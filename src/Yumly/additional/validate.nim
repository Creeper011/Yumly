##
# This module defines validation logic for the Yumly configuration language.
# This checks the types of values against their type hints
# and also checks for the presence of included files and environment variables.
##

import os, options, strutils, sets
import ../types/ast
import validate_includes

template loc(line, col: int): string =
  " (line " & $line & ", column " & $col & ")"

# --- Helpers para Mensagens de Erro ---

proc kindName(k: NodeKind): string =
  case k
  of nkString: "string"
  of nkInt:    "int"
  of nkFloat:  "float"
  of nkBool:   "bool"
  of nkEnv:    "env"
  of nkList:   "list"
  of nkTuple:  "tuple"
  of nkInclude: "include"
  else: "block/config"

proc hintKindName(k: TypeHintKind): string =
  case k
  of thString: "string"
  of thInt:    "int"
  of thFloat:  "float"
  of thBool:   "bool"
  of thEnv:    "env"
  of thList:   "list"
  of thTuple:  "tuple"

proc hintName(h: TypeHint): string =
  case h.kind
  of thList: "list[" & hintKindName(h.elementKind) & "]"
  else: hintKindName(h.kind)

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
          "\n  hint: merge them into one block or rename one of them"
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

proc checkEnvVars(node: YumNode, path: string, errors: var seq[string]) =
  case node.kind:
    of nkEnv:
      if not existsEnv(node.rawValue):
        errors.add(
          "Kyaa~! the env variable '" & node.rawValue & "' does not exist! (；ω；)" &
          "\n  path: '" & path & "'" & loc(node.line, node.col) &
          "\n  hint: make sure '" & node.rawValue & "' is set in your terminal or in your .env file"
        )
    of nkList, nkTuple:
      for child in node.children:
        checkEnvVars(child, path, errors)
    else: discard

proc validatePair(pairNode: YumNode, path: string, errors: var seq[string]) =
  let position = loc(pairNode.line, pairNode.col)
  let valNode = pairNode.valNode
  let got = valNode.kind

  if pairNode.typeHint.isSome:
    let hint = pairNode.typeHint.get

    if got == nkEnv and hint.kind != thEnv and hint.kind != thList:
      errors.add(
        "Ehhh... '" & pairNode.key & "' in '" & path & "' (block) is an env reference but is annotated as ;" & hintName(hint) & "! >_<" &
        position &
        "\n  env values must be annotated with ;env (use ;env or remove the type hint)"
      )
    
    elif hint.kind == thList:
      if got != nkList:
        errors.add(
          "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
          position &
          "\n  value is " & kindName(got) & ", but the type hint is ;" & hintName(hint)
        )

    elif hint.kind == thTuple:
      if got != nkList and got != nkTuple:
        errors.add(
          "Ehhh... '" & pairNode.key & "' in '" & path & "' has the wrong type! >_<" &
          position &
          "\n  value is " & kindName(got) & ", but the type hint is ;tuple"
        )

proc validateASTNode(node: YumNode, currentPath: string, errors: var seq[string], skipEnv: bool) =
  if node.kind in {nkConfig, nkBlock}:
    checkDuplicates(node.children, currentPath, errors)

  for child in node.children:
    case child.kind:
      of nkBlock:
        let newPath = if currentPath.len == 0: child.name else: currentPath & "." & child.name
        validateASTNode(child, newPath, errors, skipEnv)
      of nkPair:
        validatePair(child, currentPath, errors)
        if not skipEnv:
          checkEnvVars(child.valNode, currentPath & "." & child.key, errors)
      else:
        discard

proc validateConfig*(rootNode: YumNode, skipInclude: bool = false, skipEnv: bool = false) =
  var errors: seq[string]

  if not skipInclude:
     validateIncludes(rootNode, errors)

  validateASTNode(rootNode, currentPath = "", errors = errors, skipEnv = skipEnv)

  if errors.len > 0:
    raise newException(ValueError,
      "Yooo! config validation failed with " & $errors.len & " error(s):\n\n" &
      errors.join("\n\n"))