import nimpy
import ../tokenizer, ../parser, ../additional/validate
import ../types/ast
import ../yumly_file

proc insertValue(dict: PyObject, key: string, value: Value) =
  case value.kind
  of vkString: dict[key] = value.str
  of vkBool:   dict[key] = value.boolVal
  of vkInt:    dict[key] = value.intVal
  of vkFloat:  dict[key] = value.floatVal
  of vkEnv:    dict[key] = value.envVal

proc blockToPyDict(blk: Block;): PyObject =
  let dict = pyDict()
  for pair in blk.pairs:
    insertValue(dict, pair.key, pair.value)
  for subBlock in blk.subBlocks:
    dict[subBlock.name] = blockToPyDict(subBlock)
  return dict

proc blocksToPyDict(blocks: seq[Block];): PyObject =
  let root = pyDict()
  for blk in blocks:
    root[blk.name] = blockToPyDict(blk)
  return root

proc parseConfigPy*(path: string): PyObject =
  checkFileExtension(path)
  let content = openFileContent(path)
  let tokens  = tokenize(content)
  var config  = generateAST(tokens)
  validateConfig(config)
  return blocksToPyDict(config.blocks)
