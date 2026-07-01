##
# Modification utilities for Nim API
##

import std/options
import ../../../types/ast
import ../../../core/builders
import ../../../errors/exceptions/apierrors

func add*(val: var Value, element: Value) =
  if val.kind notin {vkList}:
    cannotAddToNonListError()
  val.elements.add(Item(kind: ikValue, value: element))

func add*(val: var Value, element: string) =
  val.add(newStringValue(element))

func add*(val: var Value, element: int) =
  val.add(newIntValue(element))

func add*(val: var Value, element: float) =
  val.add(newFloatValue(element))

proc applyTypeHintsToItems(items: var seq[Item])
proc applyTypeHintsToValue(value: var Value)

proc applyTypeHintsToSchemaFields(fields: var seq[SchemaField]) =
  for field in fields.mitems:
    case field.kind
    of sfValue:
      if field.defaultValue.isSome:
        var defaultValue = field.defaultValue.get
        applyTypeHintsToValue(defaultValue)
        field.defaultValue = some(defaultValue)
    of sfInlineBlock:
      applyTypeHintsToSchemaFields(field.fields)
    of sfTypedBlock:
      discard

proc applyTypeHintsToValue(value: var Value) =
  case value.kind
  of vkList:
    applyTypeHintsToItems(value.elements)
  of vkObject:
    applyTypeHintsToItems(value.items)
  else:
    discard

proc applyTypeHintsToItems(items: var seq[Item]) =
  for item in items.mitems:
    case item.kind
    of ikPair:
      if item.pair.typeHint.isNone:
        item.pair.typeHint = some(typeHintFor(item.pair.value))
      applyTypeHintsToValue(item.pair.value)
    of ikValue:
      applyTypeHintsToValue(item.value)
    of ikBlock:
      applyTypeHintsToItems(item.blk.items)
    of ikSchema:
      applyTypeHintsToSchemaFields(item.schema.fields)

proc applyTypeHints*(config: var YumlyConf) =
  applyTypeHintsToItems(config.items)
