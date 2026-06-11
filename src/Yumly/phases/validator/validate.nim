##
# This module defines validation logic for the Yumly configuration language.
# It checks values against their type hints and verifies environment variables.
##

import strutils
import ../../types/nodes
import ../../error_messages
import ../../utils/recursion
import checks

# ---------------------------------------------------------------------------
# Tree walk
# ---------------------------------------------------------------------------

proc validateNode(node: YumNode, currentPath: string, errors: var seq[string], depth: var int) =
  withRecursionGuard(depth, node.line, node.col):
    if node.kind notin {nkConfig, nkBlock}:
      return

    checkDuplicates(node.children, currentPath, errors)

    for child in node.children:
      case child.kind
      of nkBlock:
        let newPath =
          if currentPath.len == 0: child.name
          else: currentPath & "." & child.name
        validateNode(child, newPath, errors, depth)
      of nkPair:
        validatePair(child, currentPath, errors)
      else:
        discard

proc validateConfig*(rootNode: YumNode) =
  var errors: seq[string]
  var depth = 0
  validateNode(rootNode, currentPath = "", errors = errors, depth = depth)

  if errors.len > 0:
    configValidationFailedError(errors.len, errors.join("\n\n"))
