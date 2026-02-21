##
# This module defines Parser for the Yumly configuration language. It takes a sequence of tokens produced by the tokenizer
# and constructs an Abstract Syntax Tree (AST) that represents the structure of the configuration file.
##

import options, strutils
import types/ast, types/token

# says the position of token in parser object
proc peek(parser: Parser): Token = parser.tokens[parser.pos]

# advances the parser token position and returns the current token
proc advance(parser: var Parser): Token =
  result = parser.tokens[parser.pos]
  parser.pos += 1

# lookahead for a token of a specific kind, if it matches, advances the parser and returns true, otherwise returns false
proc expect(parser: var Parser, kind: TokenKind): Token =
  if parser.peek().kind != kind:
    raise newException(ValueError,
      "Heyyy, i expected " & $kind & ", but i found: " & $parser.peek().kind &
      " on line: " & $parser.peek().line)
  parser.advance()

proc consumeComma(parser: var Parser) =
  if parser.peek().kind == tkComma:
    discard parser.advance()

proc parseTypeHint(parser: var Parser): Option[ValueKind] =
  if parser.peek().kind != tkDeclaration:
    return none(ValueKind)
  discard parser.advance()
  let hint = parser.expect(tkIdent)
  case hint.value
  of "string": some(vkString)
  of "int":    some(vkInt)
  of "float":  some(vkFloat)
  of "bool":   some(vkBool)
  of "env":    some(vkEnv)
  else:
    raise newException(ValueError, "uhh.. unknown type hint '" & hint.value & "'")

proc parseValue(parser: var Parser): Value =
  case parser.peek().kind
  # if the value is an env var, we expect a structure like $[ENV_VAR_NAME]
  of tkDollar:
    discard parser.advance()
    discard parser.expect(tkLBracket)
    let key = parser.expect(tkString)
    discard parser.expect(tkRBracket)
    Value(kind: vkEnv, env: key.value, envVal: "")
  of tkString:
    let tok = parser.advance()
    Value(kind: vkString, str: tok.value)
  of tkNumber:
    let tok = parser.advance()
    if '.' in tok.value or 'e' in tok.value or 'E' in tok.value:
      Value(kind: vkFloat, floatVal: parseFloat(tok.value))
    else:
      Value(kind: vkInt, intVal: parseInt(tok.value))
  of tkIdent: 
    let tok = parser.advance()
    case tok.value
    of "true":  Value(kind: vkBool, boolVal: true)
    of "false": Value(kind: vkBool, boolVal: false)
    else:       Value(kind: vkString, str: tok.value)
  else:
    raise newException(ValueError,
      "Heyyy, i expected a value, but i found: " & $parser.peek().kind &
      " on line: " & $parser.peek().line)
      
proc parsePair(parser: var Parser): Pair =
  let key      = parser.expect(tkIdent)
  var typeHint = parseTypeHint(parser)   # key ;type = value
  discard parser.expect(tkEquals)
  let value = parseValue(parser)
  Pair(key: key.value, typeHint: typeHint, value: value)

proc parseBlock(parser: var Parser): Block =

  # Block structure: (name) {
  discard parser.expect(tkLParen)
  let name = parser.expect(tkIdent)
  discard parser.expect(tkRParen)
  discard parser.expect(tkLBrace)

  # parse the content
  var blk = Block(name: name.value)
  # while we haven't reached the end of the block..
  while parser.peek().kind notin {tkRBrace, tkEOF}:
    # detects a sub-block.. detects with an (.. the parseBlock will handle the rest of ) {
    if parser.peek().kind == tkLParen:
      blk.subBlocks.add(parseBlock(parser))
    else:
      blk.pairs.add(parsePair(parser))
      # if the next pair is not the end of the block, we expect a comma
      if parser.peek().kind notin {tkRBrace, tkEOF}:
        discard parser.expect(tkComma)
      else:
        parser.consumeComma()

  # expect the file } to close the block
  discard parser.expect(tkRBrace)
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
      raise newException(ValueError,
        "Oh no!! i found an unexpected token at root level: " & $parser.peek().kind &
        " on line " & $parser.peek().line & " (don't forget the tokens available at root level is only 'include' ;) )")

  config