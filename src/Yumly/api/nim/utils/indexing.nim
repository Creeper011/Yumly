##
# Indexing operators for Nim API
##

import ../../../types/ast
import ../../../error_messages

func `[]`*(val: Value, index: int): Value =
  if val.kind != vkList:
    notListError()
  return val.elements[index]

func `[]`*(val: var Value, index: int): var Value =
  if val.kind != vkList:
    notListError()
  return val.elements[index]

func `[]`*(config: YumlyConf, key: string): YumlyElement =
  for pair in config.pairs:
    if pair.key == key: return YumlyElement(kind: ekValue, val: pair.value)
  for blk in config.blocks:
    if blk.name == key: return YumlyElement(kind: ekBlock, blk: blk)
  keyNotFoundError(key)

func `[]`*(config: var YumlyConf, key: string): var Value =
  if config.pairs.len == 0:
    keyNotFoundError(key)
  result = config.pairs[0].value
  for pair in config.pairs.mitems:
    if pair.key == key: return pair.value
  keyNotFoundError(key)

func `[]`*(blk: Block, key: string): YumlyElement =
  for pair in blk.pairs:
    if pair.key == key: return YumlyElement(kind: ekValue, val: pair.value)
  for subBlock in blk.subBlocks:
    if subBlock.name == key: return YumlyElement(kind: ekBlock, blk: subBlock)
  keyNotFoundInBlockError(key, blk.name)

func `[]`*(blk: var Block, key: string): var Value =
  if blk.pairs.len == 0:
    keyNotFoundInBlockError(key, blk.name)
  result = blk.pairs[0].value
  for pair in blk.pairs.mitems:
    if pair.key == key: return pair.value
  keyNotFoundInBlockError(key, blk.name)

func `[]`*(elem: YumlyElement, key: string): YumlyElement =
  if elem.kind == ekBlock:
    return elem.blk[key]
  else:
    raise newException(ValueError, "Cannot index a value with string: '" & key & "'")

func `[]`*(elem: YumlyElement, index: int): YumlyElement =
  if elem.kind == ekValue:
    return YumlyElement(kind: ekValue, val: elem.val[index])
  else:
    raise newException(ValueError, "Cannot index a block with integer index: " & $index)