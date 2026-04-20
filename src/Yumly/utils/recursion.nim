import ../constants
import ../error_messages
import ../types/token

template withRecursionGuard*(depth: var int, line, col: int, body: untyped) =
  if depth >= MaxRecursionDepth:
    recursionLimitError(MaxRecursionDepth, line, col)
  
  depth += 1
  try:
    body
  finally:
    depth -= 1

template withRecursionGuard*(depth: var int, token: Token, body: untyped) =
  withRecursionGuard(depth, token.line, token.col, body)
