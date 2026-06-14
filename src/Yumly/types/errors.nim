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
    expEOF = "end of file"

proc newYumlyError*(message: string, line, col: int, code: string): ref YumlyError =
  result = newException(YumlyError, message)
  result.line = line
  result.col = col
  result.endLine = line
  result.endCol = col + 1
  result.code = code

proc newYumlyError*(message: string, line, col, endLine, endCol: int,
    code: string): ref YumlyError =
  result = newException(YumlyError, message)
  result.line = line
  result.col = col
  result.endLine = endLine
  result.endCol = endCol
  result.code = code
