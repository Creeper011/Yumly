##
# This module converts the Yumly AST into JSON format.
# It is only included when -d:yumlyJson is defined.
##

import std/json
import ../../types/ast

proc toJson*(val: Value): JsonNode =
  case val.kind
  of vkString: result = %val.strVal
  of vkInt:    result = %val.intVal
  of vkFloat:  result = %val.floatVal
  of vkBool:   result = %val.boolVal
  of vkList:
    result = newJArray()
    for el in val.elements:
      result.add(toJson(el))
  of vkEnv:
    # Environment variables are exported as their resolved string value
    result = %val.envVal

proc toJson*(blk: Block): JsonNode =
  result = newJObject()
  for pair in blk.pairs:
    result[pair.key] = toJson(pair.value)
  for sub in blk.subBlocks:
    result[sub.name] = toJson(sub)

proc toJson*(config: YumlyConf): JsonNode =
  result = newJObject()
  for pair in config.pairs:
    result[pair.key] = toJson(pair.value)
  for blk in config.blocks:
    result[blk.name] = toJson(blk)
