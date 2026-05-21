##
# This module is responsible to maintain all error messages
##
import types/token
import utils/loc

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

func getTokenValue(token: Token): string =
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
  of tkDeclaration: ";"

# Parser errors

func expectedError*(expected: Expected, token: Token) =
  raise newException(ValueError,
    "Heyy, I expected " & $expected & ", but found " & getTokenValue(token) &
    loc(token.line, token.col) & ".")

func expectedBlockError*(expected: Expected, blkName: string, blkLine,
        blkCol: int, token: Token) =
  raise newException(ValueError,
    "Heyy i expected " & $expected & " for block '(" & blkName &
            ")' opened at line " &
    $blkLine & ", column " & $blkCol & ", but found " & getTokenValue(token) &
    loc(token.line, token.col) & ".")

func expectedTopTokenError*(expected: Expected, token: Token) =
  raise newException(ValueError,
      "Ehhh.. found an unexpected token at root: '" & getTokenValue(token) &
      "'" & loc(token.line, token.col) & ".\n" &
      "Valid root tokens: include, block, ident.\n" &
      "Tip: make sure you're using commas correctly >,<")

func includeOrderError*(token: Token) =
  raise newException(ValueError,
      "Ehhh... include statements must stay at the very top of the file! >_<\n" &
      loc(token.line, token.col) & "\n" &
      "  hint: keep include { \"...\" } above all global symbols, pairs, and blocks")

# IO errors

func failedToLoadFile*(path: string, line: int, column: int, error: string) =
  raise newException(IOError,
      "Uhh... something went wrong while loading the " & path &
      " file! (>_<)\n" &
      "  file: '" & path & "'\n" &
      loc(line, column) & "\n" &
      "  detail: " & error
  )

func recursionLimitError*(limit: int, line: int, col: int) =
  raise newException(ValueError,
      "Kyaa~! My head is spinning! The nesting is way too deep! (x_x)\n" &
      "  recursion limit: " & $limit & "\n" &
      loc(line, col) & "\n" &
      "  hint: try to flatten your configuration, it is way too deep for me to handle!")

func unknownTypeHintError*(hint: string, line: int, column: int) =
  raise newException(ValueError,
      "Ehhh... unknown type hint '" & hint & "'" & loc(line, column))

func missingListTypeError*(line: int, column: int) =
  raise newException(ValueError,
      "Ehhh... the type hint 'list' must specify its element type, e.g. ';list[string]'" & loc(line, column))


func missingEnvError*(envName: string, line: int, column: int) =
  raise newException(ValueError,
      "Kyaa~! the env variable '" & envName & "' does not exist! (；ω；)" &
      loc(line, column) & "\n" &
      "  hint: make sure '" & envName & "' is set in your terminal or loaded via include { \".env\" }")

# Tokenizer errors

func commentNotClosedError*(line, col: int) =
  raise newException(ValueError, "Heyy, the comment doesn't close! Expected '<;'" & loc(line, col))

func invalidExponentError*(line, col: int) =
  raise newException(ValueError, "Heyy, invalid exponent" & loc(line, col))

func unclosedStringError*(line, col: int) =
  raise newException(ValueError, "Heyy, the string doesn't close" & loc(line, col))

func unclosedStringAtEofError*() =
  raise newException(ValueError, "Heyy the string doesn't close at the end of the file")

func unexpectedCharError*(char: string, line, col: int) =
  raise newException(ValueError, "Wow, an unexpected character '" & char & "'" & loc(line, col))

# File errors

func invalidFileExtensionError*(path: string) =
  raise newException(ValueError,
      "Mmm, that file isn't mine! :< You named it as: '" & path &
      "'. I can only read files with .yumly or .yuy extension")

func fileNotFoundError*(filePath: string) =
  raise newException(ValueError,
      "Heeeh?! I can't find the file anywhere... (T_T)\nI searched for: " & filePath &
      "\nHave you tried checking if the file path is correct?")

func fileTooLargeError*(path: string, fileSize: int64, limit: int) =
  raise newException(ValueError,
      "Heeeh?! the file '" & path & "' is too large to parse! (" &
      $fileSize & " bytes, limit is " & $limit & " bytes) (>_<)")

func couldNotOpenFileError*(path: string) =
  raise newException(IOError, "AHHH, Could not open file: " & path)

# Include loader errors

func circularIncludeError*(path: string, line: int, col: int) =
  raise newException(IOError,
      "Circular include detected! '" & path & "' is already being loaded\n" &
      loc(line, col))

func includeFileNotFoundError*(rawPath: string, absPath: string, line: int, col: int) =
  raise newException(IOError,
      "Heeeh?! i can't find '" & rawPath & "' anywhere... (T_T)\n" &
      "  searched at: " & absPath & "\n" &
      loc(line, col) & "\n" &
      "  hint: check if the path is correct and the file actually exists")

func includeUnsupportedExtError*(filePath: string, ext: string, line: int, col: int) =
  raise newException(ValueError,
      "Mmm, this file type isn't supported in include { \"\" } ;-; \n" &
      "  file: '" & filePath & "'\n" &
      "  got type: '" & ext & "'\n" &
      loc(line, col) & "\n" &
      "  hint: only .env, .yumly, .yuy files are supported for now")

func sandboxDirViolationError*(path: string, sandboxDir: string, line: int, col: int) =
  raise newException(IOError,
      "Heeeh?! Security violation! Access to '" & path & "' is denied!\n" &
      "  sandbox dir: " & sandboxDir & "\n" &
      loc(line, col) & "\n" &
      "  hint: includes must be within the sandbox directory")


# Values defs errors

func invalidEscapeError*(c: char, line: int, col: int) =
  raise newException(ValueError, "Heyy, invalid escape: \\" & $c & " ;-;" & loc(line, col))

func invalidBooleanError*(raw: string) =
  raise newException(ValueError, "Invalid boolean value: " & raw)

func couldNotDecodeLiteralError*(raw: string) =
  raise newException(Defect, "RAHHH >_<, could not decode the literal: '" & raw & "'")

# Evaluator errors

func invalidLiteralTokenError*(tokenKind: string) =
  raise newException(Defect, "RAHHH >_<, invalid literal token: " & tokenKind)

func invalidNodeKindInEvaluateError*(nodeKind: string) =
  raise newException(Defect, "RAHHH >_<, invalid YumNode kind in evaluateValue: " & nodeKind)

# Validate errors

func literalValueKindError*(nodeKind: string) =
  raise newException(Defect, "RAHHH >_<, literalValueKind expected nkLiteral, got " & nodeKind)

func invalidTypeHintKindError*() =
  raise newException(ValueError, "RAHHH >_<, invalid, i can't convert TypeHintKind to ValueKind")

func configValidationFailedError*(errorCount: int, errors: string) =
  raise newException(ValueError,
      "Yooo! config validation failed with " & $errorCount & " error(s):\n\n" & errors)

# Nim API/Value/Block/Conf errors

func iteratorNonListTupleError*() =
  raise newException(ValueError, "Cannot iterate over non-list/tuple value")

func blockNotFoundError*(name: string) =
  raise newException(KeyError, "Block not found: " & name)

func subBlockNotFoundError*(name: string) =
  raise newException(KeyError, "Sub-block not found: " & name)

func cannotAddToNonListTupleError*() =
  raise newException(IndexDefect, "Cannot add to a non-list/tuple value")

func expectedTypeError*(expected: string, got: string) =
  raise newException(ValueError, "I expected " & expected & ", got " & got)

func notListTupleError*() =
  raise newException(IndexDefect, "This value isn't a list or tuple")

func keyNotFoundError*(key: string) =
  raise newException(KeyError, "I can't find '" & key & "' in the YumlyConf")

func keyNotFoundInBlockError*(key: string, blkName: string) =
  raise newException(KeyError, "I can't find '" & key & "' in the block '" & blkName & "'")
