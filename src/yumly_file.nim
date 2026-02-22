import os, strutils

proc checkFileExtension*(path: string) =
  # accept .yumly or .yuy; reject anything else
  if not (path.endsWith(".yumly") or path.endsWith(".yuy")):
    raise newException(ValueError, "Heyy, the file should have a .yumly or .yuy extension :<, but i found: " & path)

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    raise newException(ValueError, ":( I didn't find the file: " & filePath)
  readFile(filePath)