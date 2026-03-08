##
# This module is responsable to mainten all error messages
##
import types/token

type Expected* = enum
  expValue        = "a value"
  expIdentifier   = "an identifier"
  expString       = "a string"
  expInteger      = "an integer"
  expFloat        = "a float"
  expBoolean      = "a boolean"
  expEnvVar       = "an environment variable"
  expBlockName    = "a block name"
  expEquals       = "'='"
  expLBrace       = "'{'"
  expRBrace       = "'}'"
  expLBracket     = "'['"
  expRBracket     = "']'"
  expComma        = "','"
  expEOF          = "end of file"

proc getTokenValue(token: Token): string =
  case token.kind
  of tkString, tkIdent, tkLiteral: token.value
  of tkEOF: "EOF"
  of tkLParen: "("
  of tkRParen: ")"
  of tkLBrace: "{"
  of tkRBrace: "}"
  of tkLBracket: "["
  of tkRBracket: "]"
  of tkEquals: "="
  of tkComma: ","
  of tkDollar: "$"
  of tkInclude: "include"
  of tkDeclaration: ";"

# Parser errors

proc expectedEnvBracketError*(expected: Expected, token: Token) =
    raise newException(ValueError,
        "Heeeh... env variables must look like $[\"NAME\"], but I found " & getTokenValue(token) &
        " at line " & $token.line & ", column " & $token.col & ".\n" &
        "  hint: wrap the env name inside $[\"MY_ENV\"]")

proc expectedError*(expected: Expected, token: Token) =
    raise newException(ValueError,
      "Heyy i expected " & $expected & ", but found " & getTokenValue(token) &
      " at line " & $token.line & ", column " & $token.col & ".")

proc expectedBlockError*(expected: Expected, blkName: string, blkLine,
        blkCol: int, token: Token) =
    raise newException(ValueError,
      "Heyy i expected " & $expected & " for block '(" & blkName &
              ")' opened at line " &
      $blkLine & ", column " & $blkCol & ", but found " & getTokenValue(token) &
      " at line " & $token.line & ", column " & $token.col & ".")

proc expectedTopTokenError*(expected: Expected, token: Token) =
    raise newException(ValueError,
        "Ehhh.. found an unexpected token at root: '" & getTokenValue(token) &
        "' at line " & $token.line & ", column " & $token.col & ".\n" &
        "Valid root tokens: include, block, ident.\n" &
        "Tip: make sure you're using commas correctly >,<")

# IO errors

proc failedToLoadFile*(path: string, line: int, column: int, error: string) =
    raise newException(IOError,
        "Uhh... something went wrong while loading the " & path &
        "file! (>_<)\n" &
        "  file: '" & path & "'\n" &
        "  line: " & $line & ", column: " & $column & "\n" &
        "  detail: " & error
    )

proc unknownTypeHintError*(hint: string, line: int, column: int) =
    raise newException(ValueError,
        "Ehhh... unknown type hint '" & hint & "' (line " & $line &
        ", column " & $column & ")")

proc missingListTypeError*(line: int, column: int) =
    raise newException(ValueError,
        "Ehhh... the type hint 'list' must specify its element type, e.g. ';list[string]' (line " &
        $line & ", column " & $column & ")")


proc missingEnvError*(envName: string, line: int, column: int) =
    raise newException(ValueError,
        "Kyaa~! the env variable '" & envName & "' does not exist! (；ω；)" &
        "\n  line: " & $line & ", column: " & $column & "\n" &
        "  hint: make sure '" & envName & "' is set in your terminal or loaded via include { .env }")
