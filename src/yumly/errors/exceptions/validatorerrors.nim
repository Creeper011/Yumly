## Validator diagnostic raises.

import ../../types/[errors, source]
import ../../utils/loc
import ../common

func validatorRecursionLimitError*(limit: int, span: SourceSpan) =
  raise newYumlyError(
      yumlyDetailedMessage(ecValidatorRecursionLimit,
      "Kyaa~! My head is spinning! The nesting is way too deep! (x_x)\n" &
      "  recursion limit: " & $limit & "\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: try to flatten your configuration, it is way too deep for me to handle!",
      span.line, span.col),
      ecValidatorRecursionLimit, @[span])
