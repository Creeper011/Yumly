import os, strutils

proc checkFileExtension*(path: string) =
  # accept .yumly or .yuy; reject anything else
  if not (path.endsWith(".yumly") or path.endsWith(".yuy")):
    raise newException(ValueError, "Mmm, that file it's not mine! :< you named it as: '" & path & "'. i can only read files with .yumly or .yuy extension")

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    raise newException(ValueError, "Heeeh?! i can't find the file nowhere... (T_T)\nI searched for:" & filePath & "\nHave you tried check if the file path is correct?")
  readFile(filePath)