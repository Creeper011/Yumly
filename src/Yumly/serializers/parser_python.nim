import nimpy
import ../types/ast

let pyBuiltins = pyBuiltinsModule()

proc valueToPy(value: Value): PyObject =
  case value.kind
  of vkString:
    result = pyBuiltins.str(value.strVal)
  of vkBool:
    result = pyBuiltins.bool(value.boolVal)
  of vkInt:
    result = pyBuiltins.int(value.intVal)
  of vkFloat:
    result = pyBuiltins.float(value.floatVal)
  of vkEnv:
    result = pyBuiltins.str(value.envVal)

  of vkList:
    let pyList = pyBuiltins.list()
    for it in value.elements:
      discard pyList.append(valueToPy(it))
    result = pyList

  of vkTuple:
    # im yumly, tuple is not an tuple object like python
    let pyList = pyBuiltins.list()
    for it in value.elements:
      discard pyList.append(valueToPy(it))
    result = pyList

proc insertValue(dict: PyObject, key: string, value: Value) =
  dict[key] = valueToPy(value)

proc blockToPyDict(blk: Block): PyObject =
  let dict = pyBuiltins.dict()
  for pair in blk.pairs:
    insertValue(dict, pair.key, pair.value)
  for subBlock in blk.subBlocks:
    dict[subBlock.name] = blockToPyDict(subBlock)
  return dict

proc toPython*(config: YumlyKind): PyObject =
  let root = pyBuiltins.dict()
  # root-level pairs
  for pair in config.pairs:
    insertValue(root, pair.key, pair.value)
  # blocks
  for blk in config.blocks:
    root[blk.name] = blockToPyDict(blk)
  return root