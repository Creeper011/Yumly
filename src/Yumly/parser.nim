##
# This module defines Parser for the Yumly configuration language. It takes a sequence of tokens produced by the tokenizer
# and constructs an Abstract Syntax Tree (AST) that represents the structure of the configuration file.
##

import options, strutils
import types/ast, types/token
import error_messages
import semantic

# says the position of token in parser object
proc peek(parser: Parser): Token = parser.tokens[parser.pos]

# advances the parser token position and returns the current token
proc advance(parser: var Parser): Token =
  result = parser.tokens[parser.pos]
  parser.pos += 1

# lookahead for a token of a specific kind, if it matches, advances the parser and returns true, otherwise returns false
proc expect(parser: var Parser, kind: TokenKind): Token =
  if parser.peek().kind != kind:
    expectedError(kind, parser.peek())
  parser.advance()

proc consumeComma(parser: var Parser) =
  if parser.peek().kind == tkComma:
    discard parser.advance()

proc consumeOrExpectComma(parser: var Parser) =
  if parser.peek().kind notin {tkRBrace, tkEOF}:
    discard parser.expect(tkComma)
  else:
    parser.consumeComma()

proc parseTypeHint(parser: var Parser): Option[TypeHint] =
  if parser.peek().kind != tkDeclaration:
    return none(TypeHint)
  discard parser.advance()
  let hintTok = parser.expect(tkIdent)
  var hint: TypeHint
  if hintTok.value.toLowerAscii() == "list":
    hint = TypeHint(kind: thList, raw: hintTok.value, elementKind: thUnknown, elementRaw: "")
    if parser.peek().kind == tkLBracket:
      discard parser.advance()
      let elemKindTok = parser.expect(tkIdent)
      hint.elementRaw = elemKindTok.value
      hint.elementKind = thUnknown
      discard parser.expect(tkRBracket)
  else:
    hint = TypeHint(kind: thUnknown, raw: hintTok.value)
  hint = normalizeTypeHint(hint, hintTok.line, hintTok.col)
  return some(hint)

proc parseValue(parser: var Parser): YumNode

proc parseListItems(parser: var Parser): seq[YumNode] =
  var items: seq[YumNode] = @[]
  while parser.peek().kind != tkRBracket and parser.peek().kind != tkEOF:
    items.add(parser.parseValue())
    let next = parser.peek()
    if next.kind notin {tkComma, tkRBracket, tkEOF}:
      raise newException(ValueError,
        "Heyy, i found a malformed list at line " & $next.line &
        ", column " & $next.col &
        ". Expected ',' or ']', but found " & next.kind.toDisplay() & ".")
    parser.consumeComma()
  discard parser.expect(tkRBracket)
  return items

proc parseValue(parser: var Parser): YumNode =
  let token = parser.peek()
  
  case token.kind
  of tkDollar:
    discard parser.advance()
    
    # if is an env variable
    if parser.peek().kind == tkLBracket:
      discard parser.advance()
      let envToken = parser.expect(tkString)
      discard parser.expect(tkRBracket)
      return YumNode(kind: nkEnv, rawValue: envToken.value, token: token, line: token.line, col: token.col)
    else:
      expectedEnvBracketError(token)

  of tkString:
    let tok = parser.advance()
    let lit = literalToNode(tok)
    if lit.isSome:
      return lit.get

  of tkNumber:
    let tok = parser.advance()
    let lit = literalToNode(tok)
    if lit.isSome:
      return lit.get

  of tkIdent:
    let tok = parser.advance()
    let lit = literalToNode(tok)
    if lit.isSome:
      return lit.get

  of tkLBracket:
    let startToken = parser.advance()
    let items = parser.parseListItems()
    return YumNode(kind: nkArray, children: items, token: startToken, line: startToken.line, col: startToken.col)
  else:
    expectedValueError(parser.peek())
      
proc parsePair(parser: var Parser): YumNode =
  let keyToken = parser.expect(tkIdent)
  let typeHint = parseTypeHint(parser) 
  discard parser.expect(tkEquals)
  let valueNode = parser.parseValue()
  return YumNode(kind: nkPair, key: keyToken.value, typeHint: typeHint, valNode: valueNode,
    token: keyToken, line: keyToken.line, col: keyToken.col)

proc parseBlock*(parser: var Parser): YumNode =
  # capture (name) {
  let lpToken = parser.expect(tkLParen)
  let nameToken = parser.expect(tkIdent)
  discard parser.expect(tkRParen)
  discard parser.expect(tkLBrace)

  result = YumNode(kind: nkBlock, token: lpToken, line: lpToken.line, 
  col: lpToken.col, children: @[], name: nameToken.value)

  while parser.peek().kind notin {tkRBrace, tkEOF}:
    # if starts with an ( treats it a block
    if parser.peek().kind == tkLParen:
      result.children.add(parser.parseBlock())
    else:
      result.children.add(parser.parsePair())

    parser.consumeOrExpectComma()
  # expect an }
  discard parser.expect(tkRBrace)

proc parseInclude(p: var Parser): YumNode =
  let tok = p.peek() 
  discard p.advance()
  discard p.expect(tkLBrace)
  let path = p.expect(tkIdent)
  discard p.expect(tkRBrace)
  return YumNode(kind: nkInclude, rawValue: path.value, token: tok,line: tok.line, col: tok.col)

proc generateAST*(tokens: seq[Token]): YumNode =
  var parser = Parser(tokens: tokens, pos: 0)
  result = YumNode(kind: nkConfig, children: @[])

  while parser.peek().kind != tkEOF:
    case parser.peek().kind
    of tkInclude:
      result.children.add(parser.parseInclude())
    of tkLParen:
      result.children.add(parser.parseBlock())
    of tkIdent:
      let pairNode = parser.parsePair()
      result.children.add(pairNode)
      let nextTok = parser.peek()
      if nextTok.kind != tkEOF:
        if nextTok.line == pairNode.line:
          discard parser.expect(tkComma)
        else:
          parser.consumeComma()

    else:
      let token = parser.peek()
      expectedTopTokenError(token)
      discard parser.advance()
