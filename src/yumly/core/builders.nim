import options
import ../types/[ast, source, typehints]

func listElementTypeName(value: Value): string

func valueTypeKind(value: Value): TypeHintKind =
  when defined(yumlyEnv):
    case value.kind
    of vkString: thString
    of vkInt: thInt
    of vkFloat: thFloat
    of vkBool: thBool
    of vkList: thList
    of vkEnv: thEnv
    of vkObject: thUnknown
  else:
    case value.kind
    of vkString: thString
    of vkInt: thInt
    of vkFloat: thFloat
    of vkBool: thBool
    of vkList: thList
    of vkObject: thUnknown

func valueTypeName(value: Value): string =
  when defined(yumlyEnv):
    case value.kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkEnv: "env"
    of vkList:
      let element = listElementTypeName(value)
      if element.len > 0: "list[" & element & "]" else: "list"
    of vkObject:
      if value.schema.isSome: value.schema.get.name else: "object"
  else:
    case value.kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkList:
      let element = listElementTypeName(value)
      if element.len > 0: "list[" & element & "]" else: "list"
    of vkObject:
      if value.schema.isSome: value.schema.get.name else: "object"

func listElementTypeName(value: Value): string =
  if value.kind != vkList or value.elements.len == 0:
    return ""
  case value.elements[0].kind
  of ikValue: valueTypeName(value.elements[0].value)
  of ikPair: valueTypeName(value.elements[0].pair.value)
  of ikBlock: "block"
  of ikSchema: ""

func listElementTypeKind(value: Value): TypeHintKind =
  if value.kind != vkList or value.elements.len == 0:
    return thUnknown
  case value.elements[0].kind
  of ikValue: valueTypeKind(value.elements[0].value)
  of ikPair: valueTypeKind(value.elements[0].pair.value)
  of ikBlock, ikSchema: thUnknown

func typeHintFor*(value: Value): TypeHint =
  let raw = valueTypeName(value)
  if value.kind == vkList:
    return TypeHint(raw: raw, kind: thList,
        elementKind: listElementTypeKind(value),
        elementRaw: listElementTypeName(value))
  TypeHint(raw: raw, kind: valueTypeKind(value))

# Value constructors
func newStringValue*(v: string): Value = Value(kind: vkString, strVal: v)
func newIntValue*(v: int): Value = Value(kind: vkInt, intVal: v)
func newFloatValue*(v: float): Value = Value(kind: vkFloat, floatVal: v)
func newBoolValue*(v: bool): Value = Value(kind: vkBool, boolVal: v)
when defined(yumlyEnv):
  func newEnvValue*(name: string, val: string = ""): Value = Value(kind: vkEnv,
      envName: name, envVal: if val == "": name else: val, envFound: val != "")
func newListValue*(elements: seq[Value]): Value =
  var items: seq[Item] = @[]
  for element in elements:
    items.add(Item(kind: ikValue, value: element))
  Value(kind: vkList, elements: items)
func newObjectValue*(pairs: seq[Pair], schema: string = ""): Value =
  let schemaOpt =
    if schema.len > 0:
      var newSchema: Schema
      new(newSchema)
      newSchema.name = schema
      newSchema.fields = @[]
      newSchema.source = sourceSpan(nil, SourcePos(0), SourcePos(0))
      some(newSchema)
    else:
      none(Schema)
  var items: seq[Item] = @[]
  for pair in pairs:
    items.add(Item(kind: ikPair, pair: pair))
  Value(kind: vkObject, schema: schemaOpt, items: items)

func newObjectValue*(pairs: seq[Pair], blocks: seq[Block],
    schema: string = ""): Value =
  result = newObjectValue(pairs, schema)
  for blk in blocks:
    result.items.add(Item(kind: ikBlock, blk: blk))

# Block/Pair helpers
func newYumly*(): YumlyConf =
  new(result)
  result.items = @[]

func newBlock*(name: string): Block =
  new(result)
  result.name = name
  result.items = @[]
  result.source = sourceSpan(nil, SourcePos(0), SourcePos(0))

func addPair*(container: var YumlyConf, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.items.add(Item(kind: ikPair, pair: Pair(key: key, value: value,
      typeHint: hintOpt, source: sourceSpan(nil, SourcePos(0), SourcePos(0)))))

func addPair*(container: var YumlyConf, key: string, value: Value,
    typeHint: TypeHint) =
  container.items.add(Item(kind: ikPair, pair: Pair(key: key, value: value,
      typeHint: some(typeHint),
      source: sourceSpan(nil, SourcePos(0), SourcePos(0)))))

func addPair*(container: var Block, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.items.add(Item(kind: ikPair, pair: Pair(key: key, value: value,
      typeHint: hintOpt, source: sourceSpan(nil, SourcePos(0), SourcePos(0)))))

func addPair*(container: var Block, key: string, value: Value,
    typeHint: TypeHint) =
  container.items.add(Item(kind: ikPair, pair: Pair(key: key, value: value,
      typeHint: some(typeHint),
      source: sourceSpan(nil, SourcePos(0), SourcePos(0)))))

func addBlock*(container: var YumlyConf, blk: Block) =
  container.items.add(Item(kind: ikBlock, blk: blk))

func addSubBlock*(container: var Block, blk: Block) =
  container.items.add(Item(kind: ikBlock, blk: blk))
