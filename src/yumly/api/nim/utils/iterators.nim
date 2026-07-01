##
# Iterators for Nim API
##

import ../../../types/ast
import ../../../errors/exceptions/apierrors

iterator items*(val: Value): Item =
  if val.kind != vkList:
    iteratorNonListError()
  for element in val.elements:
    yield element

iterator items*(blk: Block): Item =
  for item in blk.items:
    yield item

iterator items*(config: YumlyConf): Item =
  for item in config.items:
    yield item

iterator mitems*(val: var Value): var Item =
  if val.kind != vkList:
    iteratorNonListError()
  for element in val.elements.mitems:
    yield element

iterator mitems*(blk: var Block): var Item =
  for item in blk.items.mitems:
    yield item

iterator mitems*(config: var YumlyConf): var Item =
  for item in config.items.mitems:
    yield item

iterator pairs*(blk: Block): (string, Value) =
  for item in blk.items:
    if item.kind == ikPair:
      yield (item.pair.key, item.pair.value)

iterator pairs*(config: YumlyConf): (string, Value) =
  for item in config.items:
    if item.kind == ikPair:
      yield (item.pair.key, item.pair.value)
