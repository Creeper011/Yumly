##
# This module defines validation logic for the Yumly configuration language.
# This checks the types of values against their type hints
# and also checks for the presence of included files and environment variables.
##

import os, options, strutils, sets
import dotenv
import ../types/ast

const AllowedIncludeExts = [".env"]

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
  of thEnv:    kind == vkEnv or kind == vkString
  of thList:   kind == vkList
  of thTuple:  kind == vkTuple

proc validateBlock(blk: var Block, path: string, errors: var seq[string]) =
  checkDuplicateBlocks(blk.subBlocks, path, errors)

  for i in 0..<blk.pairs.len:
    let pair     = blk.pairs[i]
    let position = loc(pair.line, pair.col)

    # check env var presence when value is an env reference
    if pair.value.kind == vkEnv:
      if not existsEnv(pair.value.env):
        errors.add(
          "Kyaa~! the env variable '" & pair.value.env & "' does not exist! (；ω；)" &
          "\n  key: '" & pair.key & "' in block '" & path & "'" & position &
          "\n  hint: make sure '" & pair.value.env & "' is set in your terminal or in your .env file"
        )
      blk.pairs[i].value.envVal = os.getEnv(pair.value.env, "")

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

proc validateConfig*(config: var Config) =
  var errors: seq[string]

  for incl in config.includes:
    if not os.fileExists(incl.includePath):
      errors.add(
        "Heeeh?! i can't find '" & incl.includePath & "' anywhere... (T_T)" &
        "\n  searched at: " & os.absolutePath(incl.includePath) &
        "\n  hint: check if the path is correct and the file actually exists"
      )
      continue

    # checks the file extension of env
    let sf = os.splitFile(incl.includePath)
    var ext = sf.ext.toLowerAscii()
    if ext.len == 0 and sf.name.toLowerAscii() == ".env":
      ext = ".env"
    if ext notin AllowedIncludeExts:
      errors.add(
        "Mmm, this file type isn't supported in include { } ;-;" &
        "\n  file: '" & incl.includePath & "'" &
        "\n  got type: '" & ext & "'" &
        "\n  hint: only " & AllowedIncludeExts.join(", ") & " files are supported for now"
      )
      continue

    if ext == ".env":
      try:
        let sfEnv   = os.splitFile(incl.includePath)
        let envDir  = if sfEnv.dir.len == 0: "." else: sfEnv.dir
        let envFile = sfEnv.name & sfEnv.ext
        load(envDir, envFile)
      except CatchableError as e:
        errors.add(
          "Ih... something went wrong while loading the .env file! (>_<)" &
          "\n  file: '" & incl.includePath & "'" &
          "\n  detail: " & e.msg
        )

  checkDuplicateBlocks(config.blocks, "", errors)

  for i in 0..<config.blocks.len:
    validateBlock(config.blocks[i], config.blocks[i].name, errors)

  if errors.len > 0:
    raise newException(ValueError,
      "Yooo! config validation failed with " & $errors.len & " error(s):\n\n" &
      errors.join("\n\n"))