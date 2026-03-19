import options
import ../types/ast, ../types/type_hints

# Value constructors
func newStringValue*(v: string): Value = Value(kind: vkString, strVal: v)
func newIntValue*(v: int): Value = Value(kind: vkInt, intVal: v)
func newFloatValue*(v: float): Value = Value(kind: vkFloat, floatVal: v)
func newBoolValue*(v: bool): Value = Value(kind: vkBool, boolVal: v)
func newEnvValue*(name: string, val: string = ""): Value = Value(kind: vkEnv,
    envName: name, envVal: if val == "": name else: val)
func newListValue*(elements: seq[Value]): Value = Value(kind: vkList,
    elements: elements)
func newTupleValue*(elements: seq[Value]): Value = Value(kind: vkTuple,
    elements: elements)

# Block/Pair helpers
func newYumly*(): YumlyConf =
  YumlyConf(blocks: @[], pairs: @[], includes: @[])

func newBlock*(name: string): Block =
  Block(name: name, pairs: @[], subBlocks: @[], line: 0, col: 0)

func addPair*(container: var YumlyConf, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.pairs.add(Pair(key: key, value: value, typeHint: hintOpt, line: 0, col: 0))

func addPair*(container: var Block, key: string, value: Value,
    typeHint: string = "") =
  let hintOpt = if typeHint == "": none(TypeHint) else: some(TypeHint(
      raw: typeHint, kind: thUnknown))
  container.pairs.add(Pair(key: key, value: value, typeHint: hintOpt, line: 0, col: 0))

func addBlock*(container: var YumlyConf, blk: Block) =
  container.blocks.add(blk)

func addSubBlock*(container: var Block, blk: Block) =
  container.subBlocks.add(blk)
