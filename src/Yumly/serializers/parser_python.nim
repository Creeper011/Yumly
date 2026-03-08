import nimpy
import ../types/ast

proc valueToPy(value: Value, pyBuiltins: PyObject): PyObject =
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
      discard pyList.append(valueToPy(it, pyBuiltins))
    result = pyList

  of vkTuple:
    # im yumly, tuple is not an tuple object like python
    let pyList = pyBuiltins.list()
    for it in value.elements:
      discard pyList.append(valueToPy(it, pyBuiltins))
    result = pyList

proc insertValue(dict: PyObject, key: string, value: Value, pyBuiltins: PyObject) =
  dict[key] = valueToPy(value, pyBuiltins)

proc blockToPyDict(blk: Block, pyBuiltins: PyObject): PyObject =
  let dict = pyBuiltins.dict()
  for pair in blk.pairs:
    insertValue(dict, pair.key, pair.value, pyBuiltins)
  for subBlock in blk.subBlocks:
    dict[subBlock.name] = blockToPyDict(subBlock, pyBuiltins)
  return dict

proc toPython*(config: YumlyConf): PyObject =
  let pyBuiltins = pyBuiltinsModule()
  let root = pyBuiltins.dict()
  # root-level pairs
  for pair in config.pairs:
    insertValue(root, pair.key, pair.value, pyBuiltins)
  # blocks
  for blk in config.blocks:
    root[blk.name] = blockToPyDict(blk, pyBuiltins)
  return root
