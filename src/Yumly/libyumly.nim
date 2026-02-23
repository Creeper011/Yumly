import nimpy
import types/ast
import yumly_file
import parser, tokenizer, additional/validate
import serializers/parser_python
import os

proc parseContentToAST(content: string): Config =
  let tokens = tokenize(content)
  result = generateAST(tokens)

proc parseFileToAST(path: string): Config =
  checkFileExtension(path)
  let content = openFileContent(path)
  return parseContentToAST(content)

proc validateContent*(content: string): bool {.exportpy.} =
  try:
    var config = parseContentToAST(content)
    validateConfig(config, skipInclude = true, skipEnv = true)
    return true
  except ValueError as error:
    echo error.msg
    return false

proc validateFile*(path: string): bool {.exportpy.} =
  try:
    var config = parseFileToAST(path)
    validateConfig(config, skipInclude = true, skipEnv = true)
    return true
  except ValueError as error:
    echo error.msg
    return false

proc validateContentWithErrMsg*(content: string): string {.exportpy: "validateContentMsg".} =
  try:
    var config = parseContentToAST(content)
    validateConfig(config, skipInclude = true, skipEnv = true)
    return ""
  except ValueError as error:
    return error.msg

proc validateFileWithErrMsg*(path: string): string {.exportpy: "validateFileMsg".} =
  try:
    var config = parseFileToAST(path)
    validateConfig(config, skipInclude = true, skipEnv = true)
    return ""
  except ValueError as error:
    return error.msg

proc loadYumly*(path: string = "config.yumly"): Config =
  var config = parseFileToAST(path)
  validateConfig(config, skipInclude = false, skipEnv = false)
  return config

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  var config = parseFileToAST(path)
  validateConfig(config, skipInclude = false, skipEnv = false)
  return config.toPython()