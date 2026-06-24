##
# This module is responsible to maintain all error messages
##
import std/options
import types/[token, errors]
import utils/loc

when defined(yumlySuggestions):
  import utils/suggestions

func tokenError(message: string, token: Token, code: string): ref YumlyError =
  newYumlyError(message, token.line, token.col, token.endLine, token.endCol, code)

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
  of tkInterrogation: "?"
  of tkDeclaration: ";"

# Parser errors

func expectedMessage(expected: Expected, token: Token, previousToken: Option[
    Token]): string =
  result =
    "Heyy, I expected " & $expected & ", but found " & getTokenValue(token) &
    loc(token.line, token.col) & "."

  when defined(yumlySuggestions):
    let suggestion = suggestExpected(expected, token, previousToken)
    if suggestion.isSome:
      result.add("\n  hint: " & suggestion.get)

func expectedError*(expected: Expected, token: Token) =
  raise tokenError(
    expectedMessage(expected, token, none(Token)),
    token, "parser.expected")

func expectedError*(expected: Expected, token, previousToken: Token) =
  raise tokenError(
    expectedMessage(expected, token, some(previousToken)),
    token, "parser.expected")

func expectedBlockError*(expected: Expected, blkName: string, blkLine,
    blkCol: int, token: Token) =
  var message =
    "Heyy i expected " & $expected & " for block '(" & blkName &
    ")' opened at line " & $blkLine & ", column " & $blkCol &
    ", but found " & getTokenValue(token) & loc(token.line, token.col) & "."

  when defined(yumlySuggestions):
    let suggestion = suggestExpected(expected, token)
    if suggestion.isSome:
      message.add("\n  hint: " & suggestion.get)

  raise tokenError(
    message,
    token, "parser.expected")

func expectedTopTokenError*(expected: Expected, token: Token) =
  raise tokenError(
      "Ehhh.. found an unexpected token at root: '" & getTokenValue(token) &
      "'" & loc(token.line, token.col) & ".\n" &
      "Valid root tokens: include, block, ident.\n" &
      "Tip: make sure you're using commas correctly >,<",
      token, "parser.unexpected-root")

func includeOrderError*(token: Token) =
  raise tokenError(
      "Ehhh... include statements must stay at the very top of the file! >_<\n" &
      loc(token.line, token.col) & "\n" &
      "  hint: keep include { \"...\" } above all pairs and blocks",
      token, "parser.include-order")

func includeCommaError*(token: Token) =
  raise tokenError(
      "Ehhh... include statement should not be followed by a comma! >_<\n" &
      loc(token.line, token.col) & "\n" &
      "  hint: remove the comma after include { \"...\" }",
      token, "parser.include-comma")

# IO errors

func failedToLoadFile*(path: string, line: int, column: int, error: string) =
  raise newYumlyIOError(
      "Uhh... something went wrong while loading the " & path &
      " file! (>_<)\n" &
      "  file: '" & path & "'\n" &
      loc(line, column) & "\n" &
      "  detail: " & error,
      line, column, "include.load-failed", path
  )

func recursionLimitError*(limit: int, line: int, col: int) =
  raise newYumlyError(
      "Kyaa~! My head is spinning! The nesting is way too deep! (x_x)\n" &
      "  recursion limit: " & $limit & "\n" &
      loc(line, col) & "\n" &
      "  hint: try to flatten your configuration, it is way too deep for me to handle!",
      line, col, "parser.recursion-limit")

func unknownTypeHintError*(hint: string, line: int, column: int,
    sourceFile: string = "") =
  var message = "Ehhh... unknown type hint '" & hint & "'" & loc(line, column)

  when defined(yumlySuggestions):
    let suggestion = suggestTypeHint(hint)
    if suggestion.isSome:
      message.add("\n  hint: did you mean ';" & suggestion.get & "'?")

  raise newYumlyError(
      message,
      line, column, "resolver.unknown-type-hint", sourceFile)

func missingEnvError*(envName: string, line: int, column: int) =
  raise newYumlyError(
      "Kyaa~! the env variable '" & envName & "' does not exist! (；ω；)" &
      loc(line, column) & "\n" &
      "  hint: make sure '" & envName & "' is set in your terminal or loaded via include { \".env\" }",
      line, column, "validator.missing-env")

# Tokenizer errors

func commentNotClosedError*(line, col, endLine, endCol: int) =
  raise newYumlyError(
    "Heyy, the comment doesn't close! Expected '<;'" & loc(line, col),
    line, col, endLine, endCol, "tokenizer.unclosed-comment")

func invalidExponentError*(line, col, endLine, endCol: int) =
  raise newYumlyError(
    "Heyy, invalid exponent" & loc(line, col),
    line, col, endLine, endCol, "tokenizer.invalid-exponent")

func unclosedStringError*(line, col, endLine, endCol: int) =
  raise newYumlyError(
    "Heyy, the string doesn't close" & loc(line, col),
    line, col, endLine, endCol, "tokenizer.unclosed-string")

func unclosedStringAtEofError*(line, col, endLine, endCol: int) =
  raise newYumlyError(
    "Heyy the string doesn't close at the end of the file",
    line, col, endLine, endCol, "tokenizer.unclosed-string")

func unexpectedCharError*(char: string, line, col, endLine, endCol: int) =
  raise newYumlyError(
    "Wow, an unexpected character '" & char & "'" & loc(line, col),
    line, col, endLine, endCol, "tokenizer.unexpected-character")

# File errors

func invalidFileExtensionError*(path: string) =
  raise newYumlyIOError(
      "Mmm, that file isn't mine! :< You named it as: '" & path &
      "'. I can only read files with .yumly or .yuy extension",
      0, 0, "file.invalid-extension", path)

func fileNotFoundError*(filePath: string) =
  raise newYumlyIOError(
      "Heeeh?! I can't find the file anywhere... (T_T)\nI searched for: " &
      filePath &
      "\nHave you tried checking if the file path is correct?",
      0, 0, "file.not-found", filePath)

func fileTooLargeError*(path: string, fileSize: int64, limit: int) =
  raise newYumlyIOError(
      "Heeeh?! the file '" & path & "' is too large to parse! (" &
      $fileSize & " bytes, limit is " & $limit & " bytes) (>_<)",
      0, 0, "file.too-large", path)

func couldNotOpenFileError*(path: string) =
  raise newYumlyIOError("AHHH, Could not open file: " & path, 0, 0,
      "file.open-failed", path)

# Include loader errors

func circularIncludeError*(path: string, line: int, col: int) =
  raise newYumlyIOError(
      "Circular include detected! '" & path & "' is already being loaded\n" &
      loc(line, col),
      line, col, "include.circular")

func includeFileNotFoundError*(rawPath: string, absPath: string, line: int, col: int) =
  raise newYumlyIOError(
      "Heeeh?! i can't find '" & rawPath & "' anywhere... (T_T)\n" &
      "  searched at: " & absPath & "\n" &
      loc(line, col) & "\n" &
      "  hint: check if the path is correct and the file actually exists",
      line, col, "include.not-found")

func includeUnsupportedExtError*(filePath: string, ext: string, line: int, col: int) =
  raise newYumlyError(
      "Mmm, this file type isn't supported in include { \"\" } ;-; \n" &
      "  file: '" & filePath & "'\n" &
      "  got type: '" & ext & "'\n" &
      loc(line, col) & "\n" &
      "  hint: only .env, .yumly, .yuy files are supported for now",
      line, col, "include.unsupported-extension")

func sandboxDirViolationError*(path: string, sandboxDir: string, line: int, col: int) =
  raise newYumlyIOError(
      "Heeeh?! Security violation! Access to '" & path & "' is denied!\n" &
      "  sandbox dir: " & sandboxDir & "\n" &
      loc(line, col) & "\n" &
      "  hint: includes must be within the sandbox directory",
      line, col, "include.sandbox-violation")


# Values defs errors

func invalidEscapeError*(c: char, line: int, col: int) =
  raise newYumlyError(
    "Heyy, invalid escape: \\" & $c & " ;-;" & loc(line, col),
    line, col, "evaluator.invalid-escape")

func invalidBooleanError*(raw: string) =
  raise newException(ValueError, "Invalid boolean value: " & raw)

func couldNotDecodeLiteralError*(raw: string) =
  raise newException(Defect, "RAHHH >_<, could not decode the literal: '" &
      raw & "'")

# Evaluator errors

func invalidLiteralTokenError*(tokenKind: string) =
  raise newException(Defect, "RAHHH >_<, invalid literal token: " & tokenKind)

func invalidNodeKindInEvaluateError*(nodeKind: string) =
  raise newException(Defect, "RAHHH >_<, invalid YumNode kind in evaluateValue: " & nodeKind)

# Validate errors

func invalidTypeHintKindError*() =
  raise newException(ValueError, "RAHHH >_<, invalid, i can't convert TypeHintKind to ValueKind")

func configValidationFailedError*(errorCount: int, errors, code: string,
    line: int = 0, col: int = 0, sourceFile: string = "") =
  raise newYumlyError(
      "Yooo! config validation failed with " & $errorCount & " error(s):\n\n" &
      errors,
      line, col, code, sourceFile)

# Nim API/Value/Block/Conf errors

func iteratorNonListError*() =
  raise newException(ValueError, "Cannot iterate over non-list value")

func blockNotFoundError*(name: string) =
  raise newException(KeyError, "Block not found: " & name)

func subBlockNotFoundError*(name: string) =
  raise newException(KeyError, "Sub-block not found: " & name)

func cannotAddToNonListError*() =
  raise newException(IndexDefect, "Cannot add to a non-list value")

func expectedTypeError*(expected: string, got: string) =
  raise newException(ValueError, "I expected " & expected & ", got " & got)

func notListError*() =
  raise newException(IndexDefect, "This value isn't a list")

func keyNotFoundError*(key: string) =
  raise newException(KeyError, "I can't find '" & key & "' in the YumlyConf")

func keyNotFoundInBlockError*(key: string, blkName: string) =
  raise newException(KeyError, "I can't find '" & key & "' in the block '" &
      blkName & "'")
