import ../types/ast
import ../serializers/encoder
import options
import tables
import macros

proc dumpYumly*(config: YumlyKind): string =
  return encoder.dumpYumly(config)

proc toYumly*(config: YumlyKind): string =
  return dumpYumly(config)

proc newYumly*(): YumlyKind =
  YumlyKind(blocks: @[], pairs: @[], includes: @[])

proc newBlock*(name: string): Block =
  Block(name: name, pairs: @[], subBlocks: @[], line: 0, col: 0)

proc addPair*(container: var YumlyKind, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.pairs.add(Pair(key: key, value: value, typeHint: hintOpt, line: 0, col: 0))

proc addBlock*(container: var YumlyKind, blk: Block) =
  container.blocks.add(blk)

proc addPair*(container: var Block, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.pairs.add(Pair(key: key, value: value, typeHint: hintOpt, line: 0, col: 0))

proc addSubBlock*(container: var Block, blk: Block) =
  container.subBlocks.add(blk)

proc newStringValue*(v: string): Value = Value(kind: vkString, strVal: v)
proc newIntValue*(v: int): Value = Value(kind: vkInt, intVal: v)
proc newFloatValue*(v: float): Value = Value(kind: vkFloat, floatVal: v)
proc newBoolValue*(v: bool): Value = Value(kind: vkBool, boolVal: v)
proc newEnvValue*(name: string, val: string = ""): Value = Value(kind: vkEnv,
    envName: name, envVal: if val == "": name else: val)
proc newListValue*(elements: seq[Value]): Value = Value(kind: vkList,
    elements: elements)
proc newTupleValue*(elements: seq[Value]): Value = Value(kind: vkTuple,
    elements: elements)

# Getters for Value

proc getStr*(val: Value): string =
  if val.kind != vkString:
    raise newException(ValueError, "Expected vkString, but got " & $val.kind)
  return val.strVal

proc getInt*(val: Value): int =
  if val.kind != vkInt:
    raise newException(ValueError, "Expected vkInt, but got " & $val.kind)
  return val.intVal

proc getFloat*(val: Value): float =
  if val.kind != vkFloat:
    raise newException(ValueError, "Expected vkFloat, but got " & $val.kind)
  return val.floatVal

proc getBool*(val: Value): bool =
  if val.kind != vkBool:
    raise newException(ValueError, "Expected vkBool, but got " & $val.kind)
  return val.boolVal

proc getElems*(val: Value): seq[Value] =
  if val.kind notin {vkList, vkTuple}:
    raise newException(ValueError, "Expected vkList or vkTuple, but got " & $val.kind)
  return val.elements

# Indexing operators
proc `[]`*(val: Value, index: int): Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(IndexDefect, "Value is not a list or tuple")
  return val.elements[index]

proc `[]`*(val: var Value, index: int): var Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(IndexDefect, "Value is not a list or tuple")
  return val.elements[index]

proc raiseKeyError(msg: string) {.noreturn.} =
  raise newException(KeyError, msg)

proc `[]`*(config: YumlyKind, key: string): Value =
  for pair in config.pairs:
    if pair.key == key: return pair.value
  raise newException(KeyError, "Key not found in Yumly config: " & key)

proc `[]`*(config: var YumlyKind, key: string): var Value =
  if config.pairs.len == 0:
    raiseKeyError("Key not found in Yumly config: " & key)
  result = config.pairs[0].value
  for pair in config.pairs.mitems:
    if pair.key == key: return pair.value
  raiseKeyError("Key not found in Yumly config: " & key)

proc `[]`*(blk: Block, key: string): Value =
  for pair in blk.pairs:
    if pair.key == key: return pair.value
  raise newException(KeyError, "Key not found in block '" & blk.name & "': " & key)

proc `[]`*(blk: var Block, key: string): var Value =
  if blk.pairs.len == 0:
    raiseKeyError("Key not found in block '" & blk.name & "': " & key)
  result = blk.pairs[0].value
  for pair in blk.pairs.mitems:
    if pair.key == key: return pair.value
  raiseKeyError("Key not found in block '" & blk.name & "': " & key)

# Iterators
iterator items*(val: Value): Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(ValueError, "Cannot iterate over non-list/tuple value")
  for element in val.elements:
    yield element

iterator items*(blk: Block): Block =
  for subBlock in blk.subBlocks:
    yield subBlock

iterator items*(config: YumlyKind): Block =
  for rootBlock in config.blocks:
    yield rootBlock

iterator mitems*(val: var Value): var Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(ValueError, "Cannot iterate over non-list/tuple value")
  for element in val.elements.mitems:
    yield element

iterator mitems*(config: var YumlyKind): var Pair =
  for pair in config.pairs.mitems:
    yield pair

iterator pairs*(blk: Block): (string, Value) =
  for pair in blk.pairs:
    yield (pair.key, pair.value)

iterator pairs*(config: YumlyKind): (string, Value) =
  for pair in config.pairs:
    yield (pair.key, pair.value)

# Macros

macro to*(node: YumlyKind | Block, T: typedesc): untyped =
  let resultIdent = genSym(nskVar, "res")
  let typeImpl = T.getTypeImpl()

  # For typedesc[T], typeImpl is [typedesc, T]
  let actualTypeSym = if typeImpl.kind == nnkBracketExpr: typeImpl[1] else: T
  var objType = actualTypeSym.getTypeImpl()

  # If it's a TypeDef, get the actual type definition
  if objType.kind == nnkTypeDef:
    objType = objType[2]

  if objType.kind == nnkRefTy:
    objType = objType[0].getTypeImpl()

  if objType.kind != nnkObjectTy:
    error("The 'to' macro only works with object types, found " &
        objType.kind.repr, T)

  let nodeIdentSym = genSym(nskLet, "node")
  result = newStmtList()
  result.add quote do:
    let `nodeIdentSym` = `node`
    var `resultIdent`: `T`

  let fields = objType[2] # RecList
  for field in fields:
    let fieldNameNode = if field[0].kind == nnkPostfix: field[0][1] else: field[0]
    let fieldNameStr = fieldNameNode.strVal
    let fieldType = field[1]

    result.add quote do:
      if `nodeIdentSym`.hasKey(`fieldNameStr`):
        let val = `nodeIdentSym`[`fieldNameStr`]
        when `fieldType` is string:
          `resultIdent`.`fieldNameNode` = val.getStr()
        elif `fieldType` is int:
          `resultIdent`.`fieldNameNode` = val.getInt()
        elif `fieldType` is float:
          `resultIdent`.`fieldNameNode` = val.getFloat()
        elif `fieldType` is bool:
          `resultIdent`.`fieldNameNode` = val.getBool()
      elif `nodeIdentSym`.hasBlock(`fieldNameStr`):
        let targetBlock = `nodeIdentSym`.getBlock(`fieldNameStr`)
        when `fieldType` is seq:
          for subItem in targetBlock.subBlocks:
            `resultIdent`.`fieldNameNode`.add(subItem.to(typeOf(`resultIdent`.`fieldNameNode`[0])))
        elif `fieldType` is object:
          `resultIdent`.`fieldNameNode` = targetBlock.to(`fieldType`)

  result.add quote do:
    `resultIdent`

# Search Utilities

proc findPair*(config: YumlyKind, key: string): Option[Value] =
  for pair in config.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc findPair*(blk: Block, key: string): Option[Value] =
  for pair in blk.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc findBlock*(config: YumlyKind, name: string): Option[Block] =
  for blk in config.blocks:
    if blk.name == name: return some(blk)
  return none(Block)

proc findBlock*(blk: Block, name: string): Option[Block] =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return some(subBlock)
  return none(Block)

proc search*(config: YumlyKind, key: string): Option[Value] =
  return config.findPair(key)

proc search*(blk: Block, key: string): Option[Value] =
  return blk.findPair(key)

proc addInclude*(container: var YumlyKind, path: string) =
  container.includes.add(Include(includePath: path))

proc inferTypeHint(val: Value): string =
  case val.kind
  of vkString: return "string"
  of vkInt: return "int"
  of vkFloat: return "float"
  of vkBool: return "bool"
  of vkList:
    if val.elements.len > 0:
      return "list[" & inferTypeHint(val.elements[0]) & "]"
    return "list[string]"
  of vkTuple: return "tuple"
  of vkEnv: return "env"

proc hasKey*(config: YumlyKind, key: string): bool =
  for pair in config.pairs:
    if pair.key == key: return true
  return false

proc hasKey*(blk: Block, key: string): bool =
  for pair in blk.pairs:
    if pair.key == key: return true
  return false

proc hasBlock*(config: YumlyKind, name: string): bool =
  for blk in config.blocks:
    if blk.name == name: return true
  return false

proc hasBlock*(blk: Block, name: string): bool =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return true
  return false

proc getBlock*(config: YumlyKind, name: string): Block =
  for blk in config.blocks:
    if blk.name == name: return blk
  raise newException(KeyError, "Block not found: " & name)

proc getBlock*(blk: Block, name: string): Block =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return subBlock
  raise newException(KeyError, "Sub-block not found: " & name)

proc add*(val: var Value, element: Value) =
  if val.kind notin {vkList, vkTuple}:
    raise newException(IndexDefect, "Cannot add to a non-list/tuple value")
  val.elements.add(element)

proc add*(val: var Value, element: string) =
  val.add(newStringValue(element))

proc add*(val: var Value, element: int) =
  val.add(newIntValue(element))

proc add*(val: var Value, element: float) =
  val.add(newFloatValue(element))

proc applyTypeHints(pairs: var seq[Pair]) =
  for p in pairs.mitems:
    if p.typeHint.isNone:
      p.typeHint = some(TypeHint(raw: inferTypeHint(p.value), kind: thUnknown))

proc applyTypeHintsRec(blocks: var seq[Block]) =
  for b in blocks.mitems:
    applyTypeHints(b.pairs)
    applyTypeHintsRec(b.subBlocks)

proc applyTypeHints*(config: var YumlyKind) =
  applyTypeHints(config.pairs)
  applyTypeHintsRec(config.blocks)

proc writeYumly*(config: var YumlyKind, path: string, inferType: bool = false) =
  if inferType:
    applyTypeHints(config)
  writeFile(path, dumpYumly(config))

proc writeYumly*(config: YumlyKind, path: string) =
  writeFile(path, dumpYumly(config))

proc toYumly*(pairs: openArray[(string, Value)],
    inferType: bool = false): string =
  var cfg = newYumly()
  for (k, v) in pairs:
    let hint = if inferType: inferTypeHint(v) else: ""
    cfg.addPair(k, v, hint)
  return dumpYumly(cfg)

proc toYumly*(pairs: openArray[(string, Value, string)]): string =
  var cfg = newYumly()
  for (k, v, hint) in pairs:
    cfg.addPair(k, v, hint)
  return dumpYumly(cfg)

proc toYumly*(t: Table[string, Value], inferType: bool = false): string =
  var cfg = newYumly()
  for k, v in t.pairs:
    let hint = if inferType: inferTypeHint(v) else: ""
    cfg.addPair(k, v, hint)
  return dumpYumly(cfg)
