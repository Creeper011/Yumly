import ../../errors/exceptions/parser/parsererrors
import ../../types/[document, errors, nodes, token]
import ./[productions, state]

proc pullRootNode(parser: var Parser): YumNode =
  ## Pull the root node.
  ##
  ## The root node is the first node in the parse tree.
  ## The root node can contains includes, schemas, pairs and blocks.
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkEOF:
      return YumNode(kind: nkEOF, token: parser.currentToken,
          line: parser.currentToken.source.line,
          col: parser.currentToken.source.col)
    of tkSemiColon:
      parser.advance()
    of tkIdent:
      if parser.currentToken.value == "include":
        if parser.order != poIncludes:
          includeOrderError(parser.currentToken)
        result = parser.parseInclude()

        # includes statements should not be followed by a comma
        if parser.currentToken.kind == tkComma:
          includeCommaError(parser.currentToken)
        return result

      parser.order = poRest
      return parser.parsePairStart()
    of tkLParen:
      parser.order = poRest
      return parser.parseBlockStart()
    of tkLBracket:
      if parser.order == poRest:
        schemaOrderError(parser.currentToken)
      parser.order = poSchemas
      return parser.parseSchemaStart()
    else:
      expectedTopTokenError(expValue, parser.currentToken)

proc pullSchemaDocumentNode(parser: var Parser): YumNode =
  ## Pulls the root of a `.yu` document. Its distinct start rule permits only
  ## schema declarations; schema fields are handled by `pcSchema` as usual.
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkEOF:
      return YumNode(kind: nkEOF, token: parser.currentToken,
          line: parser.currentToken.source.line,
          col: parser.currentToken.source.col)
    of tkSemiColon:
      parser.advance()
    of tkIdent:
      if parser.currentToken.value == "include":
        schemaFileIncludeError(parser.currentToken)
      schemaFileRootError(parser.currentToken)
    of tkLBracket:
      parser.order = poSchemas
      return parser.parseSchemaStart()
    else:
      schemaFileRootError(parser.currentToken)

proc pullBlockNode(parser: var Parser): YumNode =
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkSemiColon:
      parser.advance()
    of tkRBrace:
      let token = parser.expect(tkRBrace, expRBrace)
      discard parser.contexts.pop()
      parser.finishBlockItem()
      return YumNode(kind: nkBlockEnd, token: token, line: token.source.line,
          col: token.source.col)
    of tkEOF:
      expectedError(expRBrace, parser.currentToken)
    of tkLParen:
      return parser.parseBlockStart()
    else:
      return parser.parsePairStart()

proc pullSchemaNode(parser: var Parser): YumNode =
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkSemiColon:
      parser.advance()
    of tkRBrace:
      let token = parser.expect(tkRBrace, expRBrace)
      discard parser.contexts.pop()
      parser.finishBlockItem()
      return YumNode(kind: nkSchemaEnd, token: token, line: token.source.line,
          col: token.source.col)
    of tkEOF:
      expectedError(expRBrace, parser.currentToken)
    else:
      return parser.parseSchemaFieldStart()

proc pullSchemaBlockNode(parser: var Parser): YumNode =
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkSemiColon:
      parser.advance()
    of tkRBrace:
      let token = parser.expect(tkRBrace, expRBrace)
      discard parser.contexts.pop()
      parser.finishBlockItem()
      return YumNode(kind: nkSchemaBlockEnd, token: token,
          line: token.source.line, col: token.source.col)
    of tkEOF:
      expectedError(expRBrace, parser.currentToken)
    else:
      return parser.parseSchemaFieldStart()

proc pullObjectNode(parser: var Parser): YumNode =
  while true:
    parser.pullItemSeparator()

    case parser.currentToken.kind
    of tkSemiColon:
      parser.advance()
    of tkLParen:
      return parser.parseBlockStart()
    of tkLBrace:
      return parser.parseObjectStart()
    of tkLess:
      return parser.parseTaggedObjectStart()
    of tkRBrace:
      let token = parser.expect(tkRBrace, expRBrace)
      discard parser.contexts.pop()
      parser.finishCompositeValue()
      return YumNode(kind: nkObjectEnd, token: token, line: token.source.line,
          col: token.source.col)
    of tkEOF:
      expectedError(expRBrace, parser.currentToken)
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
    return YumNode(kind: nkPairEnd, token: token, line: token.source.line,
        col: token.source.col)

proc pullArrayNode(parser: var Parser): YumNode =
  parser.pullArraySeparator()

  case parser.currentToken.kind
  of tkRBracket:
    let token = parser.expect(tkRBracket, expRBracket)
    discard parser.contexts.pop()
    parser.finishCompositeValue()
    return YumNode(kind: nkListEnd, token: token, line: token.source.line,
        col: token.source.col)
  of tkEOF:
    expectedError(expRBracket, parser.currentToken)
  else:
    return parser.parseValueStart()

proc pullNode*(parser: var Parser): YumNode =
  ## Pulls a node from the parser.
  ## Get the last context and pull the node from it.
  case parser.contexts[^1].kind
  of pcRoot:
    case parser.documentKind
    of dkConfig: parser.pullRootNode()
    of dkSchema: parser.pullSchemaDocumentNode()
  of pcBlock: parser.pullBlockNode()
  of pcSchema: parser.pullSchemaNode()
  of pcSchemaBlock: parser.pullSchemaBlockNode()
  of pcObject: parser.pullObjectNode()
  of pcPair: parser.pullPairNode()
  of pcArray: parser.pullArrayNode()
