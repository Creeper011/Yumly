import os, strutils

proc checkFileExtension*(path: string) =
  # check if file is an yumly file
  if not path.endsWith(".yumly"):
    raise newException(ValueError, "Heyy, the file should have a .yumly extension :<, but i found: " & path)

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    raise newException(ValueError, ":( I didn't find the file: " & filePath)
  readFile(filePath)