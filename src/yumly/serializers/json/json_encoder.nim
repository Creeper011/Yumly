##
# This module converts the Yumly AST into JSON format.
# It is only included when -d:yumlyJson is defined.
##

import std/json
import ../../types/ast

proc toJson*(blk: Block): JsonNode

proc toJson*(val: Value): JsonNode =
  when not defined(yumlyEnv):
    {.push warning[UnreachableElse]: off.}
  case val.kind
  of vkString: result = %val.strVal
  of vkInt: result = %val.intVal
  of vkFloat: result = %val.floatVal
  of vkBool: result = %val.boolVal
  of vkList:
    result = newJArray()
    for item in val.elements:
      case item.kind
      of ikPair:
        var obj = newJObject()
        obj[item.pair.key] = toJson(item.pair.value)
        result.add(obj)
      of ikValue:
        result.add(toJson(item.value))
      of ikBlock:
        var obj = newJObject()
        obj[item.blk.name] = toJson(item.blk)
        result.add(obj)
      of ikSchema:
        discard
  of vkObject:
    var onlyNamedItems = true
    for item in val.items:
      if item.kind == ikValue:
        onlyNamedItems = false
        break
    if onlyNamedItems:
      result = newJObject()
      for item in val.items:
        case item.kind
        of ikPair:
          result[item.pair.key] = toJson(item.pair.value)
        of ikBlock:
          result[item.blk.name] = toJson(item.blk)
        of ikValue:
          discard
        of ikSchema:
          discard
    else:
      result = newJArray()
      for item in val.items:
        case item.kind
        of ikPair:
          var obj = newJObject()
          obj[item.pair.key] = toJson(item.pair.value)
          result.add(obj)
        of ikValue:
          result.add(toJson(item.value))
        of ikBlock:
          var obj = newJObject()
          obj[item.blk.name] = toJson(item.blk)
          result.add(obj)
        of ikSchema:
          discard
  else:
    when defined(yumlyEnv):
      if val.kind == vkEnv:
        result = %val.envVal
      else:
        discard # TODO: throw a error here
  when not defined(yumlyEnv):
    {.pop.}

proc toJson*(blk: Block): JsonNode =
  result = newJObject()
  for item in blk.items:
    case item.kind
    of ikPair:
      result[item.pair.key] = toJson(item.pair.value)
    of ikBlock:
      result[item.blk.name] = toJson(item.blk)
    of ikValue, ikSchema:
      discard

proc toJson*(config: YumlyConf): JsonNode =
  result = newJObject()
  for item in config.items:
    case item.kind
    of ikPair:
      result[item.pair.key] = toJson(item.pair.value)
    of ikBlock:
      result[item.blk.name] = toJson(item.blk)
    of ikValue, ikSchema:
      discard
