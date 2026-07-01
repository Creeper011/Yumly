##
# Yumly Python serializers for converting Nim values to Python values:
# 1. Convert evaluated configs to/from Python dictionaries.
# 2. Map partial pipeline tokens and nodes for load_until APIs.
##

import nimpy
import sets, strutils, options
import ../../types/ast
import ../../types/nodes
import ../../types/source
import ../../types/token
import ../../types/typehints
import ../../core/builders

type
  PyTypes = tuple[bool, int, float, str, list, `tuple`, dict,
      noneType: PyObject]

func isYumlyIdent(name: string): bool =
  ## Check if the ident/name is yumly compatible
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

proc valueToPy(value: Value, pyBuiltins: PyObject): PyObject
proc blockToPyDict(blk: Block, pyBuiltins: PyObject): PyObject

proc valueToPy(value: Value, pyBuiltins: PyObject): PyObject =
  when defined(yumlyEnv):
    if value.kind == vkEnv:
      return pyBuiltins.str(value.envVal)

  case value.kind
  of vkString:
    result = pyBuiltins.str(value.strVal)
  of vkBool:
    result = pyBuiltins.bool(value.boolVal)
  of vkInt:
    result = pyBuiltins.int(value.intVal)
  of vkFloat:
    result = pyBuiltins.float(value.floatVal)
  of vkList:
    let pyList = pyBuiltins.list()
    for item in value.elements:
      case item.kind
      of ikPair:
        let dict = pyBuiltins.dict()
        dict[item.pair.key] = valueToPy(item.pair.value, pyBuiltins)
        discard pyList.append(dict)
      of ikValue:
        discard pyList.append(valueToPy(item.value, pyBuiltins))
      of ikBlock:
        let dict = pyBuiltins.dict()
        dict[item.blk.name] = blockToPyDict(item.blk, pyBuiltins)
        discard pyList.append(dict)
      of ikSchema:
        discard
    result = pyList
  of vkObject:
    var onlyNamedItems = true
    for item in value.items:
      if item.kind == ikValue:
        onlyNamedItems = false
        break

    if onlyNamedItems:
      let dict = pyBuiltins.dict()
      for item in value.items:
        case item.kind
        of ikPair:
          dict[item.pair.key] = valueToPy(item.pair.value, pyBuiltins)
        of ikBlock:
          dict[item.blk.name] = blockToPyDict(item.blk, pyBuiltins)
        of ikValue:
          discard
        of ikSchema:
          discard
      result = dict
    else:
      let pyList = pyBuiltins.list()
      for item in value.items:
        case item.kind
        of ikPair:
          let dict = pyBuiltins.dict()
          dict[item.pair.key] = valueToPy(item.pair.value, pyBuiltins)
          discard pyList.append(dict)
        of ikValue:
          discard pyList.append(valueToPy(item.value, pyBuiltins))
        of ikBlock:
          let dict = pyBuiltins.dict()
          dict[item.blk.name] = blockToPyDict(item.blk, pyBuiltins)
          discard pyList.append(dict)
        of ikSchema:
          discard
      result = pyList
  else:
    discard

proc insertValue(dict: PyObject, key: string, value: Value,
    pyBuiltins: PyObject) =
  dict[key] = valueToPy(value, pyBuiltins)

proc blockToPyDict(blk: Block, pyBuiltins: PyObject): PyObject =
  let dict = pyBuiltins.dict()
  var seen = initHashSet[string]()
  for item in blk.items:
    case item.kind
    of ikPair:
      ensureUniqueKey(seen, item.pair.key, "block '" & blk.name & "'")
      insertValue(dict, item.pair.key, item.pair.value, pyBuiltins)
    of ikBlock:
      ensureUniqueKey(seen, item.blk.name, "block '" & blk.name & "'")
      dict[item.blk.name] = blockToPyDict(item.blk, pyBuiltins)
    of ikValue, ikSchema:
      discard
  return dict

proc toPython*(config: YumlyConf): PyObject =
  let pyBuiltins = pyBuiltinsModule()
  let root = pyBuiltins.dict()
  var seen = initHashSet[string]()
  for item in config.items:
    case item.kind
    of ikPair:
      ensureUniqueKey(seen, item.pair.key, "root")
      insertValue(root, item.pair.key, item.pair.value, pyBuiltins)
    of ikBlock:
      ensureUniqueKey(seen, item.blk.name, "root")
      root[item.blk.name] = blockToPyDict(item.blk, pyBuiltins)
    of ikValue, ikSchema:
      discard
  return root

proc tokenToPy*(token: Token, pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.dict()
  result["kind"] = pyBuiltins.str($token.kind)
  result["line"] = pyBuiltins.int(int(token.source.line))
  result["col"] = pyBuiltins.int(int(token.source.col))
  result["endLine"] = pyBuiltins.int(int(token.source.endLine))
  result["endCol"] = pyBuiltins.int(int(token.source.endCol))
  if token.source.source != nil:
    result["sourceFile"] = pyBuiltins.str(token.source.source.path)
  if token.kind in {tkString, tkIdent, tkLiteral}:
    result["value"] = pyBuiltins.str(token.value)

proc tokensToPy*(tokens: openArray[Token], pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.list()
  for token in tokens:
    discard result.append(tokenToPy(token, pyBuiltins))

proc nodeToPy*(node: YumNode, pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.dict()
  result["kind"] = pyBuiltins.str($node.kind)
  result["name"] = pyBuiltins.str(node.name)
  result["line"] = pyBuiltins.int(int(node.line))
  result["col"] = pyBuiltins.int(int(node.col))
  if node.sourceFile != nil:
    result["sourceFile"] = pyBuiltins.str(node.sourceFile.path)

  when defined(yumlyEnv):
    if node.kind == nkEnv:
      result["envName"] = pyBuiltins.str(node.envName)
      if node.coerceType.isSome:
        result["coerceType"] = pyBuiltins.str(node.coerceType.get.raw)
      if node.envDefault.isSome:
        result["envDefault"] = pyBuiltins.str(node.envDefault.get())
      return

  case node.kind:
  of nkLiteral:
    result["rawValue"] = pyBuiltins.str(node.rawValue)
  of nkPairStart:
    result["key"] = pyBuiltins.str(node.key)
    if node.typeHint.isSome:
      result["typeHint"] = pyBuiltins.str(node.typeHint.get().raw)
  of nkSchemaBlockStart:
    result["required"] = pyBuiltins.bool(node.required)
  of nkSchemaTypedBlock:
    result["blockType"] = pyBuiltins.str(node.blockType.raw)
  of nkInclude:
    let paths = pyBuiltins.list()
    for path in node.includesPath:
      discard paths.append(pyBuiltins.str(path))
    result["includesPath"] = paths
  of nkListStart, nkListEnd, nkObjectStart, nkObjectEnd, nkSchemaStart,
      nkSchemaEnd, nkSchemaBlockEnd, nkBlockStart, nkBlockEnd, nkPairEnd,
      nkEOF:
    discard
  else:
    discard

proc nodesToPy*(nodes: openArray[YumNode], pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.list()
  for node in nodes:
    discard result.append(nodeToPy(node, pyBuiltins))

proc parseValue(value: PyObject, pyTypes: PyTypes,
    pyBuiltins: PyObject): Value =
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
    var elems: seq[Item] = @[]
    for item in value:
      elems.add(Item(kind: ikValue, value: parseValue(item, pyTypes, pyBuiltins)))

    return Value(kind: vkList, elements: elems)

  if pyBuiltins.callMethod("isinstance", value, pyTypes.dict).to(bool):
    var items: seq[Item] = @[]
    for item in value.callMethod("items"):
      let keyStr = parseDictKey(item[0], pyTypes, pyBuiltins, "object value")
      let pair = Pair(key: keyStr, value: parseValue(item[1], pyTypes,
          pyBuiltins), typeHint: none(TypeHint),
          source: sourceSpan(nil, SourcePos(0), SourcePos(0)))
      items.add(Item(kind: ikPair, pair: pair))
    return Value(kind: vkObject, schema: none(Schema), items: items)

  raise newException(ValueError, "Oh no.. failed to parse Python value, it's an unsupported Python type: " & $value)

proc parseBlock(name: string, data: PyObject, pyTypes: PyTypes,
    pyBuiltins: PyObject): Block =
  result = newBlock(name)
  let items = data.callMethod("items")
  for item in items:
    let keyStr = parseDictKey(item[0], pyTypes, pyBuiltins, "block '" & name & "'")
    let val = item[1]
    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      result.addSubBlock(parseBlock(keyStr, val, pyTypes, pyBuiltins))
    else:
      result.addPair(keyStr, parseValue(val, pyTypes, pyBuiltins))

proc inferPythonItemHints(items: var seq[Item])

proc inferPythonValueHints(value: var Value) =
  case value.kind
  of vkList:
    inferPythonItemHints(value.elements)
  of vkObject:
    inferPythonItemHints(value.items)
  else:
    discard

proc inferPythonItemHints(items: var seq[Item]) =
  for item in items.mitems:
    case item.kind
    of ikPair:
      if item.pair.typeHint.isNone:
        item.pair.typeHint = some(typeHintFor(item.pair.value))
      inferPythonValueHints(item.pair.value)
    of ikValue:
      inferPythonValueHints(item.value)
    of ikBlock:
      inferPythonItemHints(item.blk.items)
    of ikSchema:
      discard

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
      let keyStr = parseDictKey(k, pyTypes, pyBuiltins, "root",
          isRootPair = true)
      result.addPair(keyStr, parseValue(val, pyTypes, pyBuiltins))

  inferPythonItemHints(result.items)
