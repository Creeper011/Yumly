##
# This module defines validation logic for the Yumly configuration language.
# This checks the types of values against their type hints
# and also checks for the presence of included files and environment variables.
##

import os, options, strutils, sets
import dotenv
import ../types/ast

const AllowedIncludeExts = [".env"]

proc checkDuplicateBlocks(blocks: seq[Block], path: string, errors: var seq[string]) =
  var seen = initHashSet[string]()
  for blk in blocks:
    if blk.name in seen:
      if path.len == 0:
        errors.add "Oh no.. duplicated group '" & blk.name & "' at root"
      else:
        errors.add "Oh no.. duplicated group '" & blk.name & "' in '" & path & "'"
    else:
      seen.incl blk.name

proc validateBlock(blk: var Block, path: string, errors: var seq[string]) =
  checkDuplicateBlocks(blk.subBlocks, path, errors)
  for i in 0..<blk.pairs.len:
    # check env var presence when value is an env reference
    if blk.pairs[i].value.kind == vkEnv:
      if not existsEnv(blk.pairs[i].value.env):
        errors.add "Env '" & blk.pairs[i].value.env & "' not found for '" & blk.pairs[i].key &
                   "' at '" & path & "'"
      blk.pairs[i].value.envVal = os.getEnv(blk.pairs[i].value.env, "")

    # check type hints
    if blk.pairs[i].typeHint.isSome and blk.pairs[i].value.kind != vkEnv:
      case blk.pairs[i].typeHint.get
      of vkString:
        if blk.pairs[i].value.kind != vkString:
          errors.add "Heyy, the key '" & blk.pairs[i].key & "' at '" & path &
                     "' should be a string, but i found: " & $blk.pairs[i].value.kind
      of vkInt:
        if blk.pairs[i].value.kind != vkInt:
          errors.add "Heyy, the key '" & blk.pairs[i].key & "' at '" & path &
                     "' should be an int, but i found: " & $blk.pairs[i].value.kind
      of vkFloat:
        if blk.pairs[i].value.kind != vkFloat:
          errors.add "Heyy, the key '" & blk.pairs[i].key & "' at '" & path &
                     "' should be a float, but i found: " & $blk.pairs[i].value.kind
      of vkBool:
        if blk.pairs[i].value.kind != vkBool:
          errors.add "Heyy, the key '" & blk.pairs[i].key & "' at '" & path &
                     "' should be a bool, but i found: " & $blk.pairs[i].value.kind
      of vkEnv:
        if blk.pairs[i].value.kind != vkEnv:
          errors.add "Heyy, the key '" & blk.pairs[i].key & "' at '" & path &
                     "' should be an env var, but i found: " & $blk.pairs[i].value.kind

  for i in 0..<blk.subBlocks.len:
    validateBlock(blk.subBlocks[i], path & "." & blk.subBlocks[i].name, errors)

proc validateConfig*(config: var Config) =
  var errors: seq[string]

  for incl in config.includes:
    if not os.fileExists(incl.includePath):
      errors.add "Oh no.. i cannot found '" & incl.includePath & "'"
      continue
    
    # checks the file extension of env
    let sf = os.splitFile(incl.includePath)
    var ext = sf.ext.toLowerAscii()
    if ext.len == 0 and sf.name.toLowerAscii() == ".env":
      ext = ".env"
    if ext notin AllowedIncludeExts:
      errors.add "Oh no.. '" & incl.includePath & "' has unsupported include type: '" & ext & "'"
      continue
    
    if ext == ".env":
      try:
        let sfEnv = os.splitFile(incl.includePath)
        let envDir = if sfEnv.dir.len == 0: "." else: sfEnv.dir
        let envFile = sfEnv.name & sfEnv.ext
        load(envDir, envFile)
      except CatchableError as e:
        errors.add e.msg

  checkDuplicateBlocks(config.blocks, "", errors)

  for i in 0..<config.blocks.len:
    validateBlock(config.blocks[i], config.blocks[i].name, errors)

  if errors.len > 0:
    raise newException(ValueError,
        "Config validation failed with the following errors:\n" & errors.join("\n"))
