import ../types/ast, ../types/type_hints, ../utils/value_utils
import ../core/pipeline
import ../core/builders
export builders
export pipeline

import std/[options, tables, macros, sequtils, strutils]

proc toYumly*(config: YumlyConf): string =
  return dumpYumly(config)

# % operator for creating Values
proc `%`*(s: string): Value = newStringValue(s)
proc `%`*(i: int): Value = newIntValue(i)
proc `%`*(f: float): Value = newFloatValue(f)
proc `%`*(b: bool): Value = newBoolValue(b)
proc `%`*(elems: seq[Value]): Value = newListValue(elems)
proc `%`*(t: tuple): Value =
  var elems: seq[Value] = @[]
  for k, v in t.fieldPairs:
    elems.add(%v)
  newTupleValue(elems)

proc `%`*(keyVals: openArray[tuple[key: string, val: Value]]): YumlyConf =
  result = newYumly()
  for kv in keyVals:
    result.addPair(kv.key, kv.val)

# %* macro for creating Values from expressions
macro `%*`*(x: untyped): untyped =
  proc `%Recurse`(node: NimNode): NimNode =
    result = node
    case node.kind
    of nnkIntLit:
      result = newCall(bindSym"newIntValue", node)
    of nnkFloatLit:
      result = newCall(bindSym"newFloatValue", node)
    of nnkStrLit, nnkTripleStrLit:
      result = newCall(bindSym"newStringValue", node)
    of nnkIdent:
      if node.strVal == "true" or node.strVal == "false":
        result = newCall(bindSym"newBoolValue", node)
    of nnkBracket:
      let elems = node.mapIt(`%Recurse`(it))
      result = newCall(bindSym"newListValue", newTree(nnkBracket, elems))
    of nnkPar, nnkTupleConstr:
      let elems = node.mapIt(`%Recurse`(it))
      result = newCall(bindSym"newTupleValue", newTree(nnkBracket, elems))
    of nnkTableConstr:
      result = newCall(bindSym"newYumly")
      let pairs = node.mapIt(newTree(nnkExprColonExpr,
        newStrLitNode(it[0].strVal),
        `%Recurse`(it[1])))
      result.add(newTree(nnkBracket, pairs))
    else:
      discard
  result = `%Recurse`(x)

# Getters for Value with default value
proc getStr*(val: Value, default: string = ""): string =
  if val.kind != vkString: return default
  return val.strVal

proc getInt*(val: Value, default: int = 0): int =
  if val.kind != vkInt: return default
  return val.intVal

proc getFloat*(val: Value, default: float = 0.0): float =
  if val.kind != vkFloat: return default
  return val.floatVal

proc getBool*(val: Value, default: bool = false): bool =
  if val.kind != vkBool: return default
  return val.boolVal

proc getElems*(val: Value, default: seq[Value] = @[]): seq[Value] =
  if val.kind notin {vkList, vkTuple}: return default
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

proc `[]`*(config: YumlyConf, key: string): Value =
  for pair in config.pairs:
    if pair.key == key: return pair.value
  raise newException(KeyError, "Key not found in Yumly config: " & key)

proc `[]`*(config: var YumlyConf, key: string): var Value =
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

# Safe {} operator - returns Option[Value]
proc safeGet*(config: YumlyConf, key: string): Option[Value] =
  for pair in config.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc safeGet*(blk: Block, key: string): Option[Value] =
  for pair in blk.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc safeGet*(val: Value, index: int): Option[Value] =
  if val.kind notin {vkList, vkTuple}: return none(Value)
  if index < 0 or index >= val.elements.len: return none(Value)
  return some(val.elements[index])

proc `{}`*(config: YumlyConf, key: string): Option[Value] = safeGet(config, key)
proc `{}`*(blk: Block, key: string): Option[Value] = safeGet(blk, key)
proc `{}`*(val: Value, index: int): Option[Value] = safeGet(val, index)

proc `{}`*(config: YumlyConf, keys: varargs[string]): Option[Value] =
  result = some(Value(kind: vkString, strVal: ""))
  for key in keys:
    if result.isNone: return none(Value)
    let curr = result.get()
    if curr.kind in {vkList, vkTuple}:
      try:
        let idx = parseInt(key)
        result = safeGet(curr, idx)
      except:
        return none(Value)
    else:
      result = none(Value)
  if result.isSome and result.get().kind == vkString and result.get().strVal == "":
    return none(Value)
  return result

# Iterators
iterator items*(val: Value): Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(ValueError, "Cannot iterate over non-list/tuple value")
  for element in val.elements:
    yield element

iterator items*(blk: Block): Block =
  for subBlock in blk.subBlocks:
    yield subBlock

iterator items*(config: YumlyConf): Block =
  for rootBlock in config.blocks:
    yield rootBlock

iterator mitems*(val: var Value): var Value =
  if val.kind notin {vkList, vkTuple}:
    raise newException(ValueError, "Cannot iterate over non-list/tuple value")
  for element in val.elements.mitems:
    yield element

iterator mitems*(config: var YumlyConf): var Pair =
  for pair in config.pairs.mitems:
    yield pair

iterator pairs*(blk: Block): (string, Value) =
  for pair in blk.pairs:
    yield (pair.key, pair.value)

iterator pairs*(config: YumlyConf): (string, Value) =
  for pair in config.pairs:
    yield (pair.key, pair.value)

# Macros

macro to*(node: YumlyConf | Block, T: typedesc): untyped =
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

proc findPair*(config: YumlyConf, key: string): Option[Value] =
  for pair in config.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc findPair*(blk: Block, key: string): Option[Value] =
  for pair in blk.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

proc findBlock*(config: YumlyConf, name: string): Option[Block] =
  for blk in config.blocks:
    if blk.name == name: return some(blk)
  return none(Block)

proc findBlock*(blk: Block, name: string): Option[Block] =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return some(subBlock)
  return none(Block)

proc search*(config: YumlyConf, key: string): Option[Value] =
  return config.findPair(key)

proc search*(blk: Block, key: string): Option[Value] =
  return blk.findPair(key)

proc addInclude*(container: var YumlyConf, path: string) =
  container.includes.add(Include(includePath: path))

proc hasKey*(config: YumlyConf, key: string): bool =
  for pair in config.pairs:
    if pair.key == key: return true
  return false

proc hasKey*(blk: Block, key: string): bool =
  for pair in blk.pairs:
    if pair.key == key: return true
  return false

proc hasBlock*(config: YumlyConf, name: string): bool =
  for blk in config.blocks:
    if blk.name == name: return true
  return false

proc hasBlock*(blk: Block, name: string): bool =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return true
  return false

proc getBlock*(config: YumlyConf, name: string): Block =
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

proc applyTypeHints*(config: var YumlyConf) =
  applyTypeHints(config.pairs)
  applyTypeHintsRec(config.blocks)

proc writeYumly*(config: var YumlyConf, path: string, inferType: bool = false) =
  if inferType:
    applyTypeHints(config)
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
