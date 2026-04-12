import os, strutils
import error_messages

proc checkFileExtension*(path: string) =
  if not (path.endsWith(".yumly") or path.endsWith(".yuy")):
    invalidFileExtensionError(path)

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    fileNotFoundError(filePath)
  readFile(filePath)