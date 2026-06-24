##
# This module defines validation logic for evaluated Yumly configs.
##

import strutils
import ../../constants
import ../../types/ast
import ../../error_messages
import checks

type
  BlockFrame = object
    blk: Block
    exiting: bool

proc validateBlock(blk: Block, pathParts: var seq[string], errors: var seq[
    ValidationIssue], depth: var int) =
  var stack = @[BlockFrame(blk: blk, exiting: false)]

  while stack.len > 0:
    let frame = stack.pop()

    if frame.exiting:
      discard pathParts.pop()
      depth -= 1
      continue

    if depth >= MaxRecursionDepth:
      recursionLimitError(MaxRecursionDepth, frame.blk.line, frame.blk.col)

    depth += 1
    pathParts.add(frame.blk.name)
    checkDuplicates(frame.blk.pairs, frame.blk.subBlocks, pathParts, errors)

    for pair in frame.blk.pairs:
      validatePair(pair, pathParts, errors)

    stack.add(BlockFrame(blk: frame.blk, exiting: true))
    for i in countdown(frame.blk.subBlocks.high, 0):
      stack.add(BlockFrame(blk: frame.blk.subBlocks[i], exiting: false))

proc validateConfig*(config: YumlyConf) =
  var errors: seq[ValidationIssue]
  var depth = 0
  var pathParts: seq[string] = @[]

  checkDuplicates(config.pairs, config.blocks, pathParts, errors)

  for pair in config.pairs:
    validatePair(pair, pathParts, errors)

  for blk in config.blocks:
    validateBlock(blk, pathParts, errors, depth)

  if errors.len > 0:
    var messages: seq[string]
    var code = errors[0].code
    var sourceFile = errors[0].sourceFile
    for issue in errors:
      messages.add(issue.message)
      if issue.code != code:
        code = "validator.multiple-errors"
      if issue.sourceFile != sourceFile:
        sourceFile = ""
    configValidationFailedError(errors.len, messages.join("\n\n"), code, errors[
        0].line, errors[0].col, sourceFile)
