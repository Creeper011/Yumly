## Evaluator diagnostic raises.

import ../../../types/[errors, source]
import ../../common

func envCoerceFailedError*(envName, coerceType: string, fromDefault: bool,
    line, col: SourcePos) =
  let valueSource =
    if fromDefault: "its fallback value"
    else: "the value stored in the environment variable"
  raise newYumlyError(
    yumlyMessage(ecEvaluatorEnvCoerceFailed,
      "Ehhh... $" & "[\"" & envName & "\"; " & coerceType &
      "] asks to me decode " & valueSource & " as " & coerceType &
      ", but that value cannot be decoded as " & coerceType &
      "(>_<). Check " & (if fromDefault: "the fallback" else: "the env var '" &
      envName & "'") & " or change the coerceType.",
      line, col),
    ecEvaluatorEnvCoerceFailed, @[sourceSpan(nil, line, col)])

func invalidLiteralTokenError*(tokenKind: string) =
  raise newYumlyDefect("RAHHH >_<, invalid literal token: " & tokenKind,
    ecEvaluatorInvalidLiteralToken)

func invalidNodeKindInEvaluateError*(nodeKind: string) =
  raise newYumlyDefect(
    "RAHHH >_<, invalid YumNode kind in evaluateValue: " & nodeKind,
    ecEvaluatorInvalidNodeKind)
