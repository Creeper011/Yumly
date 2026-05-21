##
# Indexing operators for Nim API
##

import ../../types/ast
import ../../error_messages

func `[]`*(val: Value, index: int): Value =
  if val.kind notin {vkList, vkTuple}:
    notListTupleError()
  return val.elements[index]

func `[]`*(val: var Value, index: int): var Value =
  if val.kind notin {vkList, vkTuple}:
    notListTupleError()
  return val.elements[index]

func `[]`*(config: YumlyConf, key: string): Value =
  for pair in config.pairs:
    if pair.key == key: return pair.value
  keyNotFoundError(key)

func `[]`*(config: var YumlyConf, key: string): var Value =
  if config.pairs.len == 0:
    keyNotFoundError(key)
  result = config.pairs[0].value
  for pair in config.pairs.mitems:
    if pair.key == key: return pair.value
  keyNotFoundError(key)

func `[]`*(blk: Block, key: string): Value =
  for pair in blk.pairs:
    if pair.key == key: return pair.value
  keyNotFoundInBlockError(key, blk.name)

func `[]`*(blk: var Block, key: string): var Value =
  if blk.pairs.len == 0:
    keyNotFoundInBlockError(key, blk.name)
  result = blk.pairs[0].value
  for pair in blk.pairs.mitems:
    if pair.key == key: return pair.value
  keyNotFoundInBlockError(key, blk.name)