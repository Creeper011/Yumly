import nimpy
import os
import yumly_file
import tokenizer, parser, additional/validate, evaluator
import serializers/parser_python
import types/ast

proc parseContentToAST*(content: string): YumNode =
  let tokens = tokenize(content)
  return generateAST(tokens)

proc parseFileToAST*(path: string): YumNode =
  checkFileExtension(path)
  let content = openFileContent(path)
  return parseContentToAST(content)

proc validateContent*(content: string): bool {.exportpy.} =
  try:
    var ast = parseContentToAST(content)
    validateConfig(ast, skipInclude = true, skipEnv = true)
    return true
  except ValueError as error:
    echo error.msg
    return false

proc validateFile*(path: string): bool {.exportpy.} =
  try:
    var ast = parseFileToAST(path)
    validateConfig(ast, skipInclude = true, skipEnv = true)
    return true
  except ValueError as error:
    echo error.msg
    return false

proc validateContentWithErrMsg*(content: string): string {.exportpy: "validateContentMsg".} =
  try:
    var ast = parseContentToAST(content)
    validateConfig(ast, skipInclude = true, skipEnv = true)
    return ""
  except ValueError as error:
    return error.msg

proc validateFileWithErrMsg*(path: string): string {.exportpy: "validateFileMsg".} =
  try:
    var ast = parseFileToAST(path)
    validateConfig(ast, skipInclude = true, skipEnv = true)
    return ""
  except ValueError as error:
    return error.msg

proc loadYumly*(path: string = "config.yumly"): Config =
  var ast = parseFileToAST(path)
  validateConfig(ast, skipInclude = false, skipEnv = false)
  return evaluateConfig(ast)

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  let config = loadYumly(path)
  return config.toPython()