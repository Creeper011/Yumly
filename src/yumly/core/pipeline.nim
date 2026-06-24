##
# Yumly pipeline: tokenizer -> parser -> includes -> resolver -> evaluator -> validator.
# :3
##

import os, streams
import ../utils/file
import ../phases/tokenizer/tokenizer
import ../phases/parser/parser
import ../phases/includes/loader
import ../phases/resolver/resolver
import ../phases/evaluator/evaluator
import ../phases/validator/validate
import ../serializers/yumly/encoder
import ../types/[ast, nodes, token]

type
  PipelineStage* = enum
    psTokenizer
    psParser
    psIncludes
    psResolver
    psEvaluator
    psValidator

  PipelineResult* = object
    case stage*: PipelineStage
    of psTokenizer:
      tokens*: seq[Token]
    of psParser, psIncludes, psResolver:
      nodes*: seq[YumNode]
    of psEvaluator, psValidator:
      config*: YumlyConf

proc collectTokens(puller: TokenPuller): seq[Token] =
  while true:
    let token = puller()
    result.add(token)
    if token.kind == tkEOF:
      break

proc collectNodes(puller: NodePuller): seq[YumNode] =
  while true:
    let node = puller()
    result.add(node)
    if node.kind == nkEOF:
      break

proc runPipeline*(stream: Stream, until: PipelineStage = psValidator,
    workingDir: string = ".", sourceFile: string = ""): PipelineResult =
  result = PipelineResult(stage: until)

  let tokenPuller = tokenize(stream)
  if until == psTokenizer:
    result.tokens = collectTokens(tokenPuller)
    return

  let parsed = parseNodes(tokenPuller)
  if until == psParser:
    result.nodes = collectNodes(parsed)
    return

  let included = loadIncludes(parsed, workingDir, sourceFile)
  if until == psIncludes:
    result.nodes = collectNodes(included)
    return

  let resolved = resolveNodes(included)
  if until == psResolver:
    result.nodes = collectNodes(resolved)
    return

  result.config = evaluateNodes(resolved)
  if until == psEvaluator:
    return

  validateConfig(result.config)

# Api/Public procs:

proc loadYumly*(stream: Stream, until: PipelineStage,
    workingDir: string = "."): PipelineResult =
  runPipeline(stream, until, workingDir)

proc loadYumly*(stream: Stream, workingDir: string = "."): YumlyConf =
  runPipeline(stream, psValidator, workingDir).config

proc loadYumlyContent*(content: string, until: PipelineStage,
    workingDir: string = "."): PipelineResult =
  let stream = newStringStream(content)
  try:
    runPipeline(stream, until, workingDir)
  finally:
    stream.close()

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyConf =
  let stream = newStringStream(content)
  try:
    runPipeline(stream, psValidator, workingDir).config
  finally:
    stream.close()

proc loadYumly*(path: string, until: PipelineStage): PipelineResult =
  let stream = newYumlyStream(path)
  try:
    runPipeline(stream, until, parentDir(path), os.absolutePath(path))
  finally:
    stream.close()

proc loadYumly*(path: string = "config.yumly"): YumlyConf =
  let stream = newYumlyStream(path)
  try:
    runPipeline(stream, psValidator, parentDir(path), os.absolutePath(path)).config
  finally:
    stream.close()

func dumpYumly*(config: YumlyConf): string =
  encoder.dumpYumly(config)

proc writeYumly*(config: YumlyConf; path: string) =
  writeFile(path, encoder.dumpYumly(config))

proc validateContent*(content: string; workingDir: string = "."): bool =
  try:
    discard loadYumlyContent(content, workingDir)
    true
  except ValueError, IOError:
    false

proc validateFile*(path: string): bool =
  try:
    discard loadYumly(path)
    true
  except ValueError, IOError:
    false
