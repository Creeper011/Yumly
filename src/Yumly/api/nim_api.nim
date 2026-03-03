import ../types/ast
import ../serializers/encoder
import options
import tables

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
