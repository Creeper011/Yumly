##
# Modification utilities for Nim API
##

import ../../types/ast
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

proc applyTypeHints*(config: var YumlyConf) =
  applyInferredTypeHints(config)
