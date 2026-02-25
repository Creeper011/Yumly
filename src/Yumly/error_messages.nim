##
# This module is responsable to mainten all error messages
##
import types/token

proc toDisplay(kind: TokenKind): string =
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
    of tkNumber:      "a number"
    of tkIdent:       "an identifier"
    of tkEOF:         "end of file"

proc expectedValueError*(token: Token) =
    raise newException(ValueError,
      "Heyy i expected a value, but found " & $token.kind.toDisplay() &
      " at line " & $token.line & ", column " & $token.col & ".")

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
        "Ehhh.. i found an unexpected token at root level: " & $token.kind.toDisplay() &
        " at line " & $token.line & ", column " & $token.col & ". Available root tokens: 'include', 'block', 'ident'.")