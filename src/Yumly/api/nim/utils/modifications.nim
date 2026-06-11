##
# Modification utilities for Nim API
##

import std/options
import ../../../types/ast
import ../../../types/values_defs
import ../../../core/builders
import ../../../error_messages

func addInclude*(container: var YumlyConf, path: string) =
  container.includes.add(Include(includePath: path))

func add*(val: var Value, element: Value) =
  if val.kind notin {vkList}:
    cannotAddToNonListError()
  val.elements.add(element)

func add*(val: var Value, element: string) =
  val.add(newStringValue(element))

func add*(val: var Value, element: int) =
  val.add(newIntValue(element))

func add*(val: var Value, element: float) =
  val.add(newFloatValue(element))

proc applyTypeHints*(config: var YumlyConf) =
  for pair in config.pairs.mitems:
    if pair.typeHint.isNone:
      pair.typeHint = some(inferTypeHintObject(pair.value))
  for blk in config.blocks.mitems:
    for pair in blk.pairs.mitems:
      if pair.typeHint.isNone:
        pair.typeHint = some(inferTypeHintObject(pair.value))
    for sub in blk.subBlocks.mitems:
      for pair in sub.pairs.mitems:
        if pair.typeHint.isNone:
          pair.typeHint = some(inferTypeHintObject(pair.value))
