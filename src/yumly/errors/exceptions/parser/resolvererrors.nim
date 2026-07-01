## Resolver diagnostic raises.

import ../../../types/[errors, source]
import ../../common

when defined(yumlySuggestions):
  import std/options
  import ../../../utils/suggestions

func unknownTypeHintError*(hint: string, line, column: SourcePos,
    sourceFile: SourceFile = nil) =
  var message = yumlyMessage(ecResolverUnknownTypeHint,
      "Ehhh... unknown type hint '" & hint & "'", line, column)

  when defined(yumlySuggestions):
    let suggestion = suggestTypeHint(hint)
    if suggestion.isSome:
      message.add("\n  hint: did you mean ';" & suggestion.get & "'?")

  raise newYumlyError(
      message,
      ecResolverUnknownTypeHint, @[sourceSpan(sourceFile, line, column)])

func envTypeHintDisabledError*(line, column: SourcePos,
    sourceFile: SourceFile = nil) =
  raise newYumlyError(
      yumlyDetailedMessage(ecResolverEnvDisabled,
      "Ehhh... ;env is disabled in this Yumly build! >_<\n" &
      "  hint: compile with -d:yumlyEnv to enable environment values.",
      line, column),
      ecResolverEnvDisabled, @[sourceSpan(sourceFile, line, column)])
