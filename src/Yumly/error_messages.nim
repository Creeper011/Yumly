##
# This module is responsable to mainten all error messages
##
import types/token

proc toDisplay*(kind: TokenKind): string =
    case kind
    of tkLParen:      "'('"
    of tkRParen:      "')'"
    of tkLBrace:      "'{'"
    of tkRBrace:      "'}'"
    of tkLBracket:    "'['"
    of tkRBracket:    "']'"
    of tkEquals:      "'='"
    of tkDeclaration: "';'"
    of tkComma:       "','"
    of tkDollar:      "'$'"
    of tkInclude:     "'include'"
    of tkString:      "a string"
    of tkInt:         "an integer"
    of tkFloat:       "a float"
    of tkBool:        "a boolean"
    of tkIdent:       "an identifier"
    of tkEOF:         "end of file"

proc expectedValueError*(token: Token) =
    raise newException(ValueError,
      "Heyy i expected a value, but found " & $token.kind.toDisplay() &
      " at line " & $token.line & ", column " & $token.col & ".")

proc expectedEnvBracketError*(token: Token) =
    raise newException(ValueError,
        "Heeeh... env variables must look like $[\"NAME\"], but I found a lonely '$'" &
        " at line " & $token.line & ", column " & $token.col & ".\n" &
        "  hint: wrap the env name inside $[\"MY_ENV\"]")

proc expectedError*(expected_tkind: TokenKind, token: Token) =
    raise newException(ValueError,
      "Heyy i expected " & $expected_tkind.toDisplay() & ", but found " & $token.kind.toDisplay() &
      " at line " & $token.line & ", column " & $token.col & ".")

proc expectedBlockError*(expected: TokenKind, blkName: string, blkLine, blkCol: int, token: Token) =
    raise newException(ValueError,
      "Heyy i expected " & expected.toDisplay() & " for block '(" & blkName & ")' opened at line " &
      $blkLine & ", column " & $blkCol & ", but found " & token.kind.toDisplay() &
      " at line " & $token.line & ", column " & $token.col & ".")

proc expectedTopTokenError*(token: Token) =
    raise newException(ValueError,
        "Ehhh.. found an unexpected token at root: '" & $token.kind.toDisplay() &
        "' at line " & $token.line & ", column " & $token.col & ".\n" &
        "Valid root tokens: include, block, ident.\n" &
        "Tip: make sure you're using commas correctly >,<")

proc failedToLoadFile*(path: string, line: int, column: int, error: string) =
    raise newException(IOError,
        "Uhh... something went wrong while loading the " & path & "file! (>_<)\n" &
        "  file: '" & path & "'\n" &
        "  line: " & $line & ", column: " & $column & "\n" &
        "  detail: " & error
    )

proc unknownTypeHintError*(hint: string, line: int, column: int) =
    raise newException(ValueError,
        "Ehhh... unknown type hint '" & hint & "' (line " & $line & ", column " & $column & ")")

proc missingEnvError*(envName: string, line: int, column: int) =
    raise newException(ValueError,
        "Kyaa~! the env variable '" & envName & "' does not exist! (；ω；)" &
        "\n  line: " & $line & ", column: " & $column & "\n" &
        "  hint: make sure '" & envName & "' is set in your terminal or loaded via include { .env }")
