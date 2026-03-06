import nimpy
import os
import yumly_file
import tokenizer, parser, resolver, additional/include_loader, additional/validate, evaluator
import serializers/parser_python, serializers/parser_yumyumy, serializers/encoder
import types/ast
import api/nim_api, api/python_api
export nim_api

proc parseContentToAST*(content: string): YumNode =
  let tokens = tokenize(content)
  let ast = generateAST(tokens)
  resolveAst(ast)
  return ast

proc parseFileToAST*(path: string): YumNode =
  checkFileExtension(path)
  let content = openFileContent(path)
  return parseContentToAST(content)

proc writeYumly*(config: YumlyKind, path: string) =
  writeFile(path, encoder.dumpYumly(config))

proc validateContent*(content: string): bool {.exportpy.} =
  try:
    var ast = parseContentToAST(content)
    resolveAst(ast)
    validateConfig(ast)
    return true
  except ValueError, IOError:
    let error = getCurrentException()
    echo error.msg
    return false

proc validateFile*(path: string): bool {.exportpy.} =
  try:
    var ast = parseFileToAST(path)
    resolveAst(ast)
    validateConfig(ast)
    return true
  except ValueError, IOError:
    let error = getCurrentException()
    echo error.msg
    return false

proc validateContentWithErrMsg*(content: string): string {.exportpy: "validateContentMsg".} =
  try:
    var ast = parseContentToAST(content)
    resolveAst(ast)
    validateConfig(ast)
    return ""
  except ValueError, IOError:
    let error = getCurrentException()
    return error.msg

proc validateFileWithErrMsg*(path: string): string {.exportpy: "validateFileMsg".} =
  try:
    var ast = parseFileToAST(path)
    resolveAst(ast)
    validateConfig(ast)
    return ""
  except ValueError, IOError:
    let error = getCurrentException()
    return error.msg

proc validateContentMsgFFI*(content: cstring): cstring {.exportc: "validateContentMsg", dynlib.} =
  try:
    var ast = parseContentToAST($content)
    resolveAst(ast)
    validateConfig(ast)
    return ""
  except ValueError, IOError:
    let error = getCurrentException()
    return error.msg.cstring

proc validateFileMsgFFI*(path: cstring): cstring {.exportc: "validateFileMsg", dynlib.} =
  try:
    var ast = parseFileToAST($path)
    resolveAst(ast)
    validateConfig(ast)
    return ""
  except ValueError, IOError:
    let error = getCurrentException()
    return error.msg.cstring

proc loadYumly*(path: string = "config.yumly"): YumlyKind =
  var ast = parseFileToAST(path)
  loadIncludes(ast, parentDir(path))
  resolveAst(ast)
  validateConfig(ast)
  return evaluateConfig(ast)

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyKind =
  var ast = parseContentToAST(content)
  loadIncludes(ast, workingDir)
  resolveAst(ast)
  validateConfig(ast)
  return evaluateConfig(ast)

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  let config = loadYumly(path)
  return config.toPython()

proc dumpPy*(data: PyObject): string {.exportpy.} =
  if data.isNil:
    raise newException(ValueError, "HEYY! data is nil")
  let config = dictToYumlyKind(data)
  result = encoder.dumpYumly(config)

proc loadYumyumyFFI*(path: cstring): cstring {.exportc: "loadYumyumy", dynlib.} =
  try:
    let config = loadYumly($path)
    return config.toYumyumy().cstring
  except ValueError, IOError:
    let error = getCurrentException()
    return ("Error: " & error.msg).cstring

proc loadYumyumy*(path: string): string =
  try:
    let config = loadYumly(path)
    return config.toYumyumy()
  except ValueError, IOError:
    let error = getCurrentException()
    raise error