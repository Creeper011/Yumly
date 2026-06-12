static:
  echo "defined(python) = ", defined(python)
when not defined(python):
  {.error: "python_api.nim requires -d:python".}

##
# Python API to create Yumly files (this modules only create data, not serialize. serializer is in serializers/python)
##
import nimpy, os, streams
import ../../utils/file
import ../../types/ast
import ../../types/token
import ../../phases/tokenizer/tokenizer
import ../../core/pipeline
import ../../serializers/python/parser_python
import ../../serializers/yumly/encoder

proc validateContent*(content: string): bool {.exportpy.} =
  try:
    var res = pipeline.loadYumlyContent(content, psValidator)
    return true
  except ValueError, IOError:
    raise getCurrentException()

proc validateFile*(path: string): bool {.exportpy.} =
  try:
    var res = pipeline.loadYumly(path, psValidator)
    return true
  except ValueError, IOError:
    raise getCurrentException()

proc validateContentMsg*(content: string): string {.exportpy: "validateContentMsg".} =
  try:
    var res = pipeline.loadYumlyContent(content, psValidator)
    return ""
  except ValueError, IOError:
    return getCurrentException().msg

proc validateFileMsg*(path: string): string {.exportpy: "validateFileMsg".} =
  try:
    var res = pipeline.loadYumly(path, psValidator)
    return ""
  except ValueError, IOError:
    return getCurrentException().msg

proc loadYumlyPy*(path: string, until: int = 4): PyObject {.exportpy.} =
  let stage = PipelineStage(until)
  let pyBuiltins = nimpy.pyBuiltinsModule()
  
  if stage == psTokenizer:
    let stream = newYumlyStream(path)
    let tokensPy = pyBuiltins.list()
    try:
      let puller = tokenize(stream)
      while true:
        let tokenizer = puller()
        discard tokensPy.append(tokenToPy(tokenizer, pyBuiltins))
        if tokenizer.kind == tkEOF: break
    finally:
      stream.close()
    return tokensPy

  let res = pipeline.loadYumly(path, stage)
  case res.stage:
  of psTokenizer: return pyBuiltins.None
  of psParser, psIncludes, psResolver, psValidator:
    return astToPy(res.ast, pyBuiltins)
  of psEvaluator:
    return res.config.toPython()

proc loadYumlyContentPy*(content: string, workingDir: string = ".", until: int = 4): PyObject {.exportpy.} =
  let stage = PipelineStage(until)
  let pyBuiltins = nimpy.pyBuiltinsModule()

  if stage == psTokenizer:
    let stream = newStringStream(content)
    let tokensPy = pyBuiltins.list()
    try:
      let puller = tokenize(stream)
      while true:
        let tokenizer = puller()
        discard tokensPy.append(tokenToPy(tokenizer, pyBuiltins))
        if tokenizer.kind == tkEOF: break
    finally:
      stream.close()
    return tokensPy

  let res = pipeline.loadYumlyContent(content, stage, workingDir)
  case res.stage:
  of psTokenizer: return pyBuiltins.None
  of psParser, psIncludes, psResolver, psValidator:
    return astToPy(res.ast, pyBuiltins)
  of psEvaluator:
    return res.config.toPython()

proc evaluatedConfigToPy(config: YumlyConf, pyBuiltins: PyObject): PyObject =
  result = pyBuiltins.dict()
  result["data"] = config.toPython()
  result["yumyumy"] = pyBuiltins.str(config.toYumyumy())

proc loadYumlyEvaluatorPy*(path: string): PyObject {.exportpy.} =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  let config = pipeline.loadYumly(path)
  return evaluatedConfigToPy(config, pyBuiltins)

proc loadYumlyContentEvaluatorPy*(content: string, workingDir: string = "."): PyObject {.exportpy.} =
  let pyBuiltins = nimpy.pyBuiltinsModule()
  let config = pipeline.loadYumlyContent(content, workingDir)
  return evaluatedConfigToPy(config, pyBuiltins)

proc dumpPy*(data: PyObject): string {.exportpy.} =
  if data.isNil:
    raise newException(ValueError, "HEYY! data is nil")
  let config = dictToYumlyConf(data)
  result = encoder.dumpYumly(config)

proc dictToYumyumyPy*(data: PyObject): string {.exportpy.} =
  let config = dictToYumlyConf(data)
  return config.toYumyumy()

proc loadYumyumyPy*(path: string): string {.exportpy.} =
  let config = pipeline.loadYumly(path)
  return config.toYumyumy()

proc loadYumyumyContentPy*(content: string, workingDir: string = "."): string {.exportpy.} =
  let config = pipeline.loadYumlyContent(content, workingDir)
  return config.toYumyumy()
