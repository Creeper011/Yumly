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
    tkInt    # 123
    tkFloat  # 1.23 or 1e3
    tkBool   # true or false
    tkIdent # identifier
    tkEOF # end of file

  Token* = object
    line*: int
    col*:  int
    case kind*: TokenKind
    of tkString, tkIdent, tkInt, tkFloat, tkBool: value*: string
    else: discard
