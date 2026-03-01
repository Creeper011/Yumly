import nimpy
import os
import yumly_file
import tokenizer, parser, resolver, additional/include_loader, additional/validate, evaluator
import serializers/parser_python
import types/ast

proc parseContentToAST*(content: string): YumNode =
  let tokens = tokenize(content)
  let ast = generateAST(tokens)
  resolveAst(ast)
  return ast

proc parseFileToAST*(path: string): YumNode =
  checkFileExtension(path)
  let content = openFileContent(path)
  return parseContentToAST(content)

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

proc loadYumly*(path: string = "config.yumly"): Config =
  var ast = parseFileToAST(path)
  loadIncludes(ast, parentDir(path))
  resolveAst(ast)
  validateConfig(ast)
  return evaluateConfig(ast)

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  let config = loadYumly(path)
  return config.toPython()
