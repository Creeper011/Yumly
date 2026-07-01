##
# Indexing operators for Nim API
##

import ../../../types/ast
import ../../../errors/exceptions/apierrors

func `[]`*(val: Value, index: int): Item =
  if val.kind != vkList:
    notListError()
  return val.elements[index]

func `[]`*(val: var Value, index: int): var Item =
  if val.kind != vkList:
    notListError()
  return val.elements[index]

func `[]`*(val: Value, key: string): YumlyElement =
  if val.kind != vkObject:
    cannotIndexValueWithStringError(key)
  for item in val.items:
    case item.kind
    of ikPair:
      if item.pair.key == key:
        return YumlyElement(kind: ekValue, val: item.pair.value)
    of ikBlock:
      if item.blk.name == key:
        return YumlyElement(kind: ekBlock, blk: item.blk)
    of ikValue:
      discard
    of ikSchema:
      if item.schema.name == key:
        return YumlyElement(kind: ekSchema, schema: item.schema)
  keyNotFoundError(key)

func `[]`*(config: YumlyConf, key: string): YumlyElement =
  for item in config.items:
    case item.kind
    of ikPair:
      if item.pair.key == key:
        return YumlyElement(kind: ekValue, val: item.pair.value)
    of ikBlock:
      if item.blk.name == key:
        return YumlyElement(kind: ekBlock, blk: item.blk)
    of ikSchema:
      if item.schema.name == key:
        return YumlyElement(kind: ekSchema, schema: item.schema)
    of ikValue:
      discard
  keyNotFoundError(key)

func `[]`*(config: var YumlyConf, key: string): var Value =
  for item in config.items.mitems:
    if item.kind == ikPair and item.pair.key == key:
      return item.pair.value
  keyNotFoundError(key)

func `[]`*(blk: Block, key: string): YumlyElement =
  for item in blk.items:
    case item.kind
    of ikPair:
      if item.pair.key == key:
        return YumlyElement(kind: ekValue, val: item.pair.value)
    of ikBlock:
      if item.blk.name == key:
        return YumlyElement(kind: ekBlock, blk: item.blk)
    of ikValue, ikSchema:
      discard
  keyNotFoundInBlockError(key, blk.name)

func `[]`*(blk: var Block, key: string): var Value =
  for item in blk.items.mitems:
    if item.kind == ikPair and item.pair.key == key:
      return item.pair.value
  keyNotFoundInBlockError(key, blk.name)

func `[]`*(elem: YumlyElement, key: string): YumlyElement =
  case elem.kind
  of ekBlock:
    return elem.blk[key]
  of ekValue:
    return elem.val[key]
  of ekSchema:
    cannotIndexSchemaWithStringError(key)

func `[]`*(elem: YumlyElement, index: int): YumlyElement =
  if elem.kind == ekSchema:
    cannotIndexSchemaWithIntegerError(index)
  elif elem.kind == ekValue and elem.val.kind == vkList:
    let item = elem.val[index]
    case item.kind
    of ikValue:
      return YumlyElement(kind: ekValue, val: item.value)
    of ikPair:
      return YumlyElement(kind: ekValue, val: item.pair.value)
    of ikBlock:
      return YumlyElement(kind: ekBlock, blk: item.blk)
    of ikSchema:
      return YumlyElement(kind: ekSchema, schema: item.schema)
  elif elem.kind == ekBlock:
    cannotIndexBlockWithIntegerError(index)
  else:
    cannotIndexValueWithIntegerError(index)
