import os
import ../../core/pipeline
import ../../serializers/yumyumy/yumyumy_encoder

var lastFFIError {.threadvar.}: string

proc validateContentMsgFFI*(content: cstring, workingDir: cstring = "."): cstring {.exportc: "validateContentMsg", dynlib.} =
  try:
    let sContent = $content
    var ast = parseContentToAST(sContent)
    resolveYumly(ast, $workingDir)
    validateYumly(ast)
    return ""
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc validateFileMsgFFI*(path: cstring): cstring {.exportc: "validateFileMsg", dynlib.} =
  try:
    let sPath = $path
    var ast = parseFileToAST(sPath)
    resolveYumly(ast, parentDir(sPath))
    validateYumly(ast)
    return ""
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc loadYumyumyFFI*(path: cstring): cstring {.exportc: "loadYumyumy", dynlib.} =
  try:
    let config = loadYumly($path)
    return config.toYumyumy().cstring
  except ValueError, IOError:
    lastFFIError = getCurrentException().msg
    return lastFFIError.cstring

proc loadYumyumy*(path: string): string =
  let config = loadYumly(path)
  return config.toYumyumy()
