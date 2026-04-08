##
# This module is responsible to maintain all error messages
##
import types/token
import utils/loc

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
  expAt           = "an '@'"

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
  of tkBang: "!"
  of tkInclude: "include"
  of tkDeclaration: ";"
  of tkAt: "@"

# Parser errors

proc expectedEnvBracketError*(expected: Expected, token: Token) =
    raise newException(ValueError,
        "Heeeh... env variables must look like $[\"NAME\"], but I found " & getTokenValue(token) &
        loc(token.line, token.col) & ".\n" &
        "  hint: wrap the env name inside $[\"MY_ENV\"]")

proc expectedError*(expected: Expected, token: Token) =
    raise newException(ValueError,
      "Heyy, I expected " & $expected & ", but found " & getTokenValue(token) &
      loc(token.line, token.col) & ".")

proc expectedBlockError*(expected: Expected, blkName: string, blkLine,
        blkCol: int, token: Token) =
    raise newException(ValueError,
      "Heyy i expected " & $expected & " for block '(" & blkName &
              ")' opened at line " &
      $blkLine & ", column " & $blkCol & ", but found " & getTokenValue(token) &
      loc(token.line, token.col) & ".")

proc expectedTopTokenError*(expected: Expected, token: Token) =
    raise newException(ValueError,
        "Ehhh.. found an unexpected token at root: '" & getTokenValue(token) &
        "'" & loc(token.line, token.col) & ".\n" &
        "Valid root tokens: include, @global, block, ident.\n" &
        "Tip: make sure you're using commas correctly >,<")

proc includeOrderError*(token: Token) =
    raise newException(ValueError,
        "Ehhh... include statements must stay at the very top of the file! >_<\n" &
        loc(token.line, token.col) & "\n" &
        "  hint: keep include { \"...\" } above all global symbols, pairs, and blocks")

proc symbolRootOnlyError*(token: Token) =
    raise newException(ValueError,
        "Ehhh... global symbols are only allowed at the root level! >_<\n" &
        loc(token.line, token.col) & "\n" &
        "  hint: move '@name = ...' above the root pairs/blocks and outside of any block")

proc symbolOrderError*(token: Token) =
    raise newException(ValueError,
        "Ehhh... global symbols must stay in the root top section, right below includes! >_<\n" &
        loc(token.line, token.col) & "\n" &
        "  hint: place all '@name = ...' declarations after include { \"...\" } and before any root pair or block")

# IO errors

proc failedToLoadFile*(path: string, line: int, column: int, error: string) =
    raise newException(IOError,
        "Uhh... something went wrong while loading the " & path &
        "file! (>_<)\n" &
        "  file: '" & path & "'\n" &
        loc(line, column) & "\n" &
        "  detail: " & error
    )

proc unknownTypeHintError*(hint: string, line: int, column: int) =
    raise newException(ValueError,
        "Ehhh... unknown type hint '" & hint & "'" & loc(line, column))

proc missingListTypeError*(line: int, column: int) =
    raise newException(ValueError,
        "Ehhh... the type hint 'list' must specify its element type, e.g. ';list[string]'" & loc(line, column))


proc missingEnvError*(envName: string, line: int, column: int) =
    raise newException(ValueError,
        "Kyaa~! the env variable '" & envName & "' does not exist! (；ω；)" &
        loc(line, column) & "\n" &
        "  hint: make sure '" & envName & "' is set in your terminal or loaded via include { \".env\" }")

# Tokenizer errors

proc commentNotClosedError*(line, col: int) =
    raise newException(ValueError, "Heyy, the comment doesn't close! Expected '<;'" & loc(line, col))

proc invalidExponentError*(line, col: int) =
    raise newException(ValueError, "Heyy, invalid exponent" & loc(line, col))

proc unclosedStringError*(line, col: int) =
    raise newException(ValueError, "Heyy, the string doesn't close" & loc(line, col))

proc unclosedStringAtEofError*() =
    raise newException(ValueError, "Heyy the string doesn't close at the end of the file")

proc unexpectedCharError*(char: string, line, col: int) =
    raise newException(ValueError, "Wow, an unexpected character '" & char & "'" & loc(line, col))

# File errors

proc invalidFileExtensionError*(path: string) =
    raise newException(ValueError,
        "Mmm, that file isn't mine! :< You named it as: '" & path &
        "'. I can only read files with .yumly or .yuy extension")

proc fileNotFoundError*(filePath: string) =
    raise newException(ValueError,
        "Heeeh?! I can't find the file anywhere... (T_T)\nI searched for: " & filePath &
        "\nHave you tried checking if the file path is correct?")

# Include loader errors

proc circularIncludeError*(path: string, line: int, col: int) =
    raise newException(IOError,
        "Circular include detected! '" & path & "' is already being loaded\n" &
        loc(line, col))

proc includeFileNotFoundError*(rawPath: string, absPath: string, line: int, col: int) =
    raise newException(IOError,
        "Heeeh?! i can't find '" & rawPath & "' anywhere... (T_T)\n" &
        "  searched at: " & absPath & "\n" &
        loc(line, col) & "\n" &
        "  hint: check if the path is correct and the file actually exists")

proc includeUnsupportedExtError*(filePath: string, ext: string, line: int, col: int) =
    raise newException(ValueError,
        "Mmm, this file type isn't supported in include { \"\" } ;-; \n" &
        "  file: '" & filePath & "'\n" &
        "  got type: '" & ext & "'\n" &
        loc(line, col) & "\n" &
        "  hint: only .env, .yumly, .yuy files are supported for now")

# Values defs errors

proc invalidEscapeError*(c: char, line: int, col: int) =
    raise newException(ValueError, "Heyy, invalid escape: \\" & $c & " ;-;" & loc(line, col))

proc invalidBooleanError*(raw: string) =
    raise newException(ValueError, "Invalid boolean value: " & raw)

proc couldNotDecodeLiteralError*(raw: string) =
    raise newException(Defect, "RAHHH >_<, could not decode the literal: '" & raw & "'")

# Evaluator errors

proc invalidLiteralTokenError*(tokenKind: string) =
    raise newException(Defect, "RAHHH >_<, invalid literal token: " & tokenKind)

proc invalidNodeKindInEvaluateError*(nodeKind: string) =
    raise newException(Defect, "RAHHH >_<, invalid YumNode kind in evaluateValue: " & nodeKind)

# Symbol resolver errors

proc duplicateSymbolError*(key: string, line: int, col: int) =
    raise newException(ValueError,
        "Oh no! The symbol '@" & key & "' is duplicated at root! (°ロ°)" &
        loc(line, col) & "\n" &
        "  hint: keep only one symbol for each name.")

proc evaluateLiteralExpectedError*(nodeKind: string) =
    raise newException(Defect, "RAHHH >_<, evaluateLiteralNode expected nkLiteral, got " & nodeKind)

proc literalCannotInterpolateError*(symbolName: string, line: int, col: int) =
    raise newException(ValueError,
        "Ehhh... '@" & symbolName & "' can't be interpolated inside a string because it is not a literal value! >_<" &
        loc(line, col))

proc collectionCannotInterpolateError*(symbolName: string, line: int, col: int) =
    raise newException(ValueError,
        "Ehhh... '@" & symbolName & "' can't be interpolated inside a string because it resolves to a collection! >_<" &
        loc(line, col))

proc unknownSymbolError*(name: string, line: int, col: int) =
    raise newException(ValueError,
        "Ehhh... unknown symbol '@" & name & "'" &
        loc(line, col) & ".\n" &
        "  hint: declare it at the root after includes and before blocks.")

proc circularSymbolRefError*(cycle: string, line: int, col: int) =
    raise newException(ValueError,
        "Oh no! circular symbol reference detected: @" & cycle & " (°ロ°)" &
        loc(line, col))

# Validate errors

proc literalValueKindError*(nodeKind: string) =
    raise newException(Defect, "RAHHH >_<, literalValueKind expected nkLiteral, got " & nodeKind)

proc invalidTypeHintKindError*() =
    raise newException(ValueError, "RAHHH >_<, invalid, i can't convert TypeHintKind to ValueKind")

proc configValidationFailedError*(errorCount: int, errors: string) =
    raise newException(ValueError,
        "Yooo! config validation failed with " & $errorCount & " error(s):\n\n" & errors)
