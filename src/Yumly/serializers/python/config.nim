import nimpy
import sets, strutils, options
import ../../types/ast
import ../../types/values_defs
import ../../core/builders

type
  PyTypes = tuple[bool, int, float, str, list, `tuple`, dict,
      noneType: PyObject]

func isYumlyIdent(name: string): bool =
  if name.len == 0:
    return false
  if name[0] notin IdentStartChars:
    return false
  for i in 1 ..< name.len:
    if name[i] notin IdentChars and name[i] notin {'/', '.', '-'}:
      return false
  true

proc requireYumlyKey(key, scope: string, isRootPair = false) =
  if not isYumlyIdent(key):
    raise newException(ValueError,
      "Invalid Python dict key '" & key & "' in " & scope &
      ": Yumly keys must start with an identifier character and may only contain identifier characters, '/', '.', or '-'.")

  if isRootPair and key == "include":
    raise newException(ValueError,
      "Invalid Python dict key 'include' at root: 'include' is reserved for include statements in Yumly files.")

proc parseDictKey(key: PyObject, pyTypes: PyTypes, pyBuiltins: PyObject,
    scope: string, isRootPair = false): string =
  if not pyBuiltins.callMethod("isinstance", key, pyTypes.str).to(bool):
    raise newException(ValueError,
      "Invalid Python dict key in " & scope & ": Yumly keys must be strings.")
  result = key.to(string)
  requireYumlyKey(result, scope, isRootPair)

proc ensureUniqueKey(seen: var HashSet[string], key, scope: string) =
  if key in seen:
    raise newException(ValueError,
      "Cannot convert YumlyConf to Python dict: duplicate pair/block name '" &
      key & "' in " & scope & ".")
  seen.incl(key)

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

proc insertValue(dict: PyObject, key: string, value: Value, pyBuiltins: PyObject) =
  dict[key] = valueToPy(value, pyBuiltins)

proc blockToPyDict(blk: Block, pyBuiltins: PyObject): PyObject =
  let dict = pyBuiltins.dict()
  var seen = initHashSet[string]()
  for pair in blk.pairs:
    ensureUniqueKey(seen, pair.key, "block '" & blk.name & "'")
    insertValue(dict, pair.key, pair.value, pyBuiltins)
  for subBlock in blk.subBlocks:
    ensureUniqueKey(seen, subBlock.name, "block '" & blk.name & "'")
    dict[subBlock.name] = blockToPyDict(subBlock, pyBuiltins)
  return dict

proc toPython*(config: YumlyConf): PyObject =
  let pyBuiltins = pyBuiltinsModule()
  let root = pyBuiltins.dict()
  var seen = initHashSet[string]()
  for pair in config.pairs:
    ensureUniqueKey(seen, pair.key, "root")
    insertValue(root, pair.key, pair.value, pyBuiltins)
  for blk in config.blocks:
    ensureUniqueKey(seen, blk.name, "root")
    root[blk.name] = blockToPyDict(blk, pyBuiltins)
  return root

proc parseValue(value: PyObject, pyTypes: PyTypes, pyBuiltins: PyObject): Value =
  if pyBuiltins.callMethod("isinstance", value, pyTypes.noneType).to(bool):
    raise newException(ValueError, "Python None is not supported by Yumly values.")

  if pyBuiltins.callMethod("isinstance", value, pyTypes.bool).to(bool):
    return newBoolValue(value.to(bool))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.int).to(bool):
    return newIntValue(value.to(int))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.float).to(bool):
    return newFloatValue(value.to(float))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.str).to(bool):
    return newStringValue(value.to(string))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.list).to(bool) or
     pyBuiltins.callMethod("isinstance", value, pyTypes.`tuple`).to(bool):
    var elems: seq[Value] = @[]
    for item in value:
      elems.add(parseValue(item, pyTypes, pyBuiltins))

    return Value(kind: vkList, elements: elems)

  raise newException(ValueError, "Oh no.. failed to parse Python value, it's an unsupported Python type: " & $value)

proc parseBlock(name: string, data: PyObject, pyTypes: PyTypes, pyBuiltins: PyObject): Block =
  result = newBlock(name)
  let items = data.callMethod("items")
  for item in items:
    let keyStr = parseDictKey(item[0], pyTypes, pyBuiltins, "block '" & name & "'")
    let val = item[1]
    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      result.addSubBlock(parseBlock(keyStr, val, pyTypes, pyBuiltins))
    else:
      result.addPair(keyStr, parseValue(val, pyTypes, pyBuiltins))

proc dictToYumlyConf*(data: PyObject): YumlyConf =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  if pyBuiltins.isNil:
    raise newException(ValueError, "pyBuiltins is nil")

  let pyDictType = pyBuiltins.getAttr("dict")
  if pyDictType.isNil:
    raise newException(ValueError, "pyDictType is nil")

  let pyTypes = (
    bool: pyBuiltins.getAttr("bool"),
    int: pyBuiltins.getAttr("int"),
    float: pyBuiltins.getAttr("float"),
    str: pyBuiltins.getAttr("str"),
    list: pyBuiltins.getAttr("list"),
    `tuple`: pyBuiltins.getAttr("tuple"),
    dict: pyDictType,
    noneType: pyBuiltins.callMethod("type", pyBuiltins.None)
  )

  if not pyBuiltins.callMethod("isinstance", data, pyTypes.dict).to(bool):
    raise newException(ValueError, "Yumly Python input must be a dict.")

  result = newYumly()

  let items = data.callMethod("items")
  for item in items:
    let k = item[0]
    let val = item[1]

    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      let keyStr = parseDictKey(k, pyTypes, pyBuiltins, "root")
      result.addBlock(parseBlock(keyStr, val, pyTypes, pyBuiltins))
    else:
      let keyStr = parseDictKey(k, pyTypes, pyBuiltins, "root", isRootPair = true)
      result.addPair(keyStr, parseValue(val, pyTypes, pyBuiltins))

  for pair in result.pairs.mitems:
    if pair.typeHint.isNone:
      pair.typeHint = some(inferTypeHintObject(pair.value))
  for blk in result.blocks.mitems:
    for pair in blk.pairs.mitems:
      if pair.typeHint.isNone:
        pair.typeHint = some(inferTypeHintObject(pair.value))
    for sub in blk.subBlocks.mitems:
      for pair in sub.pairs.mitems:
        if pair.typeHint.isNone:
          pair.typeHint = some(inferTypeHintObject(pair.value))
