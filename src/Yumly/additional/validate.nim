##
# This module defines validation logic for the Yumly configuration language.
# It checks values against their type hints and verifies environment variables.
##

import os, options, sets, strutils
import ../types/nodes, ../types/token, ../types/type_hints, ../types/ast
import ../types/values_defs

# Helpers

template loc(line, col: int): string =
  " (line " & $line & ", column " & $col & ")"

proc isEnvNode(node: YumNode): bool =
  node.kind == nkLiteral and node.token.kind == tkDollar

# Tries each ValueDef decoder to infer which ValueKind a raw literal is.
# skips env/list/tuple since those are structural, not raw-string-decodable.
proc inferValueKind(raw: string): ValueKind =
  for vk in [vkBool, vkInt, vkFloat, vkString]:
    try:
      discard VALUES_DEF[vk].decode(raw)
      return vk
    except:
      discard
  vkString

proc nodeTypeName(node: YumNode): string =
  if isEnvNode(node):
    return VALUES_DEF[vkEnv].typeHint
  case node.kind
  of nkLiteral: VALUES_DEF[inferValueKind(node.rawValue)].typeHint
  of nkArray:   VALUES_DEF[vkList].typeHint
  of nkBlock:   "block"
  of nkPair:    "pair"
  of nkConfig:  "config"
  of nkInclude: "include"

# maps a TypeHintKind to its corresponding ValueKind so we can look up VALUES_DEF.
proc toValueKind(hk: TypeHintKind): ValueKind =
  case hk
  of thString: vkString
  of thInt:    vkInt
  of thFloat:  vkFloat
  of thBool:   vkBool
  of thEnv:    vkEnv
  of thList:   vkList
  of thTuple:  vkTuple
  of thUnknown: vkString  # won't be reached in practice

proc matchNodeToHint(node: YumNode, hintKind: TypeHintKind): bool =
  case hintKind
  of thUnknown:       true
  of thEnv:           isEnvNode(node)
  of thList, thTuple: node.kind == nkArray
  else:
    if node.kind != nkLiteral or isEnvNode(node):
      return false
    VALUES_DEF[inferValueKind(node.rawValue)].typeHint ==
      VALUES_DEF[toValueKind(hintKind)].typeHint

proc checkDuplicates(nodes: seq[YumNode], path: string, errors: var seq[string]) =
  var seenBlocks = initHashSet[string]()
  var seenPairs  = initHashSet[string]()
  let where = if path.len == 0: "root" else: "'" & path & "'"

  for child in nodes:
    case child.kind
    of nkBlock:
      if child.name in seenBlocks:
        errors.add(
          "Oh no! the block '(" & child.name & ")' is duplicated in " & where & "! (°ロ°)" &
          loc(child.line, child.col) &
          "\n  hint: merge them into one block or rename one, or check if this duplication comes from an include."
        )
      else:
        seenBlocks.incl(child.name)
    of nkPair:
      if child.key in seenPairs:
        errors.add(
          "Oh no! the key pair '(" & child.key & ")' is duplicated in " & where & "! (°ロ°)" &
          loc(child.line, child.col) &
          "\n  hint: choose one to prevail or rename the duplicated key."
        )
      else:
        seenPairs.incl(child.key)
    else:
      discard

proc validateArrayElements(node: YumNode, hint: TypeHint,
                           pairKey: string, errors: var seq[string]) =
  if hint.kind != thList or hint.elementKind == thUnknown:
    return
  for i, child in node.children:
    if isEnvNode(child):
      continue  # env references are resolved at runtime
    if not matchNodeToHint(child, hint.elementKind):
      errors.add(
        "Mmm, element " & $i & " in list '" & pairKey & "' has the wrong type! >_<" &
        loc(child.line, child.col) &
        "\n  got " & nodeTypeName(child) & ", but expected " &
        VALUES_DEF[toValueKind(hint.elementKind)].typeHint
      )

proc validateEnvExistence(node: YumNode, errors: var seq[string]) =
  if not os.existsEnv(node.rawValue):
    errors.add(
      "Kyaa~! the env variable '" & node.rawValue & "' does not exist! (；ω；)" &
      loc(node.line, node.col) &
      "\n  hint: make sure it's set in your terminal or loaded via include { .env }"
    )

proc validatePair(pairNode: YumNode, path: string, errors: var seq[string]) =
  let position = loc(pairNode.line, pairNode.col)
  let valNode  = pairNode.valNode

  # --- env existence (IO) ---
  if isEnvNode(valNode):
    validateEnvExistence(valNode, errors)
  elif valNode.kind == nkArray:
    for child in valNode.children:
      if isEnvNode(child):
        validateEnvExistence(child, errors)

  # --- type-hint checks ---
  if pairNode.typeHint.isNone:
    return
  let hint = pairNode.typeHint.get
  if hint.kind == thUnknown:
    return

  # Env reference annotated with a non-env/non-list hint
  if isEnvNode(valNode) and hint.kind notin {thEnv, thList}:
    errors.add(
      "Ehhh... '" & pairNode.key & "' in '" & path &
      "' is an env reference but is annotated as ;" & hint.raw & "! >_<" &
      position &
      "\n  env values must be annotated with ;env (or remove the type hint)"
    )
    return

  case hint.kind
  of thList:
    if valNode.kind != nkArray:
      errors.add(
        "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
        position &
        "\n  value is " & nodeTypeName(valNode) & ", but the type hint is ;" &
        VALUES_DEF[vkList].typeHint
      )
    else:
      validateArrayElements(valNode, hint, pairNode.key, errors)

  of thTuple:
    if valNode.kind != nkArray:
      errors.add(
        "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
        position &
        "\n  value is " & nodeTypeName(valNode) & ", but the type hint is ;" &
        VALUES_DEF[vkTuple].typeHint
      )

  else:
    if not matchNodeToHint(valNode, hint.kind) and not isEnvNode(valNode):
      errors.add(
        "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
        position &
        "\n  value is " & nodeTypeName(valNode) & ", but the type hint is ;" &
        VALUES_DEF[toValueKind(hint.kind)].typeHint
      )

# ---------------------------------------------------------------------------
# Tree walk
# ---------------------------------------------------------------------------

proc validateNode(node: YumNode, currentPath: string, errors: var seq[string]) =
  if node.kind notin {nkConfig, nkBlock}:
    return

  checkDuplicates(node.children, currentPath, errors)

  for child in node.children:
    case child.kind
    of nkBlock:
      let newPath =
        if currentPath.len == 0: child.name
        else: currentPath & "." & child.name
      validateNode(child, newPath, errors)
    of nkPair:
      validatePair(child, currentPath, errors)
    else:
      discard

proc validateConfig*(rootNode: YumNode) =
  var errors: seq[string]
  validateNode(rootNode, currentPath = "", errors = errors)

  if errors.len > 0:
    raise newException(ValueError,
      "Yooo! config validation failed with " & $errors.len & " error(s):\n\n" &
      errors.join("\n\n"))