## Parser diagnostic raises.

import std/options

import ../../../types/[errors, source, token]
import ../../../utils/loc
import ../../common

when defined(yumlySuggestions):
  import ../../../utils/suggestions

func expectedMessage(expected: Expected, token: Token, previousToken: Option[
    Token]): string =
  var cuteMessage =
    "Heyy, I expected " & $expected & ", but found " & getTokenValue(token)
  if previousToken.isSome:
    cuteMessage.add(" after " & getTokenValue(previousToken.get))

  result = yumlyMessage(ecParserExpected, cuteMessage, token.source.line,
      token.source.col)

  when defined(yumlySuggestions):
    let suggestion = suggestExpected(expected, token, previousToken)
    if suggestion.isSome:
      result.add("\n  hint: " & suggestion.get)

func expectedError*(expected: Expected, token: Token) =
  raise tokenError(
    expectedMessage(expected, token, none(Token)),
    token, ecParserExpected)

func expectedError*(expected: Expected, token, previousToken: Token) =
  raise tokenError(
    expectedMessage(expected, token, some(previousToken)),
    token, ecParserExpected)

func expectedBlockError*(expected: Expected, blkName: string, blkLine,
    blkCol: SourcePos, token: Token) =
  var message = yumlyMessage(ecParserExpected,
    "Heyy i expected " & $expected & " for block '(" & blkName &
    ")' opened at line " & $blkLine & ", column " & $blkCol &
    ", but found " & getTokenValue(token),
    token.source.line, token.source.col)

  when defined(yumlySuggestions):
    let suggestion = suggestExpected(expected, token)
    if suggestion.isSome:
      message.add("\n  hint: " & suggestion.get)

  raise tokenError(
    message,
    token, ecParserExpected)

func expectedTopTokenError*(expected: Expected, token: Token) =
  var message = yumlyDetailedMessage(ecParserUnexpectedRoot,
      "Ehhh.. found an unexpected token at root: '" & getTokenValue(token) &
      "'. Expected " & $expected & loc(token.source.line, token.source.col) &
          ".\n" &
      "Valid root tokens: include, block, ident.\n" &
      "Tip: make sure you're using commas correctly >,<",
      token.source.line, token.source.col)

  when defined(yumlySuggestions):
    let suggestion = suggestExpected(expected, token)
    if suggestion.isSome:
      message.add("\n  hint: " & suggestion.get)

  raise tokenError(message, token, ecParserUnexpectedRoot)

func includeOrderError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserIncludeOrder,
      "Ehhh... include statements must stay at the very top of the file! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: place includes before schemas, pairs and blocks",
      token.source.line, token.source.col),
      token, ecParserIncludeOrder)

func schemaOrderError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserSchemaOrder,
      "Ehhh... schema declarations must stay after includes and before pairs or blocks in a normal yumly file! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: place schemas after includes and before pairs and blocks; use a .yu file for schema-only content",
      token.source.line, token.source.col),
      token, ecParserSchemaOrder)

func schemaFileIncludeError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserSchemaFile,
      "Ehhh... .yu schema files cannot include other files! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: remove the include; .yu files contain schemas only",
      token.source.line, token.source.col),
      token, ecParserSchemaFile)

func schemaFileRootError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserSchemaFile,
      "Ehhh... .yu files can only contain [schema] declarations at the root! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: keep only schema declarations in .yu files; move pairs and blocks to a .yumly or .yuy file",
      token.source.line, token.source.col),
      token, ecParserSchemaFile)

func schemaFieldTypeHintError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserSchemaFieldType,
      "Ehhh... schema field '" & token.value & "' needs a type hint! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: declare its type, e.g. " & token.value & " ;string",
      token.source.line, token.source.col),
      token, ecParserSchemaFieldType)

func objectOutsideListError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserObjectContext,
      "Ehhh... objects can only be used as list items! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: objects are exclusive to lists; use a named block outside a list",
      token.source.line, token.source.col),
      token, ecParserObjectContext)

func includeCommaError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserIncludeComma,
      "Ehhh... includes statements should not be followed by a comma! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: remove the comma after the closing }; include statements are not comma-separated",
      token.source.line, token.source.col),
      token, ecParserIncludeComma)

func envSupportDisabledError*(token: Token) =
  raise tokenError(
      yumlyDetailedMessage(ecParserEnvDisabled,
      "Ehhh... environment references are disabled in this Yumly build! >_<\n" &
      loc(token.source.line, token.source.col) & "\n" &
      "  hint: compile with -d:yumlyEnv to enable $[\"NAME\"] expressions.",
      token.source.line, token.source.col),
      token, ecParserEnvDisabled)

func recursionLimitError*(limit: int, span: SourceSpan) =
  raise newYumlyError(
      yumlyDetailedMessage(ecParserRecursionLimit,
      "Kyaa~! My head is spinning! The nesting is way too deep! (x_x)\n" &
      "  recursion limit: " & $limit & "\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: try to flatten your configuration, it is way too deep for me to handle!",
      span.line, span.col),
      ecParserRecursionLimit, @[span])

func recursionLimitError*(limit: int, line, col: SourcePos) =
  recursionLimitError(limit, sourceSpan(nil, line, col))
