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
import ../types/[ast, nodes, source, token]

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

proc consumeTokens(puller: TokenPuller) =
  while puller().kind != tkEOF:
    discard

proc collectNodes(puller: NodePuller): seq[YumNode] =
  while true:
    let node = puller()
    result.add(node)
    if node.kind == nkEOF:
      break

proc consumeNodes(puller: NodePuller) =
  while puller().kind != nkEOF:
    discard

proc runPipeline(tokenPuller: TokenPuller, until: PipelineStage,
    workingDir: string, sourceFile: SourceFile,
    captureResult: bool): PipelineResult =
  result = PipelineResult(stage: until)

  if until == psTokenizer:
    if captureResult:
      result.tokens = collectTokens(tokenPuller)
    else:
      consumeTokens(tokenPuller)
    return

  let parsed = parseNodes(tokenPuller, sourceFile.documentKindFor())
  if until == psParser:
    if captureResult:
      result.nodes = collectNodes(parsed)
    else:
      consumeNodes(parsed)
    return

  let included = loadIncludes(parsed, workingDir, sourceFile)
  if until == psIncludes:
    if captureResult:
      result.nodes = collectNodes(included)
    else:
      consumeNodes(included)
    return

  let resolved = resolveNodes(included)
  if until == psResolver:
    if captureResult:
      result.nodes = collectNodes(resolved)
    else:
      consumeNodes(resolved)
    return

  let config = evaluateNodes(resolved)
  if until == psEvaluator:
    if captureResult:
      result.config = config
    return

  validateConfig(config)
  if captureResult:
    result.config = config

proc runPipeline*(stream: Stream, until: PipelineStage = psValidator,
    workingDir: string = ".", sourceFile: SourceFile = nil): PipelineResult =
  ## Runs the pipeline while reading the input incrementally from `stream`.
  runPipeline(tokenize(stream, sourceFile = sourceFile), until, workingDir,
      sourceFile, captureResult = true)

proc runPipeline*(content: sink string,
    until: PipelineStage = psValidator, workingDir: string = ".",
    sourceFile: SourceFile = nil): PipelineResult =
  ## Runs the same pull pipeline over content already resident in memory.
  runPipeline(tokenize(content, sourceFile), until, workingDir, sourceFile,
      captureResult = true)

proc consumePipeline*(stream: Stream,
    until: PipelineStage = psValidator, workingDir: string = ".",
    sourceFile: SourceFile = nil) =
  ## Runs a pipeline stage without retaining its final token/node/config result.
  discard runPipeline(tokenize(stream, sourceFile = sourceFile), until,
      workingDir, sourceFile, captureResult = false)

proc consumePipeline*(content: sink string,
    until: PipelineStage = psValidator, workingDir: string = ".",
    sourceFile: SourceFile = nil) =
  ## Runs a resident-content pipeline without retaining its final result.
  discard runPipeline(tokenize(content, sourceFile), until, workingDir,
      sourceFile, captureResult = false)

# Api/Public procs:

proc loadYumly*(stream: Stream, until: PipelineStage,
    workingDir: string = "."): PipelineResult =
  runPipeline(stream, until, workingDir)

proc loadYumly*(stream: Stream, workingDir: string = "."): YumlyConf =
  runPipeline(stream, psValidator, workingDir).config

proc loadYumlyContent*(content: string, until: PipelineStage,
    workingDir: string = "."): PipelineResult =
  runPipeline(content, until, workingDir)

proc loadYumlyContent*(content: string, workingDir: string = "."): YumlyConf =
  runPipeline(content, psValidator, workingDir).config

proc loadYumly*(path: string, until: PipelineStage): PipelineResult =
  let stream = newYumlyStream(path)
  try:
    runPipeline(stream, until, parentDir(path),
        SourceFile(path: os.absolutePath(path)))
  finally:
    stream.close()

proc loadYumly*(path: string = "config.yumly"): YumlyConf =
  let stream = newYumlyStream(path)
  try:
    runPipeline(stream, psValidator, parentDir(path),
        SourceFile(path: os.absolutePath(path))).config
  finally:
    stream.close()

proc consumeYumly*(path: string, until: PipelineStage = psValidator) =
  let stream = newYumlyStream(path)
  try:
    consumePipeline(stream, until, parentDir(path),
        SourceFile(path: os.absolutePath(path)))
  finally:
    stream.close()

proc consumeYumlyContent*(content: string,
    until: PipelineStage = psValidator, workingDir: string = ".") =
  consumePipeline(content, until, workingDir)

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
