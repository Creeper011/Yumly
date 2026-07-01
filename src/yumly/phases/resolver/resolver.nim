##
# Resolver do resolver
##

import strutils, options, sets
import ../../types/[nodes, typehints, source]
import ../../errors/exceptions/parser/resolvererrors

func isBuiltinType(raw: string): bool =
  case raw.toLowerAscii()
  of "string", "int", "float", "bool", "list": true
  of "env":
    when defined(yumlyEnv):
      true
    else:
      false
  else: false

func resolveTypeKind(raw: string, line, col: SourcePos,
    sourceFile: SourceFile = nil): TypeHintKind =
  case raw.toLowerAscii()
  of "string": result = thString
  of "int": result = thInt
  of "float": result = thFloat
  of "bool": result = thBool
  of "list": result = thList
  of "env":
    when defined(yumlyEnv):
      result = thEnv
    else:
      envTypeHintDisabledError(line, col, sourceFile)
  else: unknownTypeHintError(raw, line, col, sourceFile)

func parameterRaw(hint: TypeHint): string =
  case hint.kind
  of thList:
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

proc resolveTypeHint(hint: var TypeHint, schemas: HashSet[string],
    sourceFile: SourceFile = nil) =
  var resolvedKind = hint.kind
  var resolvedElemKind = thUnknown
  var resolvedElemRaw = ""
  let name = hint.baseTypeName()
  let hasParameter = name != hint.raw

  if hasParameter and name.toLowerAscii() != "list":
    unknownTypeHintError(hint.raw, hint.line, hint.col, sourceFile)

  if resolvedKind == thUnknown:
    if name in schemas:
      hint = TypeHint(raw: hint.raw, kind: thUnknown, line: hint.line,
          col: hint.col)
      return
    resolvedKind = resolveTypeKind(name, hint.line, hint.col, sourceFile)

  if resolvedKind == thList:
    resolvedElemRaw = hint.parameterRaw()
    if hint.kind == thList:
      resolvedElemKind = hint.elementKind

    if resolvedElemRaw.len > 0 and resolvedElemRaw notin schemas:
      resolvedElemKind = resolveTypeKind(resolvedElemRaw, hint.line, hint.col, sourceFile)

    # Note: if it's a bare list/env, we keep resolvedElemKind as thUnknown.
    # Otherwise, we default to thString for backward compatibility or explicit parameterized cases.
    if resolvedElemKind == thUnknown and name != hint.raw and resolvedElemRaw.isBuiltinType():
      resolvedElemKind = thString
      resolvedElemRaw = "string"

  case resolvedKind
  of thList:
    hint = TypeHint(raw: hint.raw, kind: thList, elementKind: resolvedElemKind,
        elementRaw: resolvedElemRaw, line: hint.line, col: hint.col)
  else:
    hint = TypeHint(raw: hint.raw, kind: resolvedKind, line: hint.line, col: hint.col)

proc resolveNode*(node: YumNode, schemas: HashSet[string]) =
  if node.kind == nkPairStart and node.typeHint.isSome:
    var hint = node.typeHint.get
    resolveTypeHint(hint, schemas, node.sourceFile)
    node.typeHint = some(hint)
  elif node.kind == nkSchemaTypedBlock:
    var hint = node.blockType
    resolveTypeHint(hint, schemas, node.sourceFile)
    node.blockType = hint

proc resolveNodes*(upstream: NodePuller): NodePuller =
  var schemas = initHashSet[string]()

  return proc(): YumNode {.closure.} =
    let node = upstream()

    case node.kind
    of nkSchemaStart:
      schemas.incl(node.name)
    of nkPairStart, nkSchemaTypedBlock:
      resolveNode(node, schemas)
    else:
      discard

    node
