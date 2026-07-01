import ../../errors/exceptions/parser/parsererrors
import ../../constants
import ../../types/[document, errors, source, token]

type
  # General parser state
  PairState* = enum psValue, psEnd
  ParserOrder* = enum poIncludes, poSchemas, poRest
  ParserContextKind* = enum
    pcRoot, pcBlock, pcSchema, pcSchemaBlock, pcObject, pcPair, pcArray

  ParserContext* = object
    case kind*: ParserContextKind
    of pcRoot, pcBlock, pcSchema, pcSchemaBlock, pcObject, pcArray:
      itemEndLine*: SourcePos
    of pcPair:
      pairState*: PairState
      valueEndLine*: SourcePos

  Parser* = object
    puller*: TokenPuller
    currentToken*: Token
    previousToken*: Token
    contexts*: seq[ParserContext]
    order*: ParserOrder
    documentKind*: DocumentKind

proc advance*(parser: var Parser) =
  parser.previousToken = parser.currentToken
  parser.currentToken = parser.puller()

proc expect*(parser: var Parser, kind: TokenKind, expected: Expected): Token =
  if parser.currentToken.kind != kind:
    expectedError(expected, parser.currentToken)
  result = parser.currentToken
  parser.advance()

# Overload with previousToken
proc expect*(parser: var Parser, kind: TokenKind, expected: Expected,
    previousToken: Token): Token =
  if parser.currentToken.kind != kind:
    expectedError(expected, parser.currentToken, previousToken)
  result = parser.currentToken
  parser.advance()

# Overload with a set of kinds
proc expect*(parser: var Parser, kinds: set[TokenKind],
    expected: Expected): Token =
  if parser.currentToken.kind notin kinds:
    expectedError(expected, parser.currentToken)
  result = parser.currentToken
  parser.advance()

proc newParser*(puller: TokenPuller,
    documentKind: DocumentKind = dkConfig): Parser =
  result = Parser(puller: puller, order: poIncludes,
      documentKind: documentKind)
  result.contexts = newSeqOfCap[ParserContext](
      InitialContextCapacity) # preallocate 6 contexts slots # TODO: if this persists, transform it into a constant
  result.contexts.add(ParserContext(kind: pcRoot, itemEndLine: SourcePos(0)))
  result.advance()

proc finishScalarValue*(parser: var Parser) =
  case parser.contexts[^1].kind
  of pcPair:
    # If a pair consumed a scalar, the next pull must close the pair.
    parser.contexts[^1].pairState = psEnd
    parser.contexts[^1].valueEndLine = parser.previousToken.source.endLine
  of pcArray:
    parser.contexts[^1].itemEndLine = parser.previousToken.source.endLine
  of pcRoot, pcBlock, pcSchema, pcSchemaBlock, pcObject:
    discard

proc finishCompositeValue*(parser: var Parser) =
  if parser.contexts.len == 0:
    return
  case parser.contexts[^1].kind
  of pcArray:
    parser.contexts[^1].itemEndLine = parser.previousToken.source.endLine
  of pcPair:
    parser.contexts[^1].valueEndLine = parser.previousToken.source.endLine
  of pcObject:
    parser.contexts[^1].itemEndLine = parser.previousToken.source.endLine
  of pcRoot, pcBlock, pcSchema, pcSchemaBlock:
    discard

proc finishBlockItem*(parser: var Parser) =
  if parser.contexts.len == 0:
    return
  case parser.contexts[^1].kind
  of pcRoot, pcBlock, pcSchema, pcSchemaBlock, pcObject:
    parser.contexts[^1].itemEndLine = parser.previousToken.source.endLine
  of pcArray:
    parser.contexts[^1].itemEndLine = parser.previousToken.source.endLine
  of pcPair:
    discard

proc pullItemSeparator*(parser: var Parser) =
  if parser.contexts[^1].itemEndLine == SourcePos(0):
    return

  if parser.currentToken.kind == tkComma:
    parser.advance()
    parser.contexts[^1].itemEndLine = SourcePos(0)
  elif parser.currentToken.kind != tkRBrace and
      parser.currentToken.kind != tkEOF and
      parser.currentToken.source.line == parser.contexts[^1].itemEndLine:
    expectedError(expBlockComma, parser.currentToken)
  elif parser.currentToken.source.line != parser.contexts[^1].itemEndLine:
    parser.contexts[^1].itemEndLine = SourcePos(0)

proc pullArraySeparator*(parser: var Parser) =
  if parser.contexts[^1].itemEndLine == SourcePos(0):
    return

  if parser.currentToken.kind == tkComma:
    parser.advance()
    parser.contexts[^1].itemEndLine = SourcePos(0)
  elif parser.currentToken.kind != tkRBracket and
      parser.currentToken.kind != tkEOF and
      parser.currentToken.source.line == parser.contexts[^1].itemEndLine:
    expectedError(expComma, parser.currentToken)
  elif parser.currentToken.source.line != parser.contexts[^1].itemEndLine:
    parser.contexts[^1].itemEndLine = SourcePos(0)
