##
# Python API to create Yumly files (this modules only create data, not serialize. serializer is in serializers/parser_python)
##
import nimpy, os, strutils
import ../types/ast, ../types/nodes
import ../tokenizer, ../parser, ../resolver, ../evaluator
import ../additional/include_loader, ../additional/validate
import nim_api

proc parseContentToAST*(content: string): YumNode =
  let tokens = tokenize(content)
  let ast = generateAST(tokens)
  resolveAst(ast)
  return ast

proc parseFileToAST*(path: string): YumNode =
  let content = readFile(path)
  parseContentToAST(content)

proc loadYumly*(path: string): YumlyConf =
  var ast = parseFileToAST(path)
  loadIncludes(ast, parentDir(path))
  resolveAst(ast)
  validateConfig(ast)
  return evaluateConfig(ast)

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyConf =
  var ast = parseContentToAST(content)
  loadIncludes(ast, workingDir)
  resolveAst(ast)
  validateConfig(ast)
  return evaluateConfig(ast)

proc newYumly*(): YumlyConf =
  YumlyConf(blocks: @[], pairs: @[], includes: @[])

proc parseValue(value: PyObject, pyTypes: tuple[bool, int, float, str, list, `tuple`, dict: PyObject], pyBuiltins: PyObject): Value =
  if pyBuiltins.callMethod("isinstance", value, pyTypes.bool).to(bool):
    return newBoolValue(value.to(bool))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.int).to(bool):
    return newIntValue(value.to(int))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.float).to(bool):
    return newFloatValue(value.to(float))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.str).to(bool):
    return newStringValue(value.to(string))

  if pyBuiltins.callMethod("isinstance", value, pyTypes.list).to(bool) or pyBuiltins.callMethod("isinstance", value, pyTypes.`tuple`).to(bool):
    var elems: seq[Value] = @[]
    for item in value:
      elems.add(parseValue(item, pyTypes, pyBuiltins))
    return newListValue(elems)

  raise newException(ValueError, "Oh no.. failed to parse Python value, it's an unsupported Python type: " & $value)

proc parseBlock(name: string, data: PyObject, pyTypes: tuple[bool, int, float, str, list, `tuple`, dict: PyObject], pyBuiltins: PyObject): Block =
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
    
    # note: for some reason pyBuiltins.isInstance are causing SIGSEGV Error
    if pyBuiltins.callMethod("isinstance", val, pyTypes.dict).to(bool):
      result.addBlock(parseBlock(safeKey, val, pyTypes, pyBuiltins))
    else:
      result.addPair(safeKey, parseValue(val, pyTypes, pyBuiltins))
