##
# Resolver: construct values and prepares the AST for validation/evaluation.
##

import strutils, options
import ../../types/nodes, ../../types/type_hints
import ../../error_messages

func resolveTypeKind(raw: string, line, col: int,
    sourceFile: string = ""): TypeHintKind =
  case raw.toLowerAscii()
  of "string": result = thString
  of "int": result = thInt
  of "float": result = thFloat
  of "bool": result = thBool
  of "env": result = thEnv
  of "list": result = thList
  else: unknownTypeHintError(raw, line, col, sourceFile)

func parameterRaw(hint: TypeHint): string =
  case hint.kind
  of thList, thEnv:
    hint.elementRaw
  else:
    let openBracket = hint.raw.find('[')
    let closeBracket = hint.raw.rfind(']')
    if openBracket >= 0 and closeBracket > openBracket:
      hint.raw[openBracket + 1 ..< closeBracket]
    else:
      ""

func baseTypeName(hint: TypeHint): string =
  let bracket = hint.raw.find('[')
  if bracket >= 0:
    return hint.raw[0 ..< bracket]
  hint.raw

proc resolveTypeHint(hint: var TypeHint, sourceFile: string = "") =
  var resolvedKind = hint.kind
  var resolvedElemKind = thUnknown
  var resolvedElemRaw = ""
  let name = hint.baseTypeName()

  if resolvedKind == thUnknown:
    resolvedKind = resolveTypeKind(name, hint.line, hint.col, sourceFile)

  if resolvedKind in {thList, thEnv}:
    resolvedElemRaw = hint.parameterRaw()
    if hint.kind in {thList, thEnv}:
      resolvedElemKind = hint.elementKind

    if resolvedElemRaw.len > 0:
      resolvedElemKind = resolveTypeKind(resolvedElemRaw, hint.line, hint.col, sourceFile)

    if resolvedKind == thEnv and resolvedElemKind in {thEnv, thList}:
      unknownTypeHintError(resolvedElemRaw, hint.line, hint.col, sourceFile)

    # Note: if it's a bare list/env, we keep resolvedElemKind as thUnknown.
    # Otherwise, we default to thString for backward compatibility or explicit parameterized cases.
    if resolvedElemKind == thUnknown and name != hint.raw:
      resolvedElemKind = thString
      resolvedElemRaw = "string"

  case resolvedKind
  of thList:
    hint = TypeHint(raw: hint.raw, kind: thList, elementKind: resolvedElemKind,
        elementRaw: resolvedElemRaw, line: hint.line, col: hint.col)
  of thEnv:
    hint = TypeHint(raw: hint.raw, kind: thEnv, elementKind: resolvedElemKind,
        elementRaw: resolvedElemRaw, line: hint.line, col: hint.col)
  else:
    hint = TypeHint(raw: hint.raw, kind: resolvedKind, line: hint.line, col: hint.col)

proc resolveNode*(node: YumNode) =
  if node.kind == nkPairStart and node.typeHint.isSome:
    var hint = node.typeHint.get
    resolveTypeHint(hint, node.sourceFile)
    node.typeHint = some(hint)

proc resolveNodes*(upstream: NodePuller): NodePuller =
  return proc(): YumNode {.closure.} =
    let node = upstream()
    if node.kind != nkEOF:
      resolveNode(node)
    node
