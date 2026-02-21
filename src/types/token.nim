##
# This module defines the Token and TokenKind types, as well as the tokenize
##

type
  TokenKind* = enum
    tkLParen # (
    tkRParen # )
    tkLBrace # {
    tkRBrace # }
    tkLBracket # [
    tkRBracket # ]
    tkEquals # =
    tkDeclaration  # ;
    tkComma # ,
    tkDollar # $
    tkInclude # include
    tkString # "string"
    tkNumber # 123 or 1.23
    tkIdent # identifier
    tkEOF # end of file

  Token* = object
    line*: int
    col*:  int
    case kind*: TokenKind
    of tkString, tkIdent, tkNumber: value*: string
    else: discard
