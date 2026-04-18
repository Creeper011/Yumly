##
# This module defines the pipeline process to build an yumly config
# the steps in pipeline are: tokenizer (lexer) [Tokens]-> parser (ast) [YumNodes]-> include loader -> [YumNodes] resolver (resolve type hints) -> validator [value defs] -> evaluator (evaluate variables like env) [value defs]
# or: text -> encoder
##

import os
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
  let tokens = tokenize(content)
  result = createNodes(tokens)

proc parseFileToAST*(path: string): YumNode =
  checkFileExtension(path)
  let content = openFileContent(path)
  result = parseContentToAST(content)
  result.sourceFile = os.absolutePath(path)

proc resolveYumly*(ast: var YumNode; workingDir: string) =
  loadIncludes(ast, workingDir)
  resolveAst(ast)

proc validateYumly*(ast: var YumNode) =
  validateConfig(ast)

proc evaluateYumly*(ast: YumNode): YumlyConf =
  result = evaluateConfig(ast)

proc dumpYumly*(config: YumlyConf): string =
  result = encoder.dumpYumly(config)

proc writeYumly*(config: YumlyConf, path: string) =
  writeFile(path, encoder.dumpYumly(config))

proc loadYumly*(path: string = "config.yumly"): YumlyConf =
  var ast = parseFileToAST(path)
  resolveYumly(ast, parentDir(path))
  validateYumly(ast)
  result = evaluateYumly(ast)

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyConf =
  var ast = parseContentToAST(content)
  resolveYumly(ast, workingDir)
  validateYumly(ast)
  result = evaluateYumly(ast)

proc validateContent*(content: string, workingDir: string = "."): bool =
  try:
    var ast = parseContentToAST(content)
    resolveYumly(ast, workingDir)
    validateYumly(ast)
    return true
  except ValueError, IOError:
    return false

proc validateFile*(path: string): bool =
  try:
    var ast = parseFileToAST(path)
    resolveYumly(ast, parentDir(path))
    validateYumly(ast)
    return true
  except ValueError, IOError:
    return false
