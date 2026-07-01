##
# This module evaluates the resolved YumNode stream into Yumly's final public
# representation. Included files have already been expanded by the include
# loader; their items remain distinguishable through SourceSpan.source.
##

import std/[options, strutils]
when defined(yumlyEnv):
  import os
  import ../../types/errors
import ../../types/[ast, nodes, source, token, typehints]
import ../../errors/exceptions/parser/evaluatorerrors
import ../../errors/exceptions/parser/valueerrors

type
  EvalContextKind = enum
    ecBlock, ecSchema, ecSchemaBlock, ecObject, ecPair, ecList

  EvalContext = object
    case kind: EvalContextKind
    of ecBlock:
      blk: Block
    of ecSchema:
      schema: Schema
    of ecSchemaBlock:
      schemaBlockName: string
      schemaBlockRequired: bool
      schemaBlockFields: seq[SchemaField]
      schemaBlockSource: SourceSpan
    of ecObject:
      objectSchema: Option[Schema]
      objectItems: seq[Item]
      objectSource: SourceSpan
    of ecPair:
      pairKey: string
      pairTypeHint: Option[TypeHint]
      pairValue: Option[Value]
      pairSource: SourceSpan
    of ecList:
      elements: seq[Item]
      elemHint: Option[TypeHint]
      listSource: SourceSpan

func nodeSource(node: YumNode): SourceSpan =
  ## The token owns the precise range. `sourceFile` remains on YumNode while the
  ## streaming representation is being redesigned, so use it only to fill a
  ## source identity that an upstream tokenizer could not know yet.
  result = node.token.source
  if result.source == nil:
    result.source = node.sourceFile
  if node.name.len > 0 and node.kind in {nkBlockStart, nkSchemaStart,
      nkObjectStart}:
    # The representative node token is the opening delimiter. Extend the final
    # domain span across `(name)`, `[name]`, or `<name>` so diagnostics highlight
    # the complete symbol without mutating the original token stream.
    result.endLine = result.line
    result.endCol = result.col + SourcePos(node.name.len + 2)

func decodeEscapes(raw: string, line, col: SourcePos): string =
  var i = 0
  while i < raw.len:
    if raw[i] == '\\' and i + 1 < raw.len:
      case raw[i + 1]
      of 'n': result.add('\n')
      of 'r': result.add('\r')
      of 't': result.add('\t')
      of '\\': result.add('\\')
      of '"': result.add('"')
      of '\'': result.add('\'')
      else: invalidEscapeError(raw[i + 1], line, col)
      i += 2
    else:
      result.add(raw[i])
      inc i

func evaluateLiteral(node: YumNode): Value =
  let span = node.nodeSource()
  if node.token.kind == tkString:
    return Value(kind: vkString, source: span,
        strVal: decodeEscapes(node.rawValue, node.line, node.col))

  if node.token.kind != tkLiteral:
    invalidLiteralTokenError($node.token.kind)

  case node.rawValue
  of "true":
    return Value(kind: vkBool, source: span, boolVal: true)
  of "false":
    return Value(kind: vkBool, source: span, boolVal: false)
  else:
    discard

  if node.rawValue.contains('.') or node.rawValue.contains('e') or
      node.rawValue.contains('E'):
    try:
      return Value(kind: vkFloat, source: span,
          floatVal: parseFloat(node.rawValue))
    except ValueError:
      invalidFloatError(node.rawValue, node.line, node.col)

  try:
    return Value(kind: vkInt, source: span, intVal: parseInt(node.rawValue))
  except ValueError:
    invalidIntegerError(node.rawValue, node.line, node.col)

when defined(yumlyEnv):
  func coerceEnvValue(raw: string, coerceType: CoerceType,
      line, col: SourcePos): Value =
    case coerceType.kind
    of ckString:
      return Value(kind: vkString, strVal: decodeEscapes(raw, line, col))
    of ckInt:
      try: return Value(kind: vkInt, intVal: parseInt(raw))
      except ValueError: invalidIntegerError(raw, line, col)
    of ckFloat:
      try: return Value(kind: vkFloat, floatVal: parseFloat(raw))
      except ValueError: invalidFloatError(raw, line, col)
    of ckBool:
      if raw == "true": return Value(kind: vkBool, boolVal: true)
      elif raw == "false": return Value(kind: vkBool, boolVal: false)
      else: invalidBooleanError(raw, line, col)

  proc coerceEnvValue(raw: string, node: YumNode, coerceType: CoerceType,
      fromDefault: bool): Value =
    try:
      result = coerceEnvValue(raw, coerceType, coerceType.line, coerceType.col)
    except YumlyError:
      envCoerceFailedError(node.envName, coerceType.raw, fromDefault,
          coerceType.line, coerceType.col)

  proc evaluateEnv(node: YumNode): Value =
    let span = node.nodeSource()
    let envFound = os.existsEnv(node.envName)

    if node.coerceType.isSome:
      let coerceType = node.coerceType.get
      if envFound:
        result = coerceEnvValue(os.getEnv(node.envName), node, coerceType,
            fromDefault = false)
        result.source = span
        return

      if node.envDefault.isSome:
        result = coerceEnvValue(node.envDefault.get, node, coerceType,
            fromDefault = true)
        result.source = span
        return

      return Value(kind: vkEnv, source: span, envName: node.envName,
          envVal: "", envFound: false, envDefault: none(string))

    let decodedDefault =
      if node.envDefault.isSome:
        some(decodeEscapes(node.envDefault.get, node.line, node.col))
      else:
        none(string)
    let envVal =
      if envFound: os.getEnv(node.envName)
      elif decodedDefault.isSome: decodedDefault.get
      else: ""

    Value(kind: vkEnv, source: span, envName: node.envName, envVal: envVal,
        envFound: envFound, envDefault: decodedDefault)

func listElementHint(hint: Option[TypeHint]): Option[TypeHint] =
  if hint.isSome and hint.get.kind == thList:
    let typeHint = hint.get
    return some(TypeHint(kind: typeHint.elementKind, raw: typeHint.elementRaw,
        line: typeHint.line, col: typeHint.col))
  none(TypeHint)

proc newConfig(): YumlyConf =
  new(result)
  result.items = @[]

proc addPair(config: YumlyConf, stack: var seq[EvalContext], pair: sink Pair) =
  if stack.len > 0 and stack[^1].kind == ecBlock:
    stack[^1].blk.items.add(Item(kind: ikPair, pair: pair))
  else:
    config.items.add(Item(kind: ikPair, pair: pair))

proc addBlock(config: YumlyConf, stack: var seq[EvalContext], blk: sink Block) =
  if stack.len > 0 and stack[^1].kind == ecBlock:
    stack[^1].blk.items.add(Item(kind: ikBlock, blk: blk))
  elif stack.len > 0 and stack[^1].kind == ecObject:
    stack[^1].objectItems.add(Item(kind: ikBlock, blk: blk))
  elif stack.len > 0 and stack[^1].kind == ecList:
    invalidNodeKindInEvaluateError("block used directly as a list item")
  else:
    config.items.add(Item(kind: ikBlock, blk: blk))

proc addValue(stack: var seq[EvalContext], value: sink Value) =
  if stack.len == 0:
    invalidNodeKindInEvaluateError("stream value without parent")

  case stack[^1].kind
  of ecPair:
    stack[^1].pairValue = some(value)
  of ecList:
    stack[^1].elements.add(Item(kind: ikValue, value: value))
  of ecObject:
    invalidNodeKindInEvaluateError("value used directly as an object item")
  of ecBlock, ecSchema, ecSchemaBlock:
    invalidNodeKindInEvaluateError("stream value without pair")

func arrayHint(stack: seq[EvalContext]): Option[TypeHint] =
  if stack.len == 0:
    return none(TypeHint)

  case stack[^1].kind
  of ecPair: stack[^1].pairTypeHint
  of ecList: stack[^1].elemHint
  of ecBlock, ecSchema, ecSchemaBlock, ecObject: none(TypeHint)

proc addSchemaField(stack: var seq[EvalContext], field: sink SchemaField) =
  if stack.len == 0:
    invalidNodeKindInEvaluateError("schema field without parent")
  case stack[^1].kind
  of ecSchema:
    stack[^1].schema.fields.add(field)
  of ecSchemaBlock:
    stack[^1].schemaBlockFields.add(field)
  else:
    invalidNodeKindInEvaluateError("schema field outside schema")

proc evaluateScalar(node: YumNode): Value =
  when defined(yumlyEnv):
    if node.kind == nkEnv:
      return evaluateEnv(node)

  if node.kind == nkLiteral:
    return evaluateLiteral(node)
  invalidNodeKindInEvaluateError($node.kind)

proc evaluateStreamNode(config: YumlyConf, stack: var seq[EvalContext],
    node: YumNode) =
  if node.kind == nkLiteral:
    stack.addValue(evaluateScalar(node))
    return
  when defined(yumlyEnv):
    if node.kind == nkEnv:
      stack.addValue(evaluateScalar(node))
      return

  when not defined(yumlyEnv):
    {.push warning[UnreachableElse]: off.}
  case node.kind
  of nkLiteral:
    discard

  of nkListStart:
    stack.add(EvalContext(kind: ecList, elements: @[],
        elemHint: listElementHint(stack.arrayHint()),
        listSource: node.nodeSource()))

  of nkListEnd:
    if stack.len == 0 or stack[^1].kind != ecList:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    stack.addValue(Value(kind: vkList, source: ctx.listSource,
        elements: ctx.elements))

  of nkPairStart:
    stack.add(EvalContext(kind: ecPair, pairKey: node.key,
        pairTypeHint: node.typeHint, pairValue: none(Value),
        pairSource: node.nodeSource()))

  of nkPairEnd:
    if stack.len == 0 or stack[^1].kind != ecPair:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    if stack.len > 0 and stack[^1].kind in {ecSchema, ecSchemaBlock}:
      if ctx.pairTypeHint.isNone:
        invalidNodeKindInEvaluateError("schema field without type hint")
      stack.addSchemaField(SchemaField(kind: sfValue, key: ctx.pairKey,
          typeHint: ctx.pairTypeHint.get, defaultValue: ctx.pairValue,
          line: ctx.pairSource.line, col: ctx.pairSource.col,
          endLine: ctx.pairSource.endLine, endCol: ctx.pairSource.endCol))
    else:
      if ctx.pairValue.isNone:
        invalidNodeKindInEvaluateError("pair without value")

      let pair = Pair(key: ctx.pairKey, typeHint: ctx.pairTypeHint,
          value: ctx.pairValue.get, source: ctx.pairSource)
      if stack.len > 0 and stack[^1].kind == ecObject:
        stack[^1].objectItems.add(Item(kind: ikPair, pair: pair))
      elif stack.len > 0 and stack[^1].kind == ecList:
        invalidNodeKindInEvaluateError("pair used directly as a list item")
      else:
        config.addPair(stack, pair)

  of nkBlockStart:
    var newBlock: Block
    new(newBlock)
    newBlock.name = node.name
    newBlock.source = node.nodeSource()
    newBlock.items = @[]
    stack.add(EvalContext(kind: ecBlock, blk: newBlock))

  of nkBlockEnd:
    if stack.len == 0 or stack[^1].kind != ecBlock:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    config.addBlock(stack, ctx.blk)

  of nkInclude:
    # The loader expands the include immediately after this marker. The final
    # YumlyConf contains the resulting items, not a second include collection.
    discard

  of nkSchemaStart:
    var schema: Schema
    new(schema)
    schema.name = node.name
    schema.source = node.nodeSource()
    schema.fields = @[]
    stack.add(EvalContext(kind: ecSchema, schema: schema))

  of nkSchemaEnd:
    if stack.len == 0 or stack[^1].kind != ecSchema:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    config.items.add(Item(kind: ikSchema, schema: ctx.schema))

  of nkSchemaBlockStart:
    stack.add(EvalContext(kind: ecSchemaBlock,
        schemaBlockName: node.name, schemaBlockRequired: node.required,
        schemaBlockFields: @[], schemaBlockSource: node.nodeSource()))

  of nkSchemaBlockEnd:
    if stack.len == 0 or stack[^1].kind != ecSchemaBlock:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    stack.addSchemaField(SchemaField(kind: sfInlineBlock,
        key: ctx.schemaBlockName, required: ctx.schemaBlockRequired,
        fields: ctx.schemaBlockFields, line: ctx.schemaBlockSource.line,
        col: ctx.schemaBlockSource.col,
        endLine: ctx.schemaBlockSource.endLine,
        endCol: ctx.schemaBlockSource.endCol))

  of nkSchemaTypedBlock:
    let span = node.nodeSource()
    stack.addSchemaField(SchemaField(kind: sfTypedBlock, key: node.name,
        valueType: node.blockType, line: span.line, col: span.col,
        endLine: span.endLine, endCol: span.endCol))

  of nkObjectStart:
    let schema =
      if node.name.len > 0:
        var newSchema: Schema
        new(newSchema)
        newSchema.name = node.name
        newSchema.source = node.nodeSource()
        newSchema.fields = @[]
        some(newSchema)
      else:
        none(Schema)
    stack.add(EvalContext(kind: ecObject, objectSchema: schema,
        objectItems: @[], objectSource: node.nodeSource()))

  of nkObjectEnd:
    if stack.len == 0 or stack[^1].kind != ecObject:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    stack.addValue(Value(kind: vkObject, source: ctx.objectSource,
        schema: ctx.objectSchema, items: ctx.objectItems))

  of nkEOF:
    invalidNodeKindInEvaluateError($node.kind)

  else:
    invalidNodeKindInEvaluateError($node.kind)
  when not defined(yumlyEnv):
    {.pop.}

proc evaluateNodes*(puller: NodePuller): YumlyConf =
  var stack: seq[EvalContext] = @[]
  result = newConfig()

  while true:
    let node = puller()
    if node.kind == nkEOF:
      if stack.len > 0:
        invalidNodeKindInEvaluateError("unterminated stream")
      return
    result.evaluateStreamNode(stack, node)
