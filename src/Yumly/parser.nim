##
# This module defines Parser for the Yumly configuration language. It takes a sequence of tokens produced by the tokenizer
# and constructs an Abstract Syntax Tree (AST) that represents the structure of the configuration file.
##

import options
import types/nodes, types/token, types/type_hints
import error_messages

# Returns the current token without advancing
proc peek(parser: Parser): Token = parser.tokens[parser.pos]

# Advances the parser position and returns the previous token
proc advance(parser: var Parser): Token =
  result = parser.tokens[parser.pos]
  parser.pos += 1

# Asserts the current token matches `kind`, advances and returns it — or raises a generic error
proc expect(parser: var Parser, kind: TokenKind, expected: Expected): Token =
  if parser.peek().kind != kind:
    expectedError(expected, parser.peek())
  parser.advance()

# overload of expect, same as above, but includes block context in the error message
proc expect(parser: var Parser, kind: TokenKind, expected: Expected,
            blkName: string, blkLine, blkCol: int): Token =
  if parser.peek().kind != kind:
    expectedBlockError(expected, blkName, blkLine, blkCol, parser.peek())
  parser.advance()

proc consumeComma(parser: var Parser) =
  if parser.peek().kind == tkComma:
    discard parser.advance()

proc consumeOrExpectComma(parser: var Parser) =
  if parser.peek().kind notin {tkRBrace, tkEOF}:
    discard parser.expect(tkComma, expComma)
  else:
    parser.consumeComma()

proc consumeRootSeparator(parser: var Parser, nodeLine: int) =
  let nextTok = parser.peek()
  if nextTok.kind != tkEOF:
    if nextTok.line == nodeLine:
      discard parser.expect(tkComma, expComma)
    else:
      parser.consumeComma()

proc parseTypeHint(parser: var Parser): Option[TypeHint] =
  if parser.peek().kind != tkDeclaration:
    return none(TypeHint)
  discard parser.advance()
  let baseTok = parser.expect(tkIdent, expIdentifier)

  if parser.peek().kind == tkLBracket:
    discard parser.advance()
    let elemTok = parser.expect(tkIdent, expIdentifier)
    discard parser.expect(tkRBracket, expRBracket)
    return some(TypeHint(
      raw: baseTok.value,
      kind: thList,
      elementKind: thUnknown,
      elementRaw: elemTok.value,
      line: baseTok.line,
      col: baseTok.col
    ))

  some(TypeHint(
    raw: baseTok.value,
    kind: thUnknown,
    line: baseTok.line,
    col: baseTok.col
  ))

proc parseValue(parser: var Parser): YumNode

proc parseListItems(parser: var Parser): seq[YumNode] =
  var items: seq[YumNode] = @[]
  while parser.peek().kind != tkRBracket and parser.peek().kind != tkEOF:
    items.add(parser.parseValue())
    let next = parser.peek()
    if next.kind notin {tkComma, tkRBracket, tkEOF}:
      expectedError(expComma, next)
    parser.consumeComma()
  discard parser.expect(tkRBracket, expRBracket)
  return items

proc parseValue(parser: var Parser): YumNode =
  let token = parser.peek()

  case token.kind
  of tkDollar:
    # Environment variable: $["ENV_NAME"]
    discard parser.advance()
    if parser.peek().kind != tkLBracket:
      expectedEnvBracketError(expEnvVar, token)
    discard parser.advance()
    let envToken = parser.expect(tkString, expString)
    discard parser.expect(tkRBracket, expRBracket)
    # rawValue holds just the env name so the evaluator can resolve it
    return YumNode(kind: nkLiteral, rawValue: envToken.value,
                   token: token, line: token.line, col: token.col)

  of tkAt:
    let atToken = parser.advance()
    let refToken = parser.expect(tkIdent, expIdentifier)
    return YumNode(kind: nkGlobalRef, refName: refToken.value,
                   token: atToken, line: atToken.line, col: atToken.col)

  of tkBang:
    let bangToken = parser.advance()
    let stringToken = parser.expect(tkString, expString)
    return YumNode(kind: nkLiteral, rawValue: stringToken.value,
                   token: bangToken, line: bangToken.line, col: bangToken.col)

  of tkString:
    let tok = parser.advance()
    return YumNode(kind: nkLiteral, rawValue: tok.value,
                   token: tok, line: tok.line, col: tok.col)

  of tkLiteral:
    # Covers integers, floats and booleans (true / false)
    let tok = parser.advance()
    return YumNode(kind: nkLiteral, rawValue: tok.value,
                   token: tok, line: tok.line, col: tok.col)

  of tkLBracket:
    let startToken = parser.advance()
    let items = parser.parseListItems()
    return YumNode(kind: nkArray, children: items,
                   token: startToken, line: startToken.line, col: startToken.col)

  else:
    expectedError(expValue, parser.peek())

proc parsePair(parser: var Parser): YumNode =
  let keyToken = parser.expect(tkIdent, expIdentifier)
  let typeHint = parseTypeHint(parser)
  discard parser.expect(tkEquals, expEquals)
  let valueNode = parser.parseValue()
  return YumNode(kind: nkPair, key: keyToken.value, typeHint: typeHint,
                 valNode: valueNode, token: keyToken,
                 line: keyToken.line, col: keyToken.col)

proc parseSymbol(parser: var Parser): YumNode =
  let atToken = parser.expect(tkAt, expAt)
  let keyToken = parser.expect(tkIdent, expIdentifier)
  let typeHint = parseTypeHint(parser)
  discard parser.expect(tkEquals, expEquals)
  let valueNode = parser.parseValue()
  return YumNode(kind: nkSymbolDecl, key: keyToken.value, typeHint: typeHint,
                 valNode: valueNode, token: atToken,
                 line: atToken.line, col: atToken.col)

proc parseBlock*(parser: var Parser): YumNode =
  # Syntax: (name) { ... }
  let lpToken = parser.expect(tkLParen, expBlockName)
  let nameToken = parser.expect(tkIdent, expIdentifier)
  discard parser.expect(tkRParen, expValue)   # no expRParen in enum — expValue is a safe fallback
  discard parser.expect(tkLBrace, expLBrace)

  result = YumNode(kind: nkBlock, name: nameToken.value, children: @[],
                   token: lpToken, line: lpToken.line, col: lpToken.col)

  while parser.peek().kind notin {tkRBrace, tkEOF}:
    if parser.peek().kind == tkLParen:
      result.children.add(parser.parseBlock())
    elif parser.peek().kind == tkAt:
      symbolRootOnlyError(parser.peek())
    else:
      result.children.add(parser.parsePair())
    parser.consumeOrExpectComma()

  discard parser.expect(tkRBrace, expRBrace,
                        nameToken.value, lpToken.line, lpToken.col)

proc parseInclude(parser: var Parser): YumNode =
  # Syntax: include { "path" }
  let tok = parser.advance() # consume tkInclude
  discard parser.expect(tkLBrace, expLBrace)
  let pathToken = parser.expect(tkString, expString)
  discard parser.expect(tkRBrace, expRBrace)
  return YumNode(kind: nkInclude, includePath: pathToken.value,
                 token: tok, line: tok.line, col: tok.col)

proc generateAST*(tokens: seq[Token]): YumNode =
  var parser = Parser(tokens: tokens, pos: 0, recursionDepth: 0)
  result = YumNode(kind: nkConfig, children: @[])

  # defines the orders of the different root-level constructs. this allows a consistent structure/style across Yumly files
  type RootPhase = enum
    rpIncludes,
    rpSymbols,
    rpRegular

  var phase = rpIncludes

  while parser.peek().kind != tkEOF:
    case parser.peek().kind
    of tkInclude:
      if phase != rpIncludes:
        includeOrderError(parser.peek())
      result.children.add(parser.parseInclude())

    of tkAt:
      if phase == rpRegular:
        symbolOrderError(parser.peek())
      phase = rpSymbols
      let symbolNode = parser.parseSymbol()
      result.children.add(symbolNode)
      parser.consumeRootSeparator(symbolNode.line)

    of tkLParen:
      phase = rpRegular
      result.children.add(parser.parseBlock())

    of tkIdent:
      phase = rpRegular
      let pairNode = parser.parsePair()
      result.children.add(pairNode)
      parser.consumeRootSeparator(pairNode.line)

    else:
      expectedTopTokenError(expValue, parser.peek())
      discard parser.advance()
