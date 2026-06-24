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
import ../../core/pipeline
import ../../serializers/python/parser_python
import ../../serializers/yumly/encoder
import ../../serializers/yumyumy/yumyumy_encoder

proc diagnosticToPy(code, message: string, line, col, endLine, endCol: int,
    sourceFile: string): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["code"] = pyBuiltins.str(code)
  result["message"] = pyBuiltins.str(message)
  result["line"] = pyBuiltins.int(line)
  result["col"] = pyBuiltins.int(col)
  result["endLine"] = pyBuiltins.int(endLine)
  result["endCol"] = pyBuiltins.int(endCol)
  result["sourceFile"] = pyBuiltins.str(sourceFile)

proc successResult(value: PyObject): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["value"] = value

proc failureResult(code: string, message: string, line: int, col: int,
    endLine: int, endCol: int, sourceFile: string): PyObject =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  result = pyBuiltins.dict()
  result["diagnostic"] = diagnosticToPy(code, message, line, col, endLine,
      endCol, sourceFile)

template withDiagnostics(body: untyped): PyObject =
  try:
    successResult(body)
  except YumlyError as error:
    failureResult(error.code, error.msg, error.line, error.col, error.endLine,
        error.endCol, error.sourceFile)
  except YumlyIOError as error:
    failureResult(error.code, error.msg, error.line, error.col, error.endLine,
        error.endCol, error.sourceFile)
  except CatchableError as error:
    failureResult("undefined" & $error.name, error.msg, 0, 0, 0, 0,
        "") # NOTE: or just crash here

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
  result["yumyumy"] = pyBuiltins.str(yumyumy_encoder.toYumyumy(config))

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
    raise newYumlyError("Invalid pipeline stage index: " & $until, 0, 0, "python.invalid-pipeline-stage")
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
  yumyumy_encoder.toYumyumy(config)

proc loadYumyumyPy*(path: string): string {.exportpy.} =
  let config = pipeline.loadYumly(path)
  yumyumy_encoder.toYumyumy(config)

proc loadYumyumyContentPy*(content: string,
    workingDir: string = "."): string {.exportpy.} =
  let config = pipeline.loadYumlyContent(content, workingDir)
  yumyumy_encoder.toYumyumy(config)
