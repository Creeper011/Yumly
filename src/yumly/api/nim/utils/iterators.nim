##
# Iterators for Nim API
##

import ../../../types/ast
import ../../../error_messages

iterator items*(val: Value): Value =
  if val.kind != vkList:
    iteratorNonListError()
  for element in val.elements:
    yield element

iterator items*(blk: Block): Block =
  for subBlock in blk.subBlocks:
    yield subBlock

iterator items*(config: YumlyConf): Block =
  for rootBlock in config.blocks:
    yield rootBlock

iterator mitems*(val: var Value): var Value =
  if val.kind != vkList:
    iteratorNonListError()
  for element in val.elements.mitems:
    yield element

iterator mitems*(config: var YumlyConf): var Pair =
  for pair in config.pairs.mitems:
    yield pair

iterator pairs*(blk: Block): (string, Value) =
  for pair in blk.pairs:
    yield (pair.key, pair.value)

iterator pairs*(config: YumlyConf): (string, Value) =
  for pair in config.pairs:
    yield (pair.key, pair.value)
