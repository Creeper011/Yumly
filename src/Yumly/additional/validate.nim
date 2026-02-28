##
# This module defines validation logic for the Yumly configuration language.
# This checks the types of values against their type hints
# and also checks for the presence of included files and environment variables.
##

import os, options, strutils, sets
import ../types/ast

template loc(line, col: int): string =
  " (line " & $line & ", column " & $col & ")"

proc kindName(nodeKind: NodeKind): string =
  case nodeKind
  of nkString: "string"
  of nkInt:    "int"
  of nkFloat:  "float"
  of nkBool:   "bool"
  of nkEnv:    "env"
  of nkArray:  "array"
  of nkInclude: "include"
  else: "block/config"

proc hintKindName(hintKind: TypeHintKind): string =
  case hintKind
  of thUnknown: "unknown"
  of thString: "string"
  of thInt:    "int"
  of thFloat:  "float"
  of thBool:   "bool"
  of thEnv:    "env"
  of thList:   "list"
  of thTuple:  "tuple"

proc hintName(hint: TypeHint): string =
  case hint.kind
  of thList: "list[" & hintKindName(hint.elementKind) & "]"
  of thUnknown: "unknown"
  else: hintKindName(hint.kind)

proc checkDuplicates(nodes: seq[YumNode], path: string, errors: var seq[string]) =
  var seenBlocks = initHashSet[string]()
  var seenPairs = initHashSet[string]()
  
  let where = if path.len == 0: "root" else: "'" & path & "'"

  for child in nodes:
    if child.kind == nkBlock:
      if child.name in seenBlocks:
        errors.add(
          "Oh no! the block '(" & child.name & ")' is duplicated in " & where & "! (°ロ°)" &
          loc(child.line, child.col) &
          "\n  hint: merge them into one block or rename one of them, or check if this duplication comes from an include."
        )
      else:
        seenBlocks.incl(child.name)
        
    elif child.kind == nkPair:
      if child.key in seenPairs:
        errors.add(
          "Oh no! the key pair '(" & child.key & ")' is duplicated in " & where & "! (°ロ°)" &
          loc(child.line, child.col) &
          "\n  hint: choose one to prevail or rename the duplicated key."
        )
      else:
        seenPairs.incl(child.key)

proc matchNodeToHint(node: YumNode, hintKind: TypeHintKind): bool =
  case hintKind
  of thUnknown: result = true
  of thString: result = node.kind == nkString
  of thInt:    result = node.kind == nkInt
  of thFloat:  result = node.kind == nkFloat
  of thBool:   result = node.kind == nkBool
  of thEnv:    result = node.kind == nkEnv
  of thList, thTuple: result = node.kind == nkArray

proc validateArrayElements(node: YumNode, hint: TypeHint, path: string, errors: var seq[string]) =
  if hint.kind == thList and hint.elementKind != thUnknown:
    for i, child in node.children:
      if not matchNodeToHint(child, hint.elementKind) and child.kind != nkEnv:
        errors.add(
          "Mmm, element " & $i & " in list '" & path & "' has the wrong type! >_<" &
          loc(child.line, child.col) &
          "\n  got " & kindName(child.kind) & ", but expected " & hintKindName(hint.elementKind)
        )

proc validatePair(pairNode: YumNode, path: string, errors: var seq[string]) =
  let position = loc(pairNode.line, pairNode.col)
  let valNode = pairNode.valNode
  let got = valNode.kind
  # ensure env existence (IO allowed per requirements)
  case valNode.kind
  of nkEnv:
    if not os.existsEnv(valNode.rawValue):
      errors.add(
        "Kyaa~! the env variable '" & valNode.rawValue & "' does not exist! (；ω；)" &
        position &
        "\n  hint: make sure it's set in your terminal or loaded via include { .env }"
      )
  of nkArray:
    for child in valNode.children:
      if child.kind == nkEnv and not os.existsEnv(child.rawValue):
        errors.add(
          "Kyaa~! the env variable '" & child.rawValue & "' does not exist! (；ω；)" &
          loc(child.line, child.col) &
          "\n  hint: make sure it's set in your terminal or loaded via include { .env }"
        )
  else:
    discard

  if pairNode.typeHint.isSome:
    let hint = pairNode.typeHint.get
    if hint.kind == thUnknown:
      return

    if got == nkEnv and hint.kind != thEnv and hint.kind != thList:
      errors.add(
        "Ehhh... '" & pairNode.key & "' in '" & path & "' (block) is an env reference but is annotated as ;" & hintName(hint) & "! >_<" &
        position &
        "\n  env values must be annotated with ;env (use ;env or remove the type hint)"
      )
    
    elif hint.kind == thList:
      if got != nkArray:
        errors.add(
          "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
          position &
          "\n  value is " & kindName(got) & ", but the type hint is ;" & hintName(hint)
        )
      else:
        validateArrayElements(valNode, hint, pairNode.key, errors)
    elif hint.kind == thTuple:
      if got != nkArray:
        errors.add(
          "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
          position &
          "\n  value is " & kindName(got) & ", but the type hint is ;tuple"
        )
    
    else:
      # Simple type validation for primitives
      if not matchNodeToHint(valNode, hint.kind) and got != nkEnv:
        errors.add(
          "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
          position &
          "\n  value is " & kindName(got) & ", but the type hint is ;" & hintName(hint)
        )
  else:
    discard

proc validateASTNode(node: YumNode, currentPath: string, errors: var seq[string]) =
  if node.kind in {nkConfig, nkBlock}:
    checkDuplicates(node.children, currentPath, errors)

  for child in node.children:
    case child.kind:
      of nkBlock:
        let newPath = if currentPath.len == 0: child.name else: currentPath & "." & child.name
        validateASTNode(child, newPath, errors)
      of nkPair:
        validatePair(child, currentPath, errors)
      else:
        discard

proc validateConfig*(rootNode: YumNode) =
  var errors: seq[string]

  validateASTNode(rootNode, currentPath = "", errors = errors)

  if errors.len > 0:
    raise newException(ValueError,
      "Yooo! config validation failed with " & $errors.len & " error(s):\n\n" &
      errors.join("\n\n"))
