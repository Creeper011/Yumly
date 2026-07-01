import std/[options, strutils, tables]
import ../../constants
import ../../types/[ast, errors, source, typehints]
import ../../utils/loc
import ../../errors/common
import ../../errors/exceptions/validatorerrors

type
  ItemContext = enum
    icRoot, icBlock, icList, icObject

  StructureFrameKind = enum
    sfItem, sfValue

  StructureFrame = object
    depth: int
    case kind: StructureFrameKind
    of sfItem:
      item: Item
      context: ItemContext
      fallback: SourceSpan
    of sfValue:
      value: Value
      objectAllowed: bool

func schemaFieldSpan(schema: Schema, field: SchemaField): SourceSpan =
  sourceSpan(schema.source.source, field.line, field.col,
      field.endLine, field.endCol)

proc pushSchemaDefaults(stack: var seq[StructureFrame],
    fields: openArray[SchemaField], depth: int, fallback: SourceSpan) =
  if depth >= MaxRecursionDepth:
    validatorRecursionLimitError(MaxRecursionDepth, fallback)
  for i in countdown(fields.high, 0):
    case fields[i].kind
    of sfValue:
      if fields[i].defaultValue.isSome:
        stack.add(StructureFrame(kind: sfValue, depth: depth,
            value: fields[i].defaultValue.get, objectAllowed: false))
    of sfInlineBlock:
      stack.pushSchemaDefaults(fields[i].fields, depth + 1, fallback)
    of sfTypedBlock:
      discard

proc raiseIssue(code: ErrorCode, cuteMessage: string, span: SourceSpan,
    related: openArray[SourceSpan] = []) =
  var sources = newSeqOfCap[SourceSpan](related.len + 1)
  sources.add(span)
  sources.add(related)
  raise newYumlyError(
      yumlyDetailedMessage(code, cuteMessage, span.line, span.col),
      code, sources)

func pathString(pathParts: openArray[string]): string =
  pathParts.join(".")

func pairWhere(pathParts: openArray[string]): string =
  if pathParts.len == 0: "root" else: "'" & pathString(pathParts) & "'"

func itemKindName(kind: ItemKind): string =
  case kind
  of ikPair: "pair"
  of ikValue: "value"
  of ikBlock: "block"
  of ikSchema: "schema"

func duplicateCode(kind: ItemKind): ErrorCode =
  case kind
  of ikPair: ecValidatorDuplicatePair
  of ikBlock: ecValidatorDuplicateBlock
  of ikSchema: ecValidatorDuplicateSchema
  of ikValue: ecNone

func valueTypeName(kind: ValueKind): string =
  when defined(yumlyEnv):
    case kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkList: "list"
    of vkEnv: "env"
    of vkObject: "object"
  else:
    case kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkList: "list"
    of vkObject: "object"

func hintTypeName(kind: TypeHintKind): string =
  when defined(yumlyEnv):
    case kind
    of thString: "string"
    of thInt: "int"
    of thFloat: "float"
    of thBool: "bool"
    of thEnv: "env"
    of thList: "list"
    of thUnknown: "unknown"
  else:
    case kind
    of thString: "string"
    of thInt: "int"
    of thFloat: "float"
    of thBool: "bool"
    of thList: "list"
    of thUnknown: "unknown"

func contextName(context: ItemContext): string =
  case context
  of icRoot: "the config root"
  of icBlock: "a block"
  of icList: "a list"
  of icObject: "an object"

func itemAllowed(kind: ItemKind, context: ItemContext): bool =
  case context
  of icRoot:
    kind in {ikPair, ikBlock, ikSchema}
  of icBlock, icObject:
    kind in {ikPair, ikBlock}
  of icList:
    kind == ikValue

func itemSource(item: Item, fallback: SourceSpan): SourceSpan =
  case item.kind
  of ikPair:
    item.pair.source
  of ikValue:
    item.value.source
  of ikBlock:
    if item.blk.isNil: fallback else: item.blk.source
  of ikSchema:
    if item.schema.isNil: fallback else: item.schema.source

proc invalidItemContext(item: Item, context: ItemContext,
    fallback: SourceSpan) =
  let span = item.itemSource(fallback)
  raiseIssue(ecValidatorInvalidItemContext,
      "Ehhh... a " & itemKindName(item.kind) & " isn't allowed inside " &
      contextName(context) & "! >_<" & loc(span.line, span.col), span)

proc invalidNilItem(item: Item, context: ItemContext,
    fallback: SourceSpan) =
  let span = item.itemSource(fallback)
  raiseIssue(ecValidatorInvalidItemContext,
      "Ehhh... the " & itemKindName(item.kind) & " inside " &
      contextName(context) & " has no value! >_<" &
      loc(span.line, span.col), span)

proc checkItemStructure*(config: YumlyConf) =
  ## `Item` is deliberately broad enough to represent every item-bearing
  ## context. The validator is the boundary that rejects combinations which
  ## Yumly's grammar does not permit.
  let unknownSource = sourceSpan(nil, SourcePos(0), SourcePos(0))
  if config.isNil:
    raiseIssue(ecValidatorInvalidItemContext,
        "Ehhh... the config itself has no value! >_<", unknownSource)

  var stack = newSeqOfCap[StructureFrame](config.items.len)
  for i in countdown(config.items.high, 0):
    stack.add(StructureFrame(kind: sfItem, depth: 0,
        item: config.items[i], context: icRoot, fallback: unknownSource))

  while stack.len > 0:
    let frame = stack.pop()
    if frame.depth >= MaxRecursionDepth:
      case frame.kind
      of sfItem:
        validatorRecursionLimitError(MaxRecursionDepth,
            frame.item.itemSource(frame.fallback))
      of sfValue:
        validatorRecursionLimitError(MaxRecursionDepth, frame.value.source)

    case frame.kind
    of sfItem:
      if not itemAllowed(frame.item.kind, frame.context):
        invalidItemContext(frame.item, frame.context, frame.fallback)

      case frame.item.kind
      of ikPair:
        stack.add(StructureFrame(kind: sfValue, depth: frame.depth + 1,
            value: frame.item.pair.value, objectAllowed: false))
      of ikValue:
        stack.add(StructureFrame(kind: sfValue, depth: frame.depth + 1,
            value: frame.item.value, objectAllowed: true))
      of ikBlock:
        if frame.item.blk.isNil:
          invalidNilItem(frame.item, frame.context, frame.fallback)
        for i in countdown(frame.item.blk.items.high, 0):
          stack.add(StructureFrame(kind: sfItem, depth: frame.depth + 1,
              item: frame.item.blk.items[i], context: icBlock,
              fallback: frame.item.blk.source))
      of ikSchema:
        if frame.item.schema.isNil:
          invalidNilItem(frame.item, frame.context, frame.fallback)
        stack.pushSchemaDefaults(frame.item.schema.fields, frame.depth + 1,
            frame.item.schema.source)

    of sfValue:
      case frame.value.kind
      of vkList:
        for i in countdown(frame.value.elements.high, 0):
          stack.add(StructureFrame(kind: sfItem, depth: frame.depth + 1,
              item: frame.value.elements[i], context: icList,
              fallback: frame.value.source))
      of vkObject:
        if not frame.objectAllowed:
          raiseIssue(ecValidatorInvalidItemContext,
              "Ehhh... an object can only be used as a list value! >_<" &
              loc(frame.value.source.line, frame.value.source.col),
              frame.value.source)
        for i in countdown(frame.value.items.high, 0):
          stack.add(StructureFrame(kind: sfItem, depth: frame.depth + 1,
              item: frame.value.items[i], context: icObject,
              fallback: frame.value.source))
      else:
        discard

proc checkSchemaFieldDuplicates(schema: Schema,
    fields: openArray[SchemaField], depth: int = 0) =
  if depth >= MaxRecursionDepth:
    validatorRecursionLimitError(MaxRecursionDepth, schema.source)
  var seenFields = initTable[(bool, string), SourceSpan]()
  for field in fields:
    let fieldSpan = schema.schemaFieldSpan(field)
    let isBlock = field.kind in {sfInlineBlock, sfTypedBlock}
    let symbol = (isBlock, field.key)
    if seenFields.hasKey(symbol):
      let noun = if isBlock: "block" else: "pair"
      let code = if isBlock: ecValidatorDuplicateBlock else: ecValidatorDuplicatePair
      raiseIssue(code, "Oh no! the " & noun & " '" & field.key &
          "' is duplicated in schema '" & schema.name & "'! (°ロ°)" &
          loc(fieldSpan.line, fieldSpan.col) &
          "\n  hint: rename one of the duplicated fields.", fieldSpan,
          [seenFields[symbol]])
    seenFields[symbol] = fieldSpan

    if field.kind == sfInlineBlock:
      checkSchemaFieldDuplicates(schema, field.fields, depth + 1)

proc checkDuplicates*(items: openArray[Item],
    pathParts: openArray[string]) =
  ## Item order is source order, including items expanded from included files.
  ## Pairs, blocks, and schemas each have their own namespace. Equal names only
  ## collide when they belong to the same kind in the same scope.
  var seenSymbols = initTable[(ItemKind, string), SourceSpan]()
  for item in items:
    var name = ""
    var span: SourceSpan
    case item.kind
    of ikPair:
      name = item.pair.key
      span = item.pair.source
    of ikBlock:
      name = item.blk.name
      span = item.blk.source
    of ikSchema:
      name = item.schema.name
      span = item.schema.source
    of ikValue:
      continue

    let symbol = (item.kind, name)
    if seenSymbols.hasKey(symbol):
      let where =
        if pathParts.len == 0: "root"
        else: "'" & pathString(pathParts) & "'"
      raiseIssue(duplicateCode(item.kind), "Oh no! the " &
          itemKindName(item.kind) & " '" & name & "' is duplicated in " &
          where & "! (°ロ°)" &
          loc(span.line, span.col) &
          "\n  hint: rename one of the duplicated " &
          itemKindName(item.kind) & "s.", span, [seenSymbols[symbol]])
    seenSymbols[symbol] = span

    if item.kind == ikSchema and not item.schema.isNil:
      checkSchemaFieldDuplicates(item.schema, item.schema.fields)

proc validateEnvExistence(value: Value, fallback: SourceSpan)

proc validateEnvExistence(blk: Block) =
  for item in blk.items:
    case item.kind
    of ikPair:
      validateEnvExistence(item.pair.value, item.pair.source)
    of ikBlock:
      validateEnvExistence(item.blk)
    of ikValue:
      validateEnvExistence(item.value, blk.source)
    of ikSchema:
      discard

proc validateEnvExistence(value: Value, fallback: SourceSpan) =
  when defined(yumlyEnv):
    if value.kind == vkEnv:
      if not value.envFound and value.envDefault.isNone:
        var issueSource = value.source
        if issueSource.line == SourcePos(0):
          issueSource = fallback
        elif issueSource.source == nil:
          issueSource.source = fallback.source
        raiseIssue(ecValidatorMissingEnv, "Kyaa~! the env variable '" &
            value.envName & "' does not exist! (；ω；)" &
            loc(issueSource.line, issueSource.col) &
            "\n  hint: make sure it's set in your terminal or loaded via include { \".env\" }",
            issueSource)
      return

  case value.kind
  of vkList:
    for item in value.elements:
      case item.kind
      of ikPair:
        validateEnvExistence(item.pair.value, item.pair.source)
      of ikValue:
        validateEnvExistence(item.value, fallback)
      of ikBlock:
        validateEnvExistence(item.blk)
      of ikSchema:
        discard
  of vkObject:
    for item in value.items:
      case item.kind
      of ikPair:
        validateEnvExistence(item.pair.value, item.pair.source)
      of ikValue:
        validateEnvExistence(item.value, fallback)
      of ikBlock:
        validateEnvExistence(item.blk)
      of ikSchema:
        discard
  else:
    discard

when defined(yumlyEnv):
  func valueMatchesHint(value: Value, hintKind: TypeHintKind): bool =
    if hintKind == thEnv:
      return value.kind == vkEnv

    case hintKind
    of thUnknown: true
    of thString: value.kind == vkString
    of thInt: value.kind == vkInt
    of thFloat: value.kind == vkFloat
    of thBool: value.kind == vkBool
    of thList: value.kind == vkList
    else: false
else:
  func valueMatchesHint(value: Value, hintKind: TypeHintKind): bool =
    case hintKind
    of thUnknown: true
    of thString: value.kind == vkString
    of thInt: value.kind == vkInt
    of thFloat: value.kind == vkFloat
    of thBool: value.kind == vkBool
    of thList: value.kind == vkList

proc validateListElements(pair: Pair, hint: TypeHint) =
  if hint.kind != thList or hint.elementKind == thUnknown or
      pair.value.kind != vkList:
    return

  for i, item in pair.value.elements:
    var child: Value
    case item.kind
    of ikPair:
      child = item.pair.value
    of ikValue:
      child = item.value
    of ikBlock, ikSchema:
      continue
    when defined(yumlyEnv):
      if child.kind == vkEnv:
        continue
    if not valueMatchesHint(child, hint.elementKind):
      raiseIssue(ecValidatorListElementType, "Mmm, element " & $i &
          " in list '" & pair.key & "' has the wrong type! >_<" &
          loc(pair.source.line, pair.source.col) & "\n  got " &
          valueTypeName(child.kind) & ", but expected " &
          hintTypeName(hint.elementKind), pair.source)

proc validatePair*(pair: Pair, pathParts: openArray[string])
proc validateNestedValue(value: Value, pathParts: openArray[string])

proc validateNestedBlock(blk: Block, pathParts: openArray[string]) =
  var blockPath = @pathParts
  blockPath.add(blk.name)
  checkDuplicates(blk.items, blockPath)

  for item in blk.items:
    case item.kind
    of ikPair:
      validatePair(item.pair, blockPath)
    of ikBlock:
      validateNestedBlock(item.blk, blockPath)
    of ikValue:
      validateNestedValue(item.value, blockPath)
    of ikSchema:
      discard

proc validateNestedValue(value: Value, pathParts: openArray[string]) =
  case value.kind
  of vkList:
    for item in value.elements:
      case item.kind
      of ikPair:
        validatePair(item.pair, pathParts)
      of ikValue:
        validateNestedValue(item.value, pathParts)
      of ikBlock:
        validateNestedBlock(item.blk, pathParts)
      of ikSchema:
        discard
  of vkObject:
    checkDuplicates(value.items, pathParts)
    for item in value.items:
      case item.kind
      of ikPair:
        validatePair(item.pair, pathParts)
      of ikValue:
        validateNestedValue(item.value, pathParts)
      of ikBlock:
        validateNestedBlock(item.blk, pathParts)
      of ikSchema:
        discard
  else:
    discard

proc validatePair*(pair: Pair, pathParts: openArray[string]) =
  let position = loc(pair.source.line, pair.source.col)
  validateEnvExistence(pair.value, pair.source)

  var valuePath = @pathParts
  valuePath.add(pair.key)
  validateNestedValue(pair.value, valuePath)

  if pair.typeHint.isNone:
    return

  let hint = pair.typeHint.get
  if hint.kind == thUnknown:
    return

  when defined(yumlyEnv):
    if hint.kind == thEnv:
      if pair.value.kind != vkEnv:
        raiseIssue(ecValidatorTypeMismatch, "Ehhh... '" & pair.key &
            "' in " & pairWhere(pathParts) & " is annotated as ;" & hint.raw &
            " but does not use an env reference! >_<" & position &
            "\n  env values must use $[\"NAME\"]", pair.source)
      return

    if pair.value.kind == vkEnv and hint.kind notin {thEnv, thList}:
      raiseIssue(ecValidatorTypeMismatch, "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) &
          " is an env reference but is annotated as ;" & hint.raw & "! >_<" &
          position &
          "\n  env values must use a coerce type, like $[\"NAME\"; " &
          hintTypeName(hint.kind) & "]", pair.source)
      return

  case hint.kind
  of thList:
    if pair.value.kind != vkList:
      raiseIssue(ecValidatorTypeMismatch, "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " has the wrong type! >_<" &
          position & "\n  value is " & valueTypeName(pair.value.kind) &
          ", but the type hint is ;list",
          pair.source)
    else:
      validateListElements(pair, hint)
  else:
    var valueIsEnv = false
    when defined(yumlyEnv):
      valueIsEnv = pair.value.kind == vkEnv
    if not valueMatchesHint(pair.value, hint.kind) and not valueIsEnv:
      raiseIssue(ecValidatorTypeMismatch, "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " has the wrong type! >_<" &
          position & "\n  value is " & valueTypeName(pair.value.kind) &
          ", but the type hint is ;" & hintTypeName(hint.kind), pair.source)

proc cloneSchemaValue(value: Value): Value
proc cloneSchemaItems(items: openArray[Item]): seq[Item]

proc cloneSchemaBlock(blk: Block): Block =
  if blk.isNil:
    return nil
  new(result)
  result.name = blk.name
  result.source = blk.source
  result.items = cloneSchemaItems(blk.items)

proc cloneSchemaItems(items: openArray[Item]): seq[Item] =
  result = newSeqOfCap[Item](items.len)
  for item in items:
    case item.kind
    of ikPair:
      var pair = item.pair
      pair.value = cloneSchemaValue(item.pair.value)
      result.add(Item(kind: ikPair, pair: pair))
    of ikValue:
      result.add(Item(kind: ikValue,
          value: cloneSchemaValue(item.value)))
    of ikBlock:
      result.add(Item(kind: ikBlock, blk: cloneSchemaBlock(item.blk)))
    of ikSchema:
      result.add(item)

proc cloneSchemaValue(value: Value): Value =
  result = value
  case value.kind
  of vkList:
    result.elements = cloneSchemaItems(value.elements)
  of vkObject:
    result.items = cloneSchemaItems(value.items)
  else:
    discard

func findValueField(fields: openArray[SchemaField], key: string): int =
  for i, field in fields:
    if field.kind == sfValue and field.key == key:
      return i
  -1

func findBlockField(fields: openArray[SchemaField], key: string): int =
  for i, field in fields:
    if field.kind in {sfInlineBlock, sfTypedBlock} and field.key == key:
      return i
  -1

func findPair(items: openArray[Item], key: string): int =
  for i, item in items:
    if item.kind == ikPair and item.pair.key == key:
      return i
  -1

func findBlock(items: openArray[Item], key: string): int =
  for i, item in items:
    if item.kind == ikBlock and item.blk.name == key:
      return i
  -1

func schemaHintType(hint: TypeHint): string =
  if hint.kind == thList and hint.elementRaw.len > 0:
    return "list, " & hint.elementRaw
  hint.raw

func acceptedSchemaFieldsHint(schema: Schema, fields: openArray[SchemaField],
    items: openArray[Item], blocksOnly: bool): string =
  var available: seq[string] = @[]
  for field in fields:
    case field.kind
    of sfValue:
      if not blocksOnly and items.findPair(field.key) < 0:
        available.add(field.key & " (" & field.typeHint.schemaHintType() & ")")
    of sfInlineBlock:
      if blocksOnly and items.findBlock(field.key) < 0:
        available.add(field.key & " (blk)")
    of sfTypedBlock:
      if blocksOnly and items.findBlock(field.key) < 0:
        available.add(field.key & " (blk, " &
            field.valueType.schemaHintType() & ")")

  let noun = if blocksOnly: "blocks" else: "pairs"
  if available.len == 0:
    return "\n  hint: schema '" & schema.name & "' accepts no additional " &
        noun & " here"

  result = "\n  hint: " & noun & " still accepted by schema '" & schema.name &
      "':"
  for entry in available:
    result.add("\n    " & entry)

proc validateSchemaValue(value: var Value, schemas: Table[string, Schema],
    expectedSchema: string, pathParts: openArray[string], depth: int)
proc validateSchemaItems(items: var seq[Item], schemas: Table[string, Schema],
    pathParts: openArray[string], depth: int)

proc validateTypedSchemaBlock(blk: var Block, schema: Schema,
    field: SchemaField, pathParts: openArray[string]) =
  var blockPath = @pathParts
  blockPath.add(blk.name)
  for item in blk.items:
    case item.kind
    of ikPair:
      let probe = Pair(key: item.pair.key, typeHint: some(field.valueType),
          value: item.pair.value, source: item.pair.source)
      try:
        validatePair(probe, blockPath)
      except YumlyError as issue:
        if issue.code notin {ecValidatorTypeMismatch,
            ecValidatorListElementType}:
          raise
        raiseIssue(ecValidatorSchemaBlockValueType,
            "Ehhh... pair '" & item.pair.key & "' in block '" & blk.name &
            "' does not match ;blk[" & field.valueType.raw & "]! >_<" &
            loc(item.pair.source.line, item.pair.source.col), item.pair.source,
            [schema.schemaFieldSpan(field)])
    of ikBlock:
      raiseIssue(ecValidatorSchemaBlockValueType,
          "Ehhh... block '" & blk.name & "' declared as ;blk[" &
          field.valueType.raw & "] can contain pairs only! >_<" &
          loc(item.blk.source.line, item.blk.source.col), item.blk.source,
          [schema.schemaFieldSpan(field)])
    of ikValue, ikSchema:
      raiseIssue(ecValidatorSchemaBlockValueType,
          "Ehhh... block '" & blk.name & "' contains an invalid schema item! >_<",
          blk.source, [schema.schemaFieldSpan(field)])

proc validateItemsAgainstSchema(items: var seq[Item], schema: Schema,
    fields: openArray[SchemaField], containerSpan: SourceSpan,
    pathParts: openArray[string], depth: int) =
  if depth >= MaxRecursionDepth:
    validatorRecursionLimitError(MaxRecursionDepth, containerSpan)

  for item in items:
    case item.kind
    of ikPair:
      if fields.findValueField(item.pair.key) < 0:
        raiseIssue(ecValidatorSchemaUnknownField,
            "Ehhh... pair '" & item.pair.key & "' is not accepted by schema '" &
            schema.name & "'! >_<" & loc(item.pair.source.line,
            item.pair.source.col) & schema.acceptedSchemaFieldsHint(fields,
            items, blocksOnly = false),
            item.pair.source, [schema.source])
    of ikBlock:
      if fields.findBlockField(item.blk.name) < 0:
        raiseIssue(ecValidatorSchemaUnknownField,
            "Ehhh... block '" & item.blk.name & "' is not accepted by schema '" &
            schema.name & "'! >_<" & loc(item.blk.source.line,
            item.blk.source.col) & schema.acceptedSchemaFieldsHint(fields,
            items, blocksOnly = true),
            item.blk.source, [schema.source])
    of ikValue, ikSchema:
      discard

  for field in fields:
    let declarationSpan = schema.schemaFieldSpan(field)
    case field.kind
    of sfValue:
      let pairIndex = items.findPair(field.key)
      if pairIndex < 0:
        if field.defaultValue.isSome:
          items.add(Item(kind: ikPair, pair: Pair(key: field.key,
              typeHint: none(TypeHint),
              value: cloneSchemaValue(field.defaultValue.get),
              source: declarationSpan)))
        else:
          raiseIssue(ecValidatorSchemaMissingField,
              "Ehhh... schema '" & schema.name & "' requires pair '" &
              field.key & "'! >_<" & loc(containerSpan.line,
              containerSpan.col), containerSpan, [declarationSpan])
      else:
        let actual = items[pairIndex].pair
        let probe = Pair(key: actual.key, typeHint: some(field.typeHint),
            value: actual.value, source: actual.source)
        validatePair(probe, pathParts)

    of sfInlineBlock:
      let blockIndex = items.findBlock(field.key)
      if blockIndex < 0:
        if field.required:
          raiseIssue(ecValidatorSchemaMissingBlock,
              "Ehhh... schema '" & schema.name & "' requires block '" &
              field.key & "'! >_<" & loc(containerSpan.line,
              containerSpan.col), containerSpan, [declarationSpan])
      else:
        var blockPath = @pathParts
        blockPath.add(field.key)
        validateItemsAgainstSchema(items[blockIndex].blk.items, schema,
            field.fields, items[blockIndex].blk.source, blockPath, depth + 1)

    of sfTypedBlock:
      let blockIndex = items.findBlock(field.key)
      if blockIndex < 0:
        raiseIssue(ecValidatorSchemaMissingBlock,
            "Ehhh... schema '" & schema.name & "' requires block '" &
            field.key & "'! >_<" & loc(containerSpan.line,
            containerSpan.col), containerSpan, [declarationSpan])
      else:
        validateTypedSchemaBlock(items[blockIndex].blk, schema, field,
            pathParts)

proc validateSchemaValue(value: var Value, schemas: Table[string, Schema],
    expectedSchema: string, pathParts: openArray[string], depth: int) =
  if depth >= MaxRecursionDepth:
    validatorRecursionLimitError(MaxRecursionDepth, value.source)

  case value.kind
  of vkList:
    for i in 0 ..< value.elements.len:
      if expectedSchema.len > 0:
        if value.elements[i].kind != ikValue or
            value.elements[i].value.kind != vkObject:
          let span =
            if value.elements[i].kind == ikValue:
              value.elements[i].value.source
            else:
              value.source
          raiseIssue(ecValidatorListElementType,
              "Mmm, element " & $i & " must be an object matching schema '" &
              expectedSchema & "'! >_<" & loc(span.line, span.col), span)
        validateSchemaValue(value.elements[i].value, schemas,
            expectedSchema, pathParts, depth + 1)
      elif value.elements[i].kind == ikValue:
        validateSchemaValue(value.elements[i].value, schemas, "", pathParts,
            depth + 1)

  of vkObject:
    let taggedSchema =
      if value.schema.isSome: value.schema.get.name else: ""
    if expectedSchema.len > 0 and taggedSchema.len > 0 and
        taggedSchema != expectedSchema:
      raiseIssue(ecValidatorTypeMismatch,
          "Ehhh... object tagged <" & taggedSchema &
          "> appears where schema '" & expectedSchema & "' is required! >_<" &
          loc(value.source.line, value.source.col), value.source)

    let selectedSchema =
      if expectedSchema.len > 0: expectedSchema else: taggedSchema
    if selectedSchema.len > 0:
      if not schemas.hasKey(selectedSchema):
        raiseIssue(ecValidatorUnknownSchema,
            "Ehhh... unknown schema '" & selectedSchema & "'! >_<" &
            loc(value.source.line, value.source.col), value.source)
      let schema = schemas[selectedSchema]
      var objectPath = @pathParts
      objectPath.add(selectedSchema)
      validateItemsAgainstSchema(value.items, schema, schema.fields,
          value.source, objectPath, depth + 1)

    validateSchemaItems(value.items, schemas, pathParts, depth + 1)
  else:
    discard

proc validateSchemaItems(items: var seq[Item], schemas: Table[string, Schema],
    pathParts: openArray[string], depth: int) =
  if depth >= MaxRecursionDepth:
    let span =
      if items.len > 0: items[0].itemSource(sourceSpan(nil, 0, 0))
      else: sourceSpan(nil, 0, 0)
    validatorRecursionLimitError(MaxRecursionDepth, span)

  for item in items.mitems:
    case item.kind
    of ikPair:
      var expectedSchema = ""
      if item.pair.typeHint.isSome:
        let hint = item.pair.typeHint.get
        if hint.kind == thList and schemas.hasKey(hint.elementRaw):
          expectedSchema = hint.elementRaw
      validateSchemaValue(item.pair.value, schemas, expectedSchema,
          pathParts, depth + 1)
    of ikBlock:
      var blockPath = @pathParts
      blockPath.add(item.blk.name)
      validateSchemaItems(item.blk.items, schemas, blockPath, depth + 1)
    of ikValue:
      validateSchemaValue(item.value, schemas, "", pathParts, depth + 1)
    of ikSchema:
      discard

proc validateSchemaDefaults(schema: Schema, fields: var seq[SchemaField],
    schemas: Table[string, Schema], pathParts: openArray[string],
    depth: int = 0) =
  if depth >= MaxRecursionDepth:
    validatorRecursionLimitError(MaxRecursionDepth, schema.source)
  for field in fields.mitems:
    case field.kind
    of sfValue:
      if field.defaultValue.isSome:
        let span = schema.schemaFieldSpan(field)
        let probe = Pair(key: field.key, typeHint: some(field.typeHint),
            value: field.defaultValue.get, source: span)
        validatePair(probe, pathParts)
        var defaultValue = field.defaultValue.get
        var nestedSchema = ""
        if field.typeHint.kind == thList and
            schemas.hasKey(field.typeHint.elementRaw):
          nestedSchema = field.typeHint.elementRaw
        validateSchemaValue(defaultValue, schemas, nestedSchema, pathParts, 0)
    of sfInlineBlock:
      validateSchemaDefaults(schema, field.fields, schemas, pathParts,
          depth + 1)
    of sfTypedBlock:
      discard

proc validateSchemas*(config: YumlyConf) =
  var schemas = initTable[string, Schema]()
  for item in config.items:
    if item.kind == ikSchema:
      schemas[item.schema.name] = item.schema

  for item in config.items.mitems:
    if item.kind == ikSchema:
      validateSchemaDefaults(item.schema, item.schema.fields, schemas,
          @[item.schema.name])

  validateSchemaItems(config.items, schemas, @[], 0)
