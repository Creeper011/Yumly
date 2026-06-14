##
# This module defines the Token and TokenKind types, as well as the tokenize
##

type
  TokenKind* = enum
    tkLParen      # (
    tkRParen      # )
    tkLBrace      # {
    tkRBrace      # }
    tkLBracket    # [
    tkRBracket    # ]
    tkEquals      # =
    tkDeclaration # ;
    tkComma       # ,
    tkDollar      # $
    tkString      # "string"
    tkLiteral     # values like: int, float, bool etc
    tkIdent       # identifier
    tkEOF         # end of file

  Token* = object
    line*: int
    col*: int
    endLine*: int
    endCol*: int
    case kind*: TokenKind
    of tkString, tkIdent, tkLiteral: value*: string
    else: discard

func `$`*(t: Token): string =
  result = $t.kind
  if t.kind in {tkString, tkIdent, tkLiteral}:
    result.add("(\"" & t.value & "\")")
  result.add(" @ " & $t.line & ":" & $t.col)
