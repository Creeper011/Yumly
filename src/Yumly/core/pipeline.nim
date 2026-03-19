import os
import ../yumly_file
import ../tokenizer
import ../parser
import ../resolver
import ../evaluator
import ../additional/include_loader
import ../additional/validate
import ../serializers/encoder
import ../types/ast
import ../types/nodes

proc parseContentToAST*(content: string): YumNode =
  let tokens = tokenize(content)
  result = generateAST(tokens)

proc parseFileToAST*(path: string): YumNode =
  checkFileExtension(path)
  let content = openFileContent(path)
  result = parseContentToAST(content)

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