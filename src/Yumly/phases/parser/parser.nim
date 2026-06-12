##
# This module defines the Recursive Descent Parser for the Yumly configuration language.
# It pulls tokens on-demand from a closure iterator
##

import options
import ../../types/[nodes, token, type_hints, errors]
import ../../utils/recursion
import ../../error_messages

proc advance(parser: var Parser) =
  parser.currentToken = parser.puller()

proc expect(parser: var Parser, kind: TokenKind, expected: Expected): Token =
  if parser.currentToken.kind != kind:
    expectedError(expected, parser.currentToken)
  result = parser.currentToken
  parser.advance()

proc newParser*(puller: TokenPuller): Parser =
  result = Parser(
    puller: puller,
    root: YumNode(kind: nkConfig, children: @[],
                 hasIncludes: some(false), hasTypeHints: some(false), hasEnvVars: some(false)),
    recursionDepth: 0
  )
  result.advance() # Load first token

# Forward declarations
proc parseValue(parser: var Parser): YumNode
proc parseBlock(parser: var Parser): YumNode

proc parseTypeHint(parser: var Parser): Option[TypeHint] =
  if parser.currentToken.kind != tkDeclaration: # ';'
    return none(TypeHint)

  discard parser.expect(tkDeclaration, expIdentifier)
  parser.root.hasTypeHints = some(true)

  let baseToken = parser.expect(tkIdent, expIdentifier)

  if parser.currentToken.kind == tkLBracket:
    parser.advance()
    let elemToken = parser.expect(tkIdent, expIdentifier)
    discard parser.expect(tkRBracket, expRBracket)
    return some(TypeHint(
      raw: baseToken.value & "[" & elemToken.value & "]",
      kind: thList,
      elementRaw: elemToken.value,
      line: baseToken.line, col: baseToken.col
    ))

  return some(TypeHint(raw: baseToken.value, kind: thUnknown, line: baseToken.line,
      col: baseToken.col))

proc parseListItems(parser: var Parser): seq[YumNode] =
  while parser.currentToken.kind != tkRBracket and parser.currentToken.kind != tkEOF:
    result.add(parser.parseValue())
    if parser.currentToken.kind == tkComma:
      parser.advance()
    elif parser.currentToken.kind != tkRBracket:
      expectedError(expComma, parser.currentToken)
  discard parser.expect(tkRBracket, expRBracket)

proc parseValue(parser: var Parser): YumNode =
  withRecursionGuard(parser.recursionDepth, parser.currentToken):
    case parser.currentToken.kind
    of tkDollar: # $["ENV"]
      let token = parser.expect(tkDollar, expEnvVar)
      discard parser.expect(tkLBracket, expLBrace)
      let envNameToken = parser.expect(tkString, expString)
      discard parser.expect(tkRBracket, expRBracket)
      parser.root.hasEnvVars = some(true)
      return YumNode(kind: nkLiteral, rawValue: envNameToken.value, token: token, line: token.line,
          col: token.col)

    of tkString, tkLiteral:
      let token = parser.currentToken
      parser.advance()
      return YumNode(kind: nkLiteral, rawValue: token.value, token: token, line: token.line,
          col: token.col)

    of tkLBracket:
      let token = parser.expect(tkLBracket, expValue)
      let items = parser.parseListItems()
      return YumNode(kind: nkArray, children: items, token: token, line: token.line, col: token.col)

    of tkLParen:
      return parser.parseBlock()

    else:
      expectedError(expValue, parser.currentToken)

proc parsePair(parser: var Parser): YumNode =
  let keyToken = parser.expect(tkIdent, expIdentifier)
  let typeHint = parser.parseTypeHint()
  discard parser.expect(tkEquals, expEquals)
  let valueNode = parser.parseValue()

  return YumNode(kind: nkPair, key: keyToken.value, typeHint: typeHint, valNode: valueNode,
                 token: keyToken, line: keyToken.line, col: keyToken.col)

proc parseBlock(parser: var Parser): YumNode =
  withRecursionGuard(parser.recursionDepth, parser.currentToken):
    let lpToken = parser.expect(tkLParen, expBlockName)
    let nameToken = parser.expect(tkIdent, expIdentifier)
    discard parser.expect(tkRParen, expValue)
    discard parser.expect(tkLBrace, expLBrace)

    result = YumNode(kind: nkBlock, name: nameToken.value, children: @[],
                    token: lpToken, line: lpToken.line, col: lpToken.col)

    while parser.currentToken.kind != tkRBrace and parser.currentToken.kind != tkEOF:
      if parser.currentToken.kind == tkLParen:
        result.children.add(parser.parseBlock())
      else:
        result.children.add(parser.parsePair())

      if parser.currentToken.kind == tkComma:
        parser.advance()

    discard parser.expect(tkRBrace, expRBrace)

proc parseInclude(parser: var Parser): YumNode =
  let token = parser.expect(tkIdent, expIdentifier) # 'include'
  discard parser.expect(tkLBrace, expLBrace)
  let pathToken = parser.expect(tkString, expString)
  discard parser.expect(tkRBrace, expRBrace)
  return YumNode(kind: nkInclude, includePath: pathToken.value, token: token, line: token.line,
      col: token.col)

proc parse*(parser: var Parser): YumNode =
  parser.root = YumNode(kind: nkConfig, children: @[],
                       hasIncludes: some(false), hasTypeHints: some(false), hasEnvVars: some(false))

  var phaseIncludes = true
  var lastWasInclude = false

  while parser.currentToken.kind != tkEOF:
    case parser.currentToken.kind
    of tkIdent:
      if parser.currentToken.value == "include":
        if not phaseIncludes: includeOrderError(parser.currentToken)
        parser.root.hasIncludes = some(true)
        parser.root.children.add(parser.parseInclude())
        lastWasInclude = true
      else:
        phaseIncludes = false
        parser.root.children.add(parser.parsePair())
        lastWasInclude = false
    of tkLParen:
      phaseIncludes = false
      parser.root.children.add(parser.parseBlock())
      lastWasInclude = false
    of tkComma:
      if lastWasInclude:
        includeCommaError(parser.currentToken)
      parser.advance()
      lastWasInclude = false
    else:
      expectedTopTokenError(expValue, parser.currentToken)
      parser.advance()

  return parser.root
