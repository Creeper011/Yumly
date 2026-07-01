##
# This module converts the Yumly AST into YAML format using NimYAML/yaml  library.
# It is only included when -d:yumlyYaml is defined.
##

import yaml
import ../../types/ast

proc toYamlNode*(blk: Block): YamlNode

proc toYamlNode*(val: Value): YamlNode =
  when not defined(yumlyEnv):
    {.push warning[UnreachableElse]: off.}
  case val.kind
  of vkString:
    result = newYamlNode(val.strVal)
  of vkInt:
    result = newYamlNode($val.intVal)
  of vkFloat:
    result = newYamlNode($val.floatVal)
  of vkBool:
    result = newYamlNode(if val.boolVal: "true" else: "false")
  of vkList:
    var elems: seq[YamlNode] = @[]
    for item in val.elements:
      case item.kind
      of ikPair:
        elems.add(newYamlNode(@[(newYamlNode(item.pair.key),
            toYamlNode(item.pair.value))]))
      of ikValue:
        elems.add(toYamlNode(item.value))
      of ikBlock:
        elems.add(newYamlNode(@[(newYamlNode(item.blk.name),
            toYamlNode(item.blk))]))
      of ikSchema:
        discard
    result = newYamlNode(elems)
  of vkObject:
    var onlyNamedItems = true
    for item in val.items:
      if item.kind == ikValue:
        onlyNamedItems = false
        break
    if onlyNamedItems:
      var fields: seq[(YamlNode, YamlNode)] = @[]
      for item in val.items:
        case item.kind
        of ikPair:
          fields.add((newYamlNode(item.pair.key), toYamlNode(item.pair.value)))
        of ikBlock:
          fields.add((newYamlNode(item.blk.name), toYamlNode(item.blk)))
        of ikValue:
          discard
        of ikSchema:
          discard
      result = newYamlNode(fields)
    else:
      var elems: seq[YamlNode] = @[]
      for item in val.items:
        case item.kind
        of ikPair:
          elems.add(newYamlNode(@[(newYamlNode(item.pair.key),
              toYamlNode(item.pair.value))]))
        of ikValue:
          elems.add(toYamlNode(item.value))
        of ikBlock:
          elems.add(newYamlNode(@[(newYamlNode(item.blk.name),
              toYamlNode(item.blk))]))
        of ikSchema:
          discard
      result = newYamlNode(elems)
  else:
    when defined(yumlyEnv):
      if val.kind == vkEnv:
        result = newYamlNode(val.envVal)
      else:
        discard # TODO: throw a error here
  when not defined(yumlyEnv):
    {.pop.}

proc toYamlNode*(blk: Block): YamlNode =
  var fields: seq[(YamlNode, YamlNode)] = @[]
  for item in blk.items:
    case item.kind
    of ikPair:
      fields.add((newYamlNode(item.pair.key), toYamlNode(item.pair.value)))
    of ikBlock:
      fields.add((newYamlNode(item.blk.name), toYamlNode(item.blk)))
    of ikValue, ikSchema:
      discard
  result = newYamlNode(fields)

proc toYamlNode*(config: YumlyConf): YamlNode =
  var fields: seq[(YamlNode, YamlNode)] = @[]
  for item in config.items:
    case item.kind
    of ikPair:
      fields.add((newYamlNode(item.pair.key), toYamlNode(item.pair.value)))
    of ikBlock:
      fields.add((newYamlNode(item.blk.name), toYamlNode(item.blk)))
    of ikValue, ikSchema:
      discard
  result = newYamlNode(fields)

proc toYaml*(config: YumlyConf): string =
  let node = toYamlNode(config)
  var dumper = blockOnlyDumper()
  return dumper.dump(node)

proc toYaml*(val: Value): string =
  let node = toYamlNode(val)
  var dumper = blockOnlyDumper()
  return dumper.dump(node)
