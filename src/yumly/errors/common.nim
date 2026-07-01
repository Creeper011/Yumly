## Shared helpers for Yumly diagnostic message modules.

import ../types/[errors, source, token]
import ../utils/loc
import ./codes

func fixedMessage(code: ErrorCode, line, col: SourcePos): string =
  result = $code
  if line > 0 or col > 0:
    result.add(loc(line, col))

func yumlyMessage*(code: ErrorCode, cuteMessage: string, line, col: SourcePos): string =
  when defined(yumlyCuteErrors):
    result = cuteMessage
    if line > 0 or col > 0:
      result.add(loc(line, col))
  else:
    fixedMessage(code, line, col)

func yumlyDetailedMessage*(code: ErrorCode, cuteMessage: string, line, col: SourcePos): string =
  when defined(yumlyCuteErrors):
    cuteMessage
  else:
    fixedMessage(code, line, col)

func tokenError*(message: string, token: Token, code: ErrorCode): ref YumlyError =
  newYumlyError(message, code, @[token.source])

func getTokenValue*(token: Token): string =
  case token.kind
  of tkString, tkIdent, tkLiteral: token.value
  of tkEOF: "EOF"
  of tkLParen: "("
  of tkRParen: ")"
  of tkLBrace: "{"
  of tkRBrace: "}"
  of tkLBracket: "["
  of tkRBracket: "]"
  of tkLess: "<"
  of tkGreater: ">"
  of tkEquals: "="
  of tkComma: ","
  of tkAt: "@"
  of tkStar: "*"
  of tkBang: "!"
  of tkDollar: "$"
  of tkDoubleInterrogation: "??"
  of tkSemiColon: ";"
