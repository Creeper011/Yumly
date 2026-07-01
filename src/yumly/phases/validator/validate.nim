##
# This module defines validation logic for evaluated Yumly configs.
##

import ../../constants
import ../../types/ast
import ../../errors/exceptions/validatorerrors
import checks

type
  BlockFrame = object
    blk: Block
    exiting: bool

proc validateBlock(blk: Block, pathParts: var seq[string], depth: var int) =
  var stack = @[BlockFrame(blk: blk, exiting: false)]

  while stack.len > 0:
    let frame = stack.pop()

    if frame.exiting:
      discard pathParts.pop()
      depth -= 1
      continue

    if depth >= MaxRecursionDepth:
      validatorRecursionLimitError(MaxRecursionDepth, frame.blk.source)

    depth += 1
    pathParts.add(frame.blk.name)
    checkDuplicates(frame.blk.items, pathParts)

    for item in frame.blk.items:
      if item.kind == ikPair:
        validatePair(item.pair, pathParts)

    stack.add(BlockFrame(blk: frame.blk, exiting: true))
    for i in countdown(frame.blk.items.high, 0):
      if frame.blk.items[i].kind == ikBlock:
        stack.add(BlockFrame(blk: frame.blk.items[i].blk, exiting: false))

proc validateConfig*(config: YumlyConf) =
  var depth = 0
  var pathParts: seq[string] = @[]

  checkItemStructure(config)
  checkDuplicates(config.items, pathParts)

  for item in config.items:
    if item.kind == ikPair:
      validatePair(item.pair, pathParts)

  for item in config.items:
    if item.kind == ikBlock:
      validateBlock(item.blk, pathParts, depth)

  validateSchemas(config)
