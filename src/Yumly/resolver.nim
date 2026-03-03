##
# Resolver: construct values and prepares the AST for validation/evaluation.
##

import strutils, options
import types/ast
import error_messages

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
      missingListTypeError(hint.line, hint.col)
    of "tuple": resolvedKind = thTuple
    else: unknownTypeHintError(hint.raw, hint.line, hint.col)

  if resolvedKind == thList:
    # Only touch list-specific fields when the original hint actually had them
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

    if resolvedElemKind == thUnknown:
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

proc resolveAst*(node: YumNode) =
  case node.kind
  of nkPair:
    if node.typeHint.isSome:
      var hint = node.typeHint.get
      resolveTypeHint(hint)
      node.typeHint = some(hint)
    resolveAst(node.valNode)

  of nkArray, nkBlock, nkConfig:
    for child in node.children:
      resolveAst(child)

  else:
    discard
