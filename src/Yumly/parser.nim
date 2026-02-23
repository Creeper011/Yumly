##
# This module defines Parser for the Yumly configuration language. It takes a sequence of tokens produced by the tokenizer
# and constructs an Abstract Syntax Tree (AST) that represents the structure of the configuration file.
##

import options, strutils
import types/ast, types/token
import error_messages

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

# overload with block
proc expect(parser: var Parser, kind: TokenKind, blk: Block): Token =
  if parser.peek().kind != kind:
    expectedBlockError(kind, blk.name, blk.line, blk.col, parser.peek())
  parser.advance()

proc consumeComma(parser: var Parser) =
  if parser.peek().kind == tkComma:
    discard parser.advance()

proc parseTypeHint(parser: var Parser): Option[TypeHint] =
  if parser.peek().kind != tkDeclaration:
    return none(TypeHint)
  discard parser.advance()
  let hint = parser.expect(tkIdent)
  case hint.value
  of "string": some(TypeHint(kind: thString))
  of "int":    some(TypeHint(kind: thInt))
  of "float":  some(TypeHint(kind: thFloat))
  of "bool":   some(TypeHint(kind: thBool))
  of "env":    some(TypeHint(kind: thEnv))
  of "tuple":  some(TypeHint(kind: thTuple))
  of "list":
    discard parser.expect(tkLBracket)
    let inner = parser.expect(tkIdent)
    discard parser.expect(tkRBracket)
    let innerKind = case inner.value
      of "string": thString
      of "int":    thInt
      of "float":  thFloat
      of "bool":   thBool
      of "env":    thEnv
      else:
        raise newException(ValueError, "Unknown list element type '" & inner.value & "' at line " & $inner.line & ", column " & $inner.col & ".")
    some(TypeHint(kind: thList, elementKind: innerKind))
  else:
    raise newException(ValueError, "Unknown type hint '" & hint.value & "' at line " & $hint.line & ", column " & $hint.col & ".")

proc parseValue(parser: var Parser, typeHint: Option[TypeHint] = none(TypeHint)): Value =
  case parser.peek().kind
  # if the value is an env var, we expect a structure like $[ENV_VAR_NAME]
  of tkDollar:
    discard parser.advance()
    discard parser.expect(tkLBracket)
    let key = parser.expect(tkString)
    discard parser.expect(tkRBracket)
    result = Value(kind: vkEnv, env: key.value, envVal: "")
  of tkString:
    let tok = parser.advance()
    result = Value(kind: vkString, str: tok.value)
  of tkNumber:
    let tok = parser.advance()
    if '.' in tok.value or 'e' in tok.value or 'E' in tok.value:
      result = Value(kind: vkFloat, floatVal: parseFloat(tok.value))
    else:
      result = Value(kind: vkInt, intVal: parseInt(tok.value))
  of tkIdent:
    let tok = parser.advance()
    result = case tok.value
      of "true":  Value(kind: vkBool, boolVal: true)
      of "false": Value(kind: vkBool, boolVal: false)
      else:       Value(kind: vkString, str: tok.value)
  of tkLBracket:
    discard parser.advance()
    var items: seq[Value]
    while parser.peek().kind != tkRBracket:
      items.add(parser.parseValue())
      if parser.peek().kind == tkComma:
        discard parser.advance()
    discard parser.expect(tkRBracket)

    var isTuple = false
    if typeHint.isSome:
      if typeHint.get.kind == thTuple:
        isTuple = true
      elif typeHint.get.kind == thList:
        isTuple = false
    else:
      if items.len > 1:
        let firstKind = items[0].kind
        for i in 1..<items.len:
          if items[i].kind != firstKind:
            isTuple = true
            break
      else:
        isTuple = false

    if isTuple:
      result = Value(kind: vkTuple, elements: items)
    else:
      result = Value(kind: vkList, items: items)
  else:
    let token = parser.peek()
    expectedValueError(token)
      
proc parsePair(parser: var Parser): Pair =
  let key      = parser.expect(tkIdent)
  var typeHint = parseTypeHint(parser)   # key ;type = value
  discard parser.expect(tkEquals)
  let value = parseValue(parser, typeHint)
  Pair(key: key.value, typeHint: typeHint, value: value, line: key.line, col: key.col)

proc parseBlock(parser: var Parser): Block =
  let key  = parser.expect(tkLParen)
  let name = parser.expect(tkIdent)
  discard parser.expect(tkRParen)
  discard parser.expect(tkLBrace)
  var blk  = Block(name: name.value, line: key.line, col: key.col)

  # while we haven't reached the end of the block..
  while parser.peek().kind notin {tkRBrace, tkEOF}:
    if parser.peek().kind == tkLParen:
      blk.subBlocks.add(parseBlock(parser))
    else:
      blk.pairs.add(parsePair(parser))
      if parser.peek().kind notin {tkRBrace, tkEOF}:
        discard parser.expect(tkComma)
      else:
        parser.consumeComma()

  # só aqui fecha
  discard parser.expect(tkRBrace, blk)
  blk

proc generateAST*(tokens: seq[Token]): Config =
  var parser = Parser(tokens: tokens, pos: 0)
  var config: Config
  
  # loop through the tokens until end of file.
  while parser.peek().kind != tkEOF:
    case parser.peek().kind
    of tkInclude:
      discard parser.advance()
      discard parser.expect(tkLBrace)
      let path = parser.expect(tkIdent)
      discard parser.expect(tkRBrace)
      config.includes.add(Include(includePath: path.value))
    of tkLParen:
      config.blocks.add(parseBlock(parser))
    else:
      let token = parser.peek()
      expectedTopTokenError(token)

  config