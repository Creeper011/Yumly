import ../../core/pipeline
import ../../serializers/yumyumy/yumyumy_encoder

var lastFFIError {.threadvar.}: string
var lastFFIResult {.threadvar.}: string

proc validateContentMsgFFI*(content: cstring,
    workingDir: cstring = "."): cstring {.exportc: "validateContentMsg", dynlib.} =
  try:
    discard loadYumlyContent($content, $workingDir)
    return ""
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc validateFileMsgFFI*(path: cstring): cstring {.exportc: "validateFileMsg", dynlib.} =
  try:
    discard loadYumly($path)
    return ""
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc loadYumyumyFFI*(path: cstring): cstring {.exportc: "loadYumyumy", dynlib.} =
  try:
    let config = loadYumly($path)
    lastFFIResult = config.toYumyumy()
    return lastFFIResult.cstring
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc loadYumyumy*(path: string): string =
  let config = loadYumly(path)
  return config.toYumyumy()
