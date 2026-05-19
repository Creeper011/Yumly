import os, strutils, streams
import error_messages

const defaultMaxBytes = 52_428_800

proc checkFileExtension*(path: string) =
  if not (path.endsWith(".yumly") or path.endsWith(".yuy")):
    invalidFileExtensionError(path)

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    fileNotFoundError(filePath)
  readFile(filePath)

proc newYumlyStream*(path: string): Stream =
  checkFileExtension(path)
  if not fileExists(path):
    fileNotFoundError(path)

  let fileSize = getFileSize(path)
  if fileSize > defaultMaxBytes:
    raise newException(ValueError,
      "Heeeh?! the file '" & path & "' is too large to parse! (" &
      $fileSize & " bytes, limit is " & $defaultMaxBytes & " bytes) (>_<)")

  result = newFileStream(path, fmRead)
  if result == nil:
    # This shouldn't happen if fileExists is true, but good to be safe
    raise newException(IOError, "AHHH, Could not open file: " & path)
