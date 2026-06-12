##
# Resolver: construct values and prepares the AST for validation/evaluation.
##

import strutils, options
import ../../types/nodes, ../../types/type_hints
import ../../error_messages

proc resolveTypeHint(hint: var TypeHint) =
  var resolvedKind = hint.kind
  var resolvedElemKind = thUnknown
  var resolvedElemRaw = ""
  let name = hint.raw.toLowerAscii()

  if resolvedKind == thUnknown:
    case name
    of "string": resolvedKind = thString
    of "int": resolvedKind = thInt
    of "float": resolvedKind = thFloat
    of "bool": resolvedKind = thBool
    of "env": resolvedKind = thEnv
    of "list":
      resolvedKind = thList
      resolvedElemKind = thUnknown
    else: unknownTypeHintError(hint.raw, hint.line, hint.col)

  if resolvedKind == thList:
    if hint.kind == thList:
      resolvedElemKind = hint.elementKind
      resolvedElemRaw = hint.elementRaw

    if resolvedElemRaw.len > 0:
      let elemName = resolvedElemRaw.toLowerAscii()
      case elemName
      of "string": resolvedElemKind = thString
      of "int": resolvedElemKind = thInt
      of "float": resolvedElemKind = thFloat
      of "bool": resolvedElemKind = thBool
      of "env": resolvedElemKind = thEnv
      else: unknownTypeHintError(resolvedElemRaw, hint.line, hint.col)

    # Note: if it's a bare list (name == "list"), we keep resolvedElemKind as thUnknown.
    # Otherwise, we default to thString for backward compatibility or explicit list[...] cases.
    if resolvedElemKind == thUnknown and name != "list":
      resolvedElemKind = thString
      resolvedElemRaw = "string"

  case resolvedKind
  of thList:
    hint = TypeHint(
      raw: hint.raw,
      kind: thList,
      elementKind: resolvedElemKind,
      elementRaw: resolvedElemRaw,
      line: hint.line,
      col: hint.col
    )
  else:
    hint = TypeHint(
      raw: hint.raw,
      kind: resolvedKind,
      line: hint.line,
      col: hint.col
    )

import ../../utils/recursion

proc resolveAstInternal(node: YumNode, depth: var int) =
  withRecursionGuard(depth, node.line, node.col):
    case node.kind
    of nkPair:
      if node.typeHint.isSome:
        var hint = node.typeHint.get
        resolveTypeHint(hint)
        node.typeHint = some(hint)
      resolveAstInternal(node.valNode, depth)

    of nkArray, nkBlock, nkConfig:
      for child in node.children:
        resolveAstInternal(child, depth)
    else:
      discard

proc resolveAst*(node: YumNode) =
  var depth = 0
  resolveAstInternal(node, depth)
