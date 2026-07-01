import options, std/strutils
import ../../errors/exceptions/parser/parsererrors
import ../../types/[errors, nodes, source, token, typehints]
import ./state

# Forward declarations
when defined(yumlyEnv):
  proc parseEnv*(parser: var Parser): YumNode
proc parseValueStart*(parser: var Parser): YumNode

proc parseTypeName(parser: var Parser, baseToken: Token): TypeHint =
  ## Parses a type name after its base identifier has already been consumed.
  ## Only lists accept a parameter at this layer.
  if parser.currentToken.kind == tkLBracket and
      baseToken.value.toLowerAscii() == "list":
    parser.advance()
    let elemToken = parser.expect(tkIdent, expIdentifier)
    discard parser.expect(tkRBracket, expRBracket)
    return TypeHint(raw: baseToken.value & "[" & elemToken.value & "]",
        kind: thList, elementKind: thUnknown, elementRaw: elemToken.value,
        line: baseToken.source.line, col: baseToken.source.col)

  TypeHint(raw: baseToken.value, kind: thUnknown,
      line: baseToken.source.line, col: baseToken.source.col)

proc parseTypeHint*(parser: var Parser): Option[TypeHint] =
  if parser.currentToken.kind != tkSemiColon: # ';'
    return none(TypeHint)

  let declarationToken = parser.expect(tkSemiColon, expIdentifier)
  let baseToken = parser.expect(tkIdent, expIdentifier, declarationToken)

  some(parser.parseTypeName(baseToken))

proc parsePairStart*(parser: var Parser): YumNode =
  ## Parse the pair start.
  ##
  ## The pair syntax is: key = value.
  ## Also can be: key ;type = value
  ## OBS: ';' can be a separator when two or more pairs are in the same line.
  ## The token kinds are:
  ## tkIdent, [tkSemiColon, tkIdent], tkEquals, tkSemicolon(if in the same line).
  let keyToken = parser.expect(tkIdent, expIdentifier)
  let typeHint = parser.parseTypeHint()
  discard parser.expect(tkEquals, expEquals, keyToken)
  parser.contexts.add(ParserContext(kind: pcPair, pairState: psValue,
      valueEndLine: SourcePos(0)))
  YumNode(kind: nkPairStart, key: keyToken.value, typeHint: typeHint,
      token: keyToken, line: keyToken.source.line, col: keyToken.source.col)

proc parseSchemaFieldStart*(parser: var Parser): YumNode =
  ## Parses a value field or one of the schema-only block field forms.
  ##
  ## The schema pair syntax is: key ;type or key ;type = default.
  ## where the value is optional and only emitted when the pair has an equals token.
  ##
  ## The token kinds are:
  ## tkIdent, tkSemiColon, tkIdent, tkEquals(Optional).
  ## If tkEquals is absent, the parser emits nkPairStart followed by nkPairEnd.
  let keyToken = parser.expect(tkIdent, expIdentifier)
  if parser.currentToken.kind != tkSemiColon:
    schemaFieldTypeHintError(keyToken)
  let declarationToken = parser.expect(tkSemiColon, expIdentifier)
  let baseToken = parser.expect(tkIdent, expIdentifier, declarationToken)

  if baseToken.value.toLowerAscii() == "blk":
    if parser.currentToken.kind == tkLBracket:
      parser.advance()
      let valueBase = parser.expect(tkIdent, expIdentifier)
      let valueType = parser.parseTypeName(valueBase)
      discard parser.expect(tkRBracket, expRBracket)
      parser.finishBlockItem()
      return YumNode(kind: nkSchemaTypedBlock, name: keyToken.value,
          blockType: valueType, token: keyToken, line: keyToken.source.line,
          col: keyToken.source.col)

    let required = parser.currentToken.kind != tkEquals
    if not required:
      parser.advance()
    discard parser.expect(tkLBrace, expLBrace, keyToken)
    parser.contexts.add(ParserContext(kind: pcSchemaBlock,
        itemEndLine: SourcePos(0)))
    return YumNode(kind: nkSchemaBlockStart, name: keyToken.value,
        required: required, token: keyToken, line: keyToken.source.line,
        col: keyToken.source.col)

  let typeHint = some(parser.parseTypeName(baseToken))
  let pairState =
    if parser.currentToken.kind == tkEquals:
      parser.advance()
      psValue
    else:
      psEnd

  parser.contexts.add(ParserContext(kind: pcPair, pairState: pairState,
      valueEndLine: SourcePos(0)))
  YumNode(kind: nkPairStart, key: keyToken.value, typeHint: typeHint,
      token: keyToken, line: keyToken.source.line, col: keyToken.source.col)

proc parseBlockStart*(parser: var Parser): YumNode =
  ## Parse the block start.
  ##
  ## The block syntax is: (Name) {}
  ## where Name is an identifier and {} can contains other blocks and pairs.
  ## The token kinds are: tkLParen, tkIdent, tkRParen, tkLBrace and tkRBrace.
  let lpToken = parser.expect(tkLParen, expBlockName)
  let nameToken = parser.expect(tkIdent, expIdentifier)
  discard parser.expect(tkRParen, expValue)
  discard parser.expect(tkLBrace, expLBrace)
  parser.contexts.add(ParserContext(kind: pcBlock, itemEndLine: SourcePos(0)))
  YumNode(kind: nkBlockStart, name: nameToken.value, token: lpToken,
      line: lpToken.source.line, col: lpToken.source.col)

proc parseInclude*(parser: var Parser): YumNode =
  ## Parse the include statement.
  ##
  ## The include statement syntax is: include { "eg.yumly", "eg2.yumly" }.
  ## where each string is an include path to be loaded by the include phase.
  ##
  ## The token kinds are:
  ## tkIdent, tkLBrace, tkString, tkComma(Optional), tkString(Optional), tkRBrace.
  ## The include statement can only appear at the top of the root document.
  let token = parser.expect(tkIdent, expIdentifier) # 'include'
  discard parser.expect(tkLBrace, expLBrace) # expect {

  var paths: seq[string] = @[]
  paths.add(parser.expect(tkString, expString).value) # expect the first include path

  while parser.currentToken.kind == tkComma: # go over the others includes path
    parser.advance()
    paths.add(parser.expect(tkString, expString).value)

  discard parser.expect(tkRBrace, expRBrace) # expect }
  YumNode(kind: nkInclude, includesPath: paths, token: token,
      line: token.source.line, col: token.source.col)

proc parseSchemaStart*(parser: var Parser): YumNode =
  ## Parse the schema start.
  ##
  ## The schema syntax is: [name] { ... }.
  ## where `name` is an identifier and the body contains schema pairs.
  ##
  ## The token kinds are:
  ## tkLBracket, tkIdent, tkRBracket, tkLBrace and tkRBrace.
  ## The parser emits nkSchemaStart now and nkSchemaEnd when the body closes.
  let token = parser.expect(tkLBracket, expLBracket) # expect [
  let nameToken = parser.expect(tkIdent, expIdentifier) # expect indentifier. e.g: `name`
  discard parser.expect(tkRBracket, expRBracket) # expect ]
  discard parser.expect(tkLBrace, expLBrace) # expect {
  parser.contexts.add(ParserContext(kind: pcSchema, itemEndLine: SourcePos(
      0))) # update the context
  YumNode(kind: nkSchemaStart, name: nameToken.value, token: token,
      line: token.source.line, col: token.source.col)

proc parseObjectStart*(parser: var Parser): YumNode =
  ## Parse the object start.
  ##
  ## The object syntax is: { ... }.
  ## Objects are list items whose body contains pairs and blocks.
  ##
  ## The token kinds are:
  ## tkLBrace and tkRBrace.
  ## The parser emits nkObjectStart now and nkObjectEnd when the body closes.
  if parser.contexts.len == 0 or parser.contexts[^1].kind != pcArray:
    objectOutsideListError(parser.currentToken)
  let token = parser.expect(tkLBrace, expLBrace)
  parser.contexts.add(ParserContext(kind: pcObject, itemEndLine: SourcePos(0)))
  YumNode(kind: nkObjectStart, token: token, line: token.source.line,
      col: token.source.col)

proc parseTaggedObjectStart*(parser: var Parser): YumNode =
  ## Parse the tagged object start.
  ##
  ## The tagged object syntax is: <schema> { ... }.
  ## where schema is an identifier used by validation/resolution.
  ##
  ## The token kinds are:
  ## tkLess, tkIdent, tkGreater, tkLBrace and tkRBrace.
  ## The parser emits nkObjectStart with the schema name and nkObjectEnd when the body closes.
  if parser.contexts.len == 0 or parser.contexts[^1].kind != pcArray:
    objectOutsideListError(parser.currentToken)
  let token = parser.expect(tkLess, expValue)
  let schemaToken = parser.expect(tkIdent, expIdentifier)
  discard parser.expect(tkGreater, expValue)
  discard parser.expect(tkLBrace, expLBrace)
  parser.contexts.add(ParserContext(kind: pcObject, itemEndLine: SourcePos(0)))
  YumNode(kind: nkObjectStart, name: schemaToken.value, token: token,
      line: token.source.line, col: token.source.col)

when defined(yumlyEnv):
  proc parseCoerceType*(parser: var Parser): Option[CoerceType] =
    ## Parse an optional environment coercion type.
    ##
    ## The coercion syntax is: ;type.
    ## where type can be string, int, float or bool.
    ##
    ## The token kinds are:
    ## tkSemiColon and tkIdent.
    ## If tkSemiColon is absent, no coercion type is emitted.
    if parser.currentToken.kind != tkSemiColon:
      return none(CoerceType)

    discard parser.expect(tkSemiColon, expIdentifier)
    let typeToken = parser.expect(tkIdent, expIdentifier)
    let kind =
      case typeToken.value
      of "string": ckString
      of "int": ckInt
      of "float": ckFloat
      of "bool": ckBool
      else:
        expectedError(expIdentifier, typeToken)
        ckString

    some(CoerceType(raw: typeToken.value, kind: kind,
        line: typeToken.source.line, col: typeToken.source.col))

  proc parseEnv*(parser: var Parser): YumNode =
    ## Parse the environment variable.
    ##
    ## The environment variable syntax is: $["VAR_NAME"; coerceType ?? default]
    ## where coerceType is optional and default is optional.
    ##
    ## The token kinds are:
    ## tkDollar, tkLBracket, tkRBracket, tkString, tkSemiColon(Optional), tkDoubleInterrogation and tk[String or Literal].
    ## The default value must have the same type as coerceType.
    let token = parser.expect(tkDollar, expEnvVar) # expect $
    discard parser.expect(tkLBracket, expLBrace) # expect [
    let envNameToken = parser.expect(tkString, expString) # expect the var. e.g: "TOKEN"
    let coerceType = parser.parseCoerceType()       # try to parse ;coerceType
    var envDefault = none(string)

    # try to parse the default fallback
    if parser.currentToken.kind == tkDoubleInterrogation:
      discard parser.expect(tkDoubleInterrogation, expQuestion) # expect ??
      # expect a "string" or a literal (0, true etc.)
      let defaultToken = parser.expect({tkString, tkLiteral}, expValue)
      envDefault = some(defaultToken.value)

    discard parser.expect(tkRBracket, expRBracket)
    YumNode(kind: nkEnv, envName: envNameToken.value, envDefault: envDefault,
        coerceType: coerceType, token: token, line: token.source.line,
        col: token.source.col)

proc parseValueStart*(parser: var Parser): YumNode =
  ## Parse a value.
  ##
  ## Pair values can be environment references, scalars, or lists. Lists may also
  ## contain objects (`{ pairs or blocks }`) and tagged objects
  ## (`<schema> { pairs or blocks }`).
  ##
  ## The token kinds are:
  ## tkDollar, tkString, tkLiteral, tkLBracket, tkLBrace or tkLess.
  ## Composite values keep their context open until their closing token is read.
  case parser.currentToken.kind
  # if a value starts with a '$', it is a env.
  of tkDollar: # $["ENV"]
    when defined(yumlyEnv):
      result = parser.parseEnv() # go to parseEnv()
      parser.finishScalarValue() # mark it as consumed.
    else:
      envSupportDisabledError(parser.currentToken)

  # if a value is a string or a literal, try to parse it.
  of tkString, tkLiteral:
    let token = parser.currentToken
    parser.advance()
    # converts the string to a literal.
    result = YumNode(kind: nkLiteral, rawValue: token.value, token: token,
        line: token.source.line, col: token.source.col)
    parser.finishScalarValue() # mark it as consumed.

  # if the value starts with a '[', this can be a list.
  of tkLBracket:
    # if this list is the pair value, mark the pair as finished.
    if parser.contexts[^1].kind == pcPair:
      parser.contexts[^1].pairState = psEnd
    let token = parser.expect(tkLBracket, expValue)
    parser.contexts.add(ParserContext(kind: pcArray, itemEndLine: SourcePos(0)))
    result = YumNode(kind: nkListStart, token: token, line: token.source.line,
        col: token.source.col)
  of tkLBrace:
    result = parser.parseObjectStart()
  of tkLess:
    result = parser.parseTaggedObjectStart()
  else:
    expectedError(expValue, parser.currentToken)
