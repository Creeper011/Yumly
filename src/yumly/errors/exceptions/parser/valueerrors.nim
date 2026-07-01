## Value decoding diagnostic raises.

import ../../../types/[errors, source]
import ../../common

func invalidEscapeError*(c: char, line, col: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecEvaluatorInvalidEscape, "Heyy, invalid escape: \\" & $c &
      " ;-;", line, col),
    ecEvaluatorInvalidEscape, @[sourceSpan(nil, line, col)])

func invalidIntegerError*(raw: string, line, col: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecValueInvalidInteger,
      "Ehhh... '" & raw & "' is not a valid integer! >_<", line, col),
    ecValueInvalidInteger, @[sourceSpan(nil, line, col)])

func invalidFloatError*(raw: string, line, col: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecValueInvalidFloat,
      "Ehhh... '" & raw & "' is not a valid float! >_<", line, col),
    ecValueInvalidFloat, @[sourceSpan(nil, line, col)])

func invalidBooleanError*(raw: string, line, col: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecValueInvalidBoolean,
      "Ehhh... '" & raw & "' is not a valid boolean! >_<", line, col),
    ecValueInvalidBoolean, @[sourceSpan(nil, line, col)])
