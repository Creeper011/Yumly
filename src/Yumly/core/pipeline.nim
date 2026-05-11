##
# This module defines the pipeline process to build an yumly config
# steps: tokenizer (pull) -> parser (recursive descent) -> includes -> resolver -> validator -> evaluator
##

import os, options, streams
import ../yumly_file
import ../phases/tokenizer
import ../phases/parser
import ../phases/resolver
import ../phases/evaluator
import ../phases/load_include
import ../phases/validate
import ../serializers/encoder
import ../types/ast
import ../types/nodes

proc parseContentToAST*(content: string): YumNode =
  let stream = newStringStream(content)
  let puller = tokenize(stream)
  var parser = newParser(puller)
  result = parser.parse()

proc parseFileToAST*(path: string): YumNode =
  let stream = newYumlyStream(path)
  let puller = tokenize(stream)
  var parser = newParser(puller)
  result = parser.parse()
  result.sourceFile = os.absolutePath(path)
  stream.close()

proc resolveYumly*(ast: var YumNode; workingDir: string) =
  if ast.hasIncludes.get(false):
    loadIncludes(ast, workingDir)

  if ast.hasTypeHints.get(false):
    resolveAst(ast)

proc validateYumly*(ast: var YumNode) =
  validateConfig(ast)

proc evaluateYumly*(ast: YumNode): YumlyConf =
  result = evaluateConfig(ast)

proc dumpYumly*(config: YumlyConf): string =
  result = encoder.dumpYumly(config)

proc writeYumly*(config: YumlyConf; path: string) =
  writeFile(path, encoder.dumpYumly(config))

proc loadYumly*(path: string = "config.yumly"): YumlyConf =
  var ast = parseFileToAST(path)
  resolveYumly(ast, parentDir(path))
  validateYumly(ast)
  result = evaluateYumly(ast)

proc loadYumlyContent*(content: string; workingDir: string = "."): YumlyConf =
  var ast = parseContentToAST(content)
  resolveYumly(ast, workingDir)
  validateYumly(ast)
  result = evaluateYumly(ast)

proc loadYumlyFast*(path: string): YumlyConf =
  let ast = parseFileToAST(path)
  result = evaluateYumly(ast)

proc loadYumlyContentFast*(content: string; workingDir: string = "."): YumlyConf =
  let ast = parseContentToAST(content)
  result = evaluateYumly(ast)

proc validateContent*(content: string; workingDir: string = "."): bool =
  try:
    var ast = parseContentToAST(content)
    resolveYumly(ast, workingDir)
    validateYumly(ast)
    return true
  except CatchableError:
    return false

proc validateFile*(path: string): bool =
  try:
    var ast = parseFileToAST(path)
    resolveYumly(ast, parentDir(path))
    validateYumly(ast)
    return true
  except CatchableError:
    return false
