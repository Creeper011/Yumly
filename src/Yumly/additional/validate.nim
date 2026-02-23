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

proc checkDuplicateBlocks(blocks: seq[Block], path: string, errors: var seq[string]) =
  var seen = initHashSet[string]()
  for blk in blocks:
    if blk.name in seen:
      let where = if path.len == 0: "root" else: "'" & path & "'"
      errors.add(
        "Oh no! the block '(" & blk.name & ")' is duplicated in " & where & "! (°ロ°)" &
        loc(blk.line, blk.col) &
        "\n  hint: merge them into one block or rename one of them"
      )
    else:
      seen.incl blk.name

proc checkDuplicatePairs(pairs: seq[Pair], blkPath: string, errors: var seq[string]) =
  var seen = initHashSet[string]()
  for pair in pairs:
    if pair.key in seen:
      let where = if blkPath.len == 0: "root" else: "'" & blkPath & "'"
      errors.add(
        "Oh no! the key pair '(" & pair.key & ")' is duplicated in " & where & "! (°ロ°)" &
        loc(pair.line, pair.col) &
        "\n  hint: choose one to prevail or rename the duplicated key."
      )
    else:
      seen.incl pair.key

proc kindName(k: ValueKind): string =
  case k
  of vkString: "string"
  of vkInt:    "int"
  of vkFloat:  "float"
  of vkBool:   "bool"
  of vkEnv:    "env"
  of vkList:   "list"
  of vkTuple:  "tuple"

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

proc matches(hint: TypeHintKind, kind: ValueKind): bool =
  case hint
  of thString: kind == vkString
  of thInt:    kind == vkInt
  of thFloat:  kind == vkFloat
  of thBool:   kind == vkBool
  of thEnv:    kind == vkEnv
  of thList:   kind == vkList
  of thTuple:  kind == vkTuple

proc resolveEnvVars(blk: var Block, path: string, errors: var seq[string]) =
  for i in 0..<blk.pairs.len:
    template pair: untyped = blk.pairs[i]
    if pair.value.kind == vkEnv:
      if not existsEnv(pair.value.env):
        errors.add(
          "Kyaa~! the env variable '" & pair.value.env & "' does not exist! (；ω；)" &
          "\n  key: '" & pair.key & "' in block '" & path & "'" & loc(pair.line, pair.col) &
          "\n  hint: make sure '" & pair.value.env & "' is set in your terminal or in your .env file"
        )
      blk.pairs[i].value.envVal = os.getEnv(pair.value.env)

  for i in 0..<blk.subBlocks.len:
    resolveEnvVars(blk.subBlocks[i], path & "." & blk.subBlocks[i].name, errors)

proc validateBlock(blk: var Block, path: string, errors: var seq[string]) =
  checkDuplicateBlocks(blk.subBlocks, path, errors)
  checkDuplicatePairs(blk.pairs, path, errors)

  for i in 0..<blk.pairs.len:
    template pair: untyped = blk.pairs[i]
    let position = loc(pair.line, pair.col)

    # transform an list with heterogenius value to a tuple
    if pair.typeHint.isSome and pair.typeHint.get().kind == thTuple and pair.value.kind == vkList:
      pair.value = Value(kind: vkTuple, elements: pair.value.items)

    # check type hints
    if pair.typeHint.isSome:
      let hint = pair.typeHint.get
      let got = pair.value.kind

      # env values must use the ;env hint (or be part of a list[env])
      if got == vkEnv and hint.kind != thEnv and hint.kind != thList:
        errors.add(
          "Ehhh... '" & pair.key & "' in '" & path & "' (group) is an env reference but is annotated as ;" & hintName(hint) & "! >_<" &
          position &
          "\n  env values must be annotated with ;env (use ;env or remove the type hint)"
        )
      
      if hint.kind == thList:
        if got != vkList:
          errors.add(
            "Ehhh... '" & pair.key & "' in '" & path & "' has the wrong type! >_<" &
            position &
            "\n  value is " & kindName(got) & ", but the type hint is ;" & hintName(hint)
          )
        else:
          for item in pair.value.items:
            if not matches(hint.elementKind, item.kind):
              errors.add(
                "Ehhh... an item in list '" & pair.key & "' in '" & path & "' has the wrong type! >_<" &
                position &
                "\n  expected item type: " & hintKindName(hint.elementKind) & ", but got " & kindName(item.kind)
              )
      elif hint.kind == thTuple:
        if got != vkTuple:
          errors.add(
            "Ehhh... '" & pair.key & "' in '" & path & "' has the wrong type! >_<" &
            position &
            "\n  value is " & kindName(got) & ", but the type hint is ;tuple"
          )
      else:
        if not matches(hint.kind, got):
          errors.add(
            "Ehhh... '" & pair.key & "' in '" & path & "' has the wrong type! >_<" &
            position &
            "\n  value has type: " & kindName(got) & ", but the type hint is ;" & hintName(hint)
          )

  for i in 0..<blk.subBlocks.len:
    validateBlock(blk.subBlocks[i], path & "." & blk.subBlocks[i].name, errors)

proc validateConfig*(config: var Config, skipInclude: bool = false, skipEnv: bool = false) =
  var errors: seq[string]

  if not skipInclude:
    validateIncludes(config, errors)

  if not skipEnv:
    for i in 0..<config.blocks.len:
      resolveEnvVars(config.blocks[i], config.blocks[i].name, errors)

  checkDuplicateBlocks(config.blocks, "", errors)
  for i in 0..<config.blocks.len:
    validateBlock(config.blocks[i], config.blocks[i].name, errors)

  if errors.len > 0:
    raise newException(ValueError,
      "Yooo! config validation failed with " & $errors.len & " error(s):\n\n" &
      errors.join("\n\n"))