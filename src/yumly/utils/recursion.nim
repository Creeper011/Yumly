import ../constants
import ../errors/exceptions/parser/parsererrors
import ../types/source
import ../types/token

template withRecursionGuard*(depth: var int, line, col: SourcePos, body: untyped) =
  if depth >= MaxRecursionDepth:
    recursionLimitError(MaxRecursionDepth, line, col)

  depth += 1
  try:
    body
  finally:
    depth -= 1

template withRecursionGuard*(depth: var int, token: Token, body: untyped) =
  withRecursionGuard(depth, token.source.line, token.source.col, body)
