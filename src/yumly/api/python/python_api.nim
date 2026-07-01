static:
  echo "defined(python) = ", defined(python)
when not defined(python):
  {.error: "python_api.nim requires -d:python".}

##
# Python API to load Yumly files/content (this modules only create data, not serialize. serializer is in serializers/python)
##

import nimpy
import ../../types/ast
import ../../types/errors
import ../../types/source
import ../../core/pipeline
import ../../serializers/python/parser_python
import ../../serializers/yumly/encoder
import ../../serializers/yumyumy/yumyumyencoder

proc sourceSpanToPy(span: SourceSpan, pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.dict()
  result["sourceFile"] = pyBuiltins.str(
      if span.source != nil: span.source.path else: "")
  result["line"] = pyBuiltins.int(int(span.line))
  result["col"] = pyBuiltins.int(int(span.col))
  result["endLine"] = pyBuiltins.int(int(span.endLine))
  result["endCol"] = pyBuiltins.int(int(span.endCol))

proc diagnosticToPy(code, message: string, primary: SourceSpan,
    sources: openArray[SourceSpan]): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["code"] = pyBuiltins.str(code)
  result["message"] = pyBuiltins.str(message)
  result["line"] = pyBuiltins.int(int(primary.line))
  result["col"] = pyBuiltins.int(int(primary.col))
  result["endLine"] = pyBuiltins.int(int(primary.endLine))
  result["endCol"] = pyBuiltins.int(int(primary.endCol))
  result["sourceFile"] = pyBuiltins.str(
      if primary.source != nil: primary.source.path else: "")
  let pySources = pyBuiltins.list()
  for span in sources:
    discard pySources.append(sourceSpanToPy(span, pyBuiltins))
  result["sources"] = pySources

proc successResult(value: PyObject): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["value"] = value

proc failureResult(code, message: string, primary: SourceSpan,
    sources: openArray[SourceSpan]): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["diagnostic"] = diagnosticToPy(code, message, primary, sources)

template withDiagnostics(body: untyped): PyObject =
  try:
    successResult(body)
  except YumlyError as error:
    failureResult($error.code, error.msg,
        if error.source.len > 0: error.source[0]
        else: SourceSpan(),
        error.source)
  except YumlyIOError as error:
    failureResult($error.code, error.msg,
        if error.source.len > 0: error.source[0]
        else: SourceSpan(),
        error.source)
  except CatchableError as error:
    failureResult("undefined" & $error.name, error.msg, SourceSpan(), [])

proc validateContent*(content: string): bool {.exportpy.} =
  try:
    discard pipeline.loadYumlyContent(content)
    return true
  except ValueError, IOError:
    raise getCurrentException()

proc validateFile*(path: string): bool {.exportpy.} =
  try:
    discard pipeline.loadYumly(path)
    return true
  except ValueError, IOError:
    raise getCurrentException()

proc validateContentMsg*(content: string): string {.exportpy: "validateContentMsg".} =
  try:
    discard pipeline.loadYumlyContent(content)
    return ""
  except ValueError, IOError:
    return getCurrentException().msg

proc validateFileMsg*(path: string): string {.exportpy: "validateFileMsg".} =
  try:
    discard pipeline.loadYumly(path)
    return ""
  except ValueError, IOError:
    return getCurrentException().msg

proc evaluatedConfigToPy(config: YumlyConf, pyBuiltins: PyObject): PyObject =
  ## YumlyData keeps the evaluated mapping and its exact Yumyumy rendering.
  result = pyBuiltins.dict()
  result["data"] = config.toPython()
  result["yumyumy"] = pyBuiltins.str(yumyumyencoder.toYumyumy(config))

proc pipelineResultToPy(res: PipelineResult, pyBuiltins: PyObject): PyObject =
  case res.stage
  of psTokenizer:
    tokensToPy(res.tokens, pyBuiltins)
  of psParser, psIncludes, psResolver:
    nodesToPy(res.nodes, pyBuiltins)
  of psEvaluator, psValidator:
    evaluatedConfigToPy(res.config, pyBuiltins)

func parsePipelineStage(until: int): PipelineStage =
  if until < ord(low(PipelineStage)) or until > ord(high(PipelineStage)):
    raise newException(ValueError, "Invalid pipeline stage index: " & $until)
  PipelineStage(until)

proc loadYumlyPy*(path: string, until: int = 5): PyObject {.exportpy.} =
  let pyBuiltins = nimpy.pyBuiltinsModule()

  withDiagnostics:
    pipelineResultToPy(pipeline.loadYumly(path, parsePipelineStage(until)), pyBuiltins)

proc loadYumlyContentPy*(content: string, workingDir: string = ".",
    until: int = 5): PyObject {.exportpy.} =
  let pyBuiltins = nimpy.pyBuiltinsModule()

  withDiagnostics:
    pipelineResultToPy(pipeline.loadYumlyContent(content, parsePipelineStage(
        until), workingDir), pyBuiltins)

proc dumpPy*(data: PyObject): string {.exportpy.} =
  if data.isNil:
    raise newException(ValueError, "HEYY! data is nil")
  let config = dictToYumlyConf(data)
  result = encoder.dumpYumly(config)

proc dictToYumyumyPy*(data: PyObject): string {.exportpy.} =
  let config = dictToYumlyConf(data)
  yumyumyencoder.toYumyumy(config)

proc loadYumyumyPy*(path: string): string {.exportpy.} =
  let config = pipeline.loadYumly(path)
  yumyumyencoder.toYumyumy(config)

proc loadYumyumyContentPy*(content: string,
    workingDir: string = "."): string {.exportpy.} =
  let config = pipeline.loadYumlyContent(content, workingDir)
  yumyumyencoder.toYumyumy(config)
