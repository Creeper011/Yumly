## This module defines the Token and TokenKind types for the Yumly configuration language :3

import source # TODO/NOTE: talvez mudar isso para yumly/types/source com building apontando para src

type
  TokenKind* = enum
    tkLParen              # (                                   | Used in blocks. e.g: (application) {}
    tkRParen              # )                                   | Used in blocks. e.g: (services) {}
    tkLBrace              # {                                   | Used for opening blocks. e.g: (application) {
    tkRBrace              # }                                   | Used for closing blocks. e.g: }
    tkLBracket            # [                                   | Used for env vars, lists, and schema declarations. e.g: $["MAIN_TOKEN"; int ?? 0], [dependency] {}
    tkRBracket            # ]                                   | Used for env vars, lists, and schema declarations. e.g: $["MAIN_TOKEN"; int ?? 0], [dependency] {}
    tkLess                # <                                   | Used for object-local schema tags. e.g: <dependency> { name = "Yumene" }
    tkGreater             # >                                   | Used for object-local schema tags. e.g: <dependency> { name = "Yumene" }
    tkEquals              # =                                   | Used in pairs. e.g: name = "Big Cid"
    tkSemiColon           # ;                                   | Used for constraints/coercions. e.g: dependencies ;list[dependency] = [<dependency> { name = "Yume" }]
    tkComma               # ,                                   | Used as separator in lists. e.g: names = ["yume", "yumene"]
    tkAt                  # @                                   | Used for const declarations. e.g: @PROJECT_NAME = "Big Cid"
    tkStar                # *                                   | Used for const references. e.g: name = *PROJECT_NAME
    tkBang                # !                                   | Used for explicit interpolation a const. e.g: @NAME = "yume", description = !"""hi #{NAME}"""
    tkDollar              # $                                   | Used for env vars. e.g: $["MAIN_TOKEN"; int ?? 0]
    tkDoubleInterrogation # ??                                  | Used for fallback values. e.g: $["MAIN_TOKEN"; int ?? 0]
    tkString              # "string"                            | String value. e.g: "Big Cid"
    tkLiteral             # values like: int, float, bool etc   | Literal value. e.g: true, 0, 1.5
    tkIdent               # identifier                          | Identifier. e.g: include, name, main-token
    tkEOF                 # end of file                         | End of file

  # TODO/(ficar): For composite tokens, when the tokenizer throws an "unexpected char" exception,
  # it must be followed by suggestions if enabled via -d:yumlySuggestions

  # Trivia is used to store syntactic details of the files for potential linting;
  # this can be enabled with -d:yumlyTrivia
  TriviaKind* = enum
    tvComment
    tvWhitespace
    tvNewline

  Trivia* = object
    case kind*: TriviaKind
    of tvComment: text*: string
    of tvWhitespace: len*: SourcePos
    of tvNewline: discard

  Token* = object
    source*: SourceSpan
    when defined(yumlyTrivia):
      leading*, trailing*: seq[Trivia]
    case kind*: TokenKind
    of tkString, tkIdent, tkLiteral: value*: string
    else: discard
  
  # Closure aliases
  TokenPuller* = proc(): Token {.closure.}

func `$`*(tk: Token): string =
  result = $tk.kind
  if tk.kind in {tkString, tkIdent, tkLiteral}:
    result.add("(\"" & tk.value & "\")")
  result.add(" @ " & $tk.source.line & ":" & $tk.source.col)
  when defined(yumlyTrivia):
    if tk.leading.len > 0:
      result.add("\n  leading:  " & $tk.leading)
    if tk.trailing.len > 0:
      result.add("\n  trailing: " & $tk.trailing)
