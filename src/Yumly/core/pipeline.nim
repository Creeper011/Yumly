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
import ../types/token

type
  PipelineStage* = enum
    psTokenizer
    psParser
    psIncludes
    psResolver
    psValidator
    psEvaluator

  PipelineResult* = object
    case stage*: PipelineStage
    of psTokenizer:
      discard
    of psParser, psIncludes, psResolver, psValidator:
      ast*: YumNode
    of psEvaluator:
      config*: YumlyConf

proc runPipeline*(stream: Stream, until: PipelineStage = psEvaluator, workingDir: string = "."): PipelineResult =
  result = PipelineResult(stage: until)
  
  let puller = tokenize(stream)
  if until == psTokenizer:
    while true:
      let t = puller()
      if t.kind == tkEOF: break
    return

  var parser = newParser(puller)
  let ast = parser.parse()
  if until == psParser:
    result.ast = ast
    return

  if ast.hasIncludes.get(false):
    loadIncludes(ast, workingDir)
    
  if until == psIncludes:
    result.ast = ast
    return

  if ast.hasTypeHints.get(false):
    resolveAst(ast)
  
  if until == psResolver:
    result.ast = ast
    return

  validateConfig(ast)
  if until == psValidator:
    result.ast = ast
    return

  result.config = evaluateConfig(ast)

# Stream overloads
proc loadYumly*(stream: Stream, until: PipelineStage, workingDir: string = "."): PipelineResult =
  runPipeline(stream, until, workingDir)

proc loadYumly*(stream: Stream, workingDir: string = "."): YumlyConf =
  runPipeline(stream, psEvaluator, workingDir).config

# Content overloads
proc loadYumlyContent*(content: string, until: PipelineStage, workingDir: string = "."): PipelineResult =
  let stream = newStringStream(content)
  runPipeline(stream, until, workingDir)

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyConf =
  let stream = newStringStream(content)
  runPipeline(stream, psEvaluator, workingDir).config

# File overloads
proc loadYumly*(path: string, until: PipelineStage): PipelineResult =
  let stream = newYumlyStream(path)
  result = runPipeline(stream, until, parentDir(path))
  if result.stage in {psParser, psIncludes, psResolver, psValidator}:
    result.ast.sourceFile = os.absolutePath(path)
  stream.close()

proc loadYumly*(path: string = "config.yumly"): YumlyConf =
  let stream = newYumlyStream(path)
  let res = runPipeline(stream, psEvaluator, parentDir(path))
  stream.close()
  result = res.config

proc dumpYumly*(config: YumlyConf): string =
  result = encoder.dumpYumly(config)

proc writeYumly*(config: YumlyConf; path: string) =
  writeFile(path, encoder.dumpYumly(config))

proc validateContent*(content: string; workingDir: string = "."): bool =
  try:
    discard loadYumlyContent(content, psValidator, workingDir)
    return true
  except ValueError, IOError:
    return false

proc validateFile*(path: string): bool =
  try:
    discard loadYumly(path, psValidator)
    return true
  except ValueError, IOError:
    return false

proc parseContentToAST*(content: string): YumNode =
  loadYumlyContent(content, psParser).ast

proc parseFileToAST*(path: string): YumNode =
  loadYumly(path, psParser).ast

proc resolveYumly*(ast: YumNode, workingDir: string = ".") =
  if ast.hasIncludes.get(false):
    loadIncludes(ast, workingDir)
  if ast.hasTypeHints.get(false):
    resolveAst(ast)

proc validateYumly*(ast: YumNode) =
  validateConfig(ast)

proc loadYumlyFast*(path: string): YumlyConf =
  let ast = parseFileToAST(path)
  result = evaluateConfig(ast)

proc loadYumlyContentFast*(content: string; workingDir: string = "."): YumlyConf =
  let ast = parseContentToAST(content)
  result = evaluateConfig(ast)
