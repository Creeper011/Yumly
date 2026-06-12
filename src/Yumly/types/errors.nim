##
# This module defines the Expected enum used for error reporting
##

type Expected* = enum
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
