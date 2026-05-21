import nimpy
import options, strutils
import ../types/ast, ../types/type_hints, ../utils/value_utils
import ../core/builders

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
    # NOTE: in yumly, tuple is not an tuple object like python
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

proc applyPythonTypeHints(pairs: var seq[Pair]) =
  for p in pairs.mitems:
    if not p.typeHint.isSome:
      p.typeHint = some(TypeHint(raw: inferTypeHint(p.value), kind: thUnknown))

proc applyPythonTypeHintsRec(blocks: var seq[Block]) =
  for b in blocks.mitems:
    applyPythonTypeHints(b.pairs)
    applyPythonTypeHintsRec(b.subBlocks)

proc applyPythonTypeHints*(config: var YumlyConf) =
  applyPythonTypeHints(config.pairs)
  applyPythonTypeHintsRec(config.blocks)

proc parseValue(value: PyObject, pyTypes: tuple[bool, int, float, str, list, `tuple`,
    dict: PyObject], pyBuiltins: PyObject): Value =
  if pyBuiltins.callMethod("isinstance", value, pyTypes.bool).to(bool):
    return newBoolValue(value.to(bool))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.int).to(bool):
    return newIntValue(value.to(int))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.float).to(bool):
    return newFloatValue(value.to(float))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.str).to(bool):
    return newStringValue(value.to(string))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.list).to(bool) or pyBuiltins.callMethod(
      "isinstance", value, pyTypes.`tuple`).to(bool):
    var elems: seq[Value] = @[]
    for item in value:
      elems.add(parseValue(item, pyTypes, pyBuiltins))
    return newListValue(elems)

  raise newException(ValueError, "Oh no.. failed to parse Python value, it's an unsupported Python type: " & $value)

proc parseBlock(name: string, data: PyObject, pyTypes: tuple[bool, int, float, str, list, `tuple`,
    dict: PyObject], pyBuiltins: PyObject): Block =
  result = newBlock(name)
  let items = data.callMethod("items")
  for item in items:
    let keyStr = item[0].to(string)
    let val = item[1]
    let safeKey = keyStr.replace(" ", "_")
    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      result.addSubBlock(parseBlock(safeKey, val, pyTypes, pyBuiltins))
    else:
      result.addPair(safeKey, parseValue(val, pyTypes, pyBuiltins))

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
    dict: pyDictType
  )

  result = newYumly()

  let items = data.callMethod("items")
  for item in items:
    let k = item[0]
    let keyStr = k.to(string)
    let val = item[1]
    let safeKey = keyStr.replace(" ", "_")

    if val.isNil:
      continue

    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      result.addBlock(parseBlock(safeKey, val, pyTypes, pyBuiltins))
    else:
      result.addPair(safeKey, parseValue(val, pyTypes, pyBuiltins))

  applyPythonTypeHints(result)

import ../types/nodes, ../types/token

proc tokenToPy*(t: Token, pyBuiltins: PyObject): PyObject =
  let dict = pyBuiltins.dict()
  dict["kind"] = pyBuiltins.str($t.kind)
  dict["line"] = pyBuiltins.int(t.line)
  dict["col"] = pyBuiltins.int(t.col)
  if t.kind in {tkString, tkIdent, tkLiteral}:
    dict["value"] = pyBuiltins.str(t.value)
  return dict

proc astToPy*(node: YumNode, pyBuiltins: PyObject): PyObject =
  if node == nil: return pyBuiltins.None
  let dict = pyBuiltins.dict()
  dict["kind"] = pyBuiltins.str($node.kind)
  dict["name"] = pyBuiltins.str(node.name)
  dict["line"] = pyBuiltins.int(node.line)
  dict["col"] = pyBuiltins.int(node.col)
  if node.sourceFile != "": dict["sourceFile"] = pyBuiltins.str(node.sourceFile)
  
  case node.kind:
  of nkLiteral:
    dict["rawValue"] = pyBuiltins.str(node.rawValue)
  of nkPair:
    dict["key"] = pyBuiltins.str(node.key)
    if node.typeHint.isSome:
      dict["typeHint"] = pyBuiltins.str(node.typeHint.get().raw)
    dict["valNode"] = astToPy(node.valNode, pyBuiltins)
  of nkInclude:
    dict["includePath"] = pyBuiltins.str(node.includePath)
  of nkConfig:
    if node.hasIncludes.isSome: dict["hasIncludes"] = pyBuiltins.bool(node.hasIncludes.get())
    if node.hasTypeHints.isSome: dict["hasTypeHints"] = pyBuiltins.bool(node.hasTypeHints.get())
    if node.hasEnvVars.isSome: dict["hasEnvVars"] = pyBuiltins.bool(node.hasEnvVars.get())
  else: discard

  if node.children.len > 0:
    let childrenPy = pyBuiltins.list()
    for child in node.children:
      discard childrenPy.append(astToPy(child, pyBuiltins))
    dict["children"] = childrenPy
  return dict
