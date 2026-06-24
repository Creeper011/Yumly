##
# This module defines structured errors used while processing Yumly input.
##

type
  YumlyError* = object of ValueError
    line*: int
    col*: int
    endLine*: int
    endCol*: int
    code*: string
    sourceFile*: string

  YumlyIOError* = object of IOError
    line*: int
    col*: int
    endLine*: int
    endCol*: int
    code*: string
    sourceFile*: string

  Expected* = enum
    expValue = "a value"
    expIdentifier = "an identifier"
    expString = "a string"
    expInteger = "an integer"
    expFloat = "a float"
    expBoolean = "a boolean"
    expEnvVar = "an environment variable"
    expBlockName = "a block name"
    expEquals = "'='"
    expLBrace = "'{'"
    expRBrace = "'}'"
    expLBracket = "'['"
    expRBracket = "']'"
    expComma = "','"
    expBlockComma = "a comma"
    expQuestion = "'?'"
    expEOF = "end of file"

proc newYumlyError*(message: string, line: int, col: int, code: string,
    sourceFile: string = ""): ref YumlyError =
  result = newException(YumlyError, message)
  result.line = line
  result.col = col
  result.endLine = line
  result.endCol = col + 1
  result.code = code
  result.sourceFile = sourceFile

proc newYumlyError*(message: string, line: int, col: int, endLine: int,
    endCol: int, code: string, sourceFile: string = ""): ref YumlyError =
  result = newException(YumlyError, message)
  result.line = line
  result.col = col
  result.endLine = endLine
  result.endCol = endCol
  result.code = code
  result.sourceFile = sourceFile

proc newYumlyIOError*(message: string, line, col: int, code: string,
    sourceFile: string = ""): ref YumlyIOError =
  result = newException(YumlyIOError, message)
  result.line = line
  result.col = col
  result.endLine = line
  result.endCol = col + 1
  result.code = code
  result.sourceFile = sourceFile
