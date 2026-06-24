##
# This module defines the Recursive Descent Parser for the Yumly configuration language.
# It pulls tokens on-demand from a closure iterator
##

import options, strutils
import ../../types/[nodes, token, type_hints, errors]
import ../../error_messages

type
  PairState = enum psValue, psEnd
  ParserContextKind = enum pcRoot, pcBlock, pcPair, pcArray

  ParserContext = object
    case kind: ParserContextKind
    of pcBlock:
      blockNeedsComma: bool
    of pcPair:
      pairState: PairState
    of pcArray:
      needsComma: bool
    else:
      discard

  Parser = object
    puller: TokenPuller
    currentToken: Token
    contexts: seq[ParserContext]
    bodyStarted: bool

proc advance(parser: var Parser) =
  parser.currentToken = parser.puller()

proc expect(parser: var Parser, kind: TokenKind, expected: Expected): Token =
  if parser.currentToken.kind != kind:
    expectedError(expected, parser.currentToken)
  result = parser.currentToken
  parser.advance()

# Overload with previousToken
proc expect(parser: var Parser, kind: TokenKind, expected: Expected,
    previousToken: Token): Token =
  if parser.currentToken.kind != kind:
    expectedError(expected, parser.currentToken, previousToken)
  result = parser.currentToken
  parser.advance()

proc newParser(puller: TokenPuller): Parser =
  result = Parser(puller: puller, contexts: @[ParserContext(kind: pcRoot)])
  result.advance() # Load first token

# Forward declarations
proc parseEnv(parser: var Parser): YumNode
proc parseValueStart(parser: var Parser): YumNode

proc parseTypeHint(parser: var Parser): Option[TypeHint] =
  if parser.currentToken.kind != tkDeclaration: # ';'
    return none(TypeHint)

  let declarationToken = parser.expect(tkDeclaration, expIdentifier)

  let baseToken = parser.expect(tkIdent, expIdentifier, declarationToken)

  if parser.currentToken.kind == tkLBracket:
    parser.advance()
    let elemToken = parser.expect(tkIdent, expIdentifier)
    discard parser.expect(tkRBracket, expRBracket)
    let raw = baseToken.value & "[" & elemToken.value & "]"
    case baseToken.value.toLowerAscii()
    of "list":
      return some(TypeHint(raw: raw, kind: thList, elementRaw: elemToken.value,
          line: baseToken.line, col: baseToken.col))
    of "env":
      return some(TypeHint(raw: raw, kind: thEnv, elementRaw: elemToken.value,
          line: baseToken.line, col: baseToken.col))
    else:
      return some(TypeHint(raw: raw, kind: thUnknown, line: baseToken.line,
          col: baseToken.col))

  return some(TypeHint(raw: baseToken.value, kind: thUnknown,
      line: baseToken.line, col: baseToken.col))

proc finishScalarValue(parser: var Parser) =
  case parser.contexts[^1].kind
  of pcPair:
    # If a pair consumed a scalar, the next pull must close the pair.
    parser.contexts[^1].pairState = psEnd
  of pcArray:
    # If an array consumed a scalar, the next token must be ',' or ']'.
    parser.contexts[^1].needsComma = true
  else:
    discard

proc finishCompositeValue(parser: var Parser) =
  if parser.contexts.len == 0:
    return
  # If a nested list just closed inside a list, the parent list now needs a separator.
  if parser.contexts[^1].kind == pcArray:
    parser.contexts[^1].needsComma = true

proc finishBlockItem(parser: var Parser) =
  if parser.contexts.len > 0 and parser.contexts[^1].kind == pcBlock:
    parser.contexts[^1].blockNeedsComma = true

proc parsePairStart(parser: var Parser): YumNode =
  let keyToken = parser.expect(tkIdent, expIdentifier)
  let typeHint = parser.parseTypeHint()
  discard parser.expect(tkEquals, expEquals, keyToken)
  parser.contexts.add(ParserContext(kind: pcPair, pairState: psValue))
  return YumNode(kind: nkPairStart, key: keyToken.value, typeHint: typeHint,
      token: keyToken, line: keyToken.line, col: keyToken.col)

proc parseBlockStart(parser: var Parser): YumNode =
  let lpToken = parser.expect(tkLParen, expBlockName)
  let nameToken = parser.expect(tkIdent, expIdentifier)
  discard parser.expect(tkRParen, expValue)
  discard parser.expect(tkLBrace, expLBrace)
  parser.contexts.add(ParserContext(kind: pcBlock, blockNeedsComma: false))
  return YumNode(kind: nkBlockStart, name: nameToken.value, token: lpToken,
      line: lpToken.line, col: lpToken.col)

proc parseInclude(parser: var Parser): YumNode =
  let token = parser.expect(tkIdent, expIdentifier) # 'include'
  discard parser.expect(tkLBrace, expLBrace)
  let pathToken = parser.expect(tkString, expString)
  discard parser.expect(tkRBrace, expRBrace)
  return YumNode(kind: nkInclude, includePath: pathToken.value, token: token,
      line: token.line, col: token.col)

proc parseEnv(parser: var Parser): YumNode =
  let token = parser.expect(tkDollar, expEnvVar)
  discard parser.expect(tkLBracket, expLBrace)
  let envNameToken = parser.expect(tkString, expString)
  var envDefault = none(string)

  if parser.currentToken.kind == tkInterrogation:
    # If a default starts, require the second '?' so suggestions can explain '??'.
    discard parser.expect(tkInterrogation, expQuestion)
    discard parser.expect(tkInterrogation, expQuestion)
    let defaultToken = parser.expect(tkString, expString)
    envDefault = some(defaultToken.value)

  discard parser.expect(tkRBracket, expRBracket)
  return YumNode(kind: nkEnv, envName: envNameToken.value,
      envDefault: envDefault, token: token, line: token.line, col: token.col)

proc parseValueStart(parser: var Parser): YumNode =
  case parser.currentToken.kind
  of tkDollar: # $["ENV"]
    result = parser.parseEnv()
    parser.finishScalarValue()

  of tkString, tkLiteral:
    let token = parser.currentToken
    parser.advance()
    result = YumNode(kind: nkLiteral, rawValue: token.value, token: token,
        line: token.line, col: token.col)
    parser.finishScalarValue()

  of tkLBracket:
    # If a pair value starts a list, the pair closes only after the matching ']'.
    if parser.contexts[^1].kind == pcPair:
      parser.contexts[^1].pairState = psEnd
    let token = parser.expect(tkLBracket, expValue)
    parser.contexts.add(ParserContext(kind: pcArray, needsComma: false))
    result = YumNode(kind: nkArrayStart, token: token, line: token.line,
        col: token.col)

  else:
    expectedError(expValue, parser.currentToken)

proc pullRootNode(parser: var Parser): YumNode =
  while true:
    case parser.currentToken.kind
    of tkEOF:
      return YumNode(kind: nkEOF, token: parser.currentToken,
          line: parser.currentToken.line, col: parser.currentToken.col)
    of tkComma:
      parser.advance()
    of tkIdent:
      if parser.currentToken.value == "include":
        # If root body already started, include is no longer allowed here.
        if parser.bodyStarted:
          includeOrderError(parser.currentToken)
        result = parser.parseInclude()
        # If include is followed by ',', fail before treating it as body punctuation.
        if parser.currentToken.kind == tkComma:
          includeCommaError(parser.currentToken)
        return result

      parser.bodyStarted = true
      return parser.parsePairStart()
    of tkLParen:
      parser.bodyStarted = true
      return parser.parseBlockStart()
    else:
      expectedTopTokenError(expValue, parser.currentToken)

proc pullBlockNode(parser: var Parser): YumNode =
  while true:
    if parser.contexts[^1].blockNeedsComma:
      if parser.currentToken.kind == tkComma:
        parser.advance()
        parser.contexts[^1].blockNeedsComma = false
      elif parser.currentToken.kind != tkRBrace:
        expectedError(expBlockComma, parser.currentToken)

    case parser.currentToken.kind
    of tkComma:
      parser.advance()
    of tkRBrace:
      let token = parser.expect(tkRBrace, expRBrace)
      discard parser.contexts.pop()
      parser.finishBlockItem()
      return YumNode(kind: nkBlockEnd, token: token, line: token.line,
          col: token.col)
    of tkEOF:
      expectedError(expRBrace, parser.currentToken)
    of tkLParen:
      return parser.parseBlockStart()
    else:
      return parser.parsePairStart()

proc pullPairNode(parser: var Parser): YumNode =
  case parser.contexts[^1].pairState
  of psValue:
    return parser.parseValueStart()
  of psEnd:
    let token = parser.currentToken
    discard parser.contexts.pop()
    parser.finishBlockItem()
    return YumNode(kind: nkPairEnd, token: token, line: token.line,
        col: token.col)

proc pullArrayNode(parser: var Parser): YumNode =
  if parser.contexts[^1].needsComma:
    if parser.currentToken.kind == tkComma:
      parser.advance()
      parser.contexts[^1].needsComma = false
    elif parser.currentToken.kind != tkRBracket:
      # If the previous element was complete, only ',' or ']' can follow it.
      expectedError(expComma, parser.currentToken)

  case parser.currentToken.kind
  of tkRBracket:
    let token = parser.expect(tkRBracket, expRBracket)
    discard parser.contexts.pop()
    parser.finishCompositeValue()
    return YumNode(kind: nkArrayEnd, token: token, line: token.line,
        col: token.col)
  of tkEOF:
    expectedError(expRBracket, parser.currentToken)
  else:
    return parser.parseValueStart()

proc pullNode(parser: var Parser): YumNode =
  case parser.contexts[^1].kind
  of pcRoot: parser.pullRootNode()
  of pcBlock: parser.pullBlockNode()
  of pcPair: parser.pullPairNode()
  of pcArray: parser.pullArrayNode()

# Api/Public procs:

proc parseNodes*(puller: TokenPuller): NodePuller =
  var parser = newParser(puller)

  return proc(): YumNode {.closure.} =
    parser.pullNode()
