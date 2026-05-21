##
# Modification utilities for Nim API
##

import std/options
import ../../types/ast, ../../types/type_hints
import ../../utils/value_utils
import ../../core/builders
import ../../error_messages

func addInclude*(container: var YumlyConf, path: string) =
  container.includes.add(Include(includePath: path))

func add*(val: var Value, element: Value) =
  if val.kind notin {vkList, vkTuple}:
    cannotAddToNonListTupleError()
  val.elements.add(element)

func add*(val: var Value, element: string) =
  val.add(newStringValue(element))

func add*(val: var Value, element: int) =
  val.add(newIntValue(element))

func add*(val: var Value, element: float) =
  val.add(newFloatValue(element))

func applyTypeHints*(pairs: var seq[Pair]) =
  for p in pairs.mitems:
    if p.typeHint.isNone:
      p.typeHint = some(TypeHint(raw: inferTypeHint(p.value), kind: thUnknown))

func applyTypeHintsRec(blocks: var seq[Block]) =
  for b in blocks.mitems:
    applyTypeHints(b.pairs)
    applyTypeHintsRec(b.subBlocks)

func applyTypeHints*(config: var YumlyConf) =
  applyTypeHints(config.pairs)
  applyTypeHintsRec(config.blocks)

