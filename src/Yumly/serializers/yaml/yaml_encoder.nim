##
# This module converts the Yumly AST into YAML format using NimYAML/yaml  library.
# It is only included when -d:yumlyYaml is defined.
##

import yaml
import ../../types/ast

proc toYamlNode*(val: Value): YamlNode =
  case val.kind
  of vkString:
    result = newYamlNode(val.strVal)
  of vkInt:
    result = newYamlNode($val.intVal)
  of vkFloat:
    result = newYamlNode($val.floatVal)
  of vkBool:
    result = newYamlNode(if val.boolVal: "true" else: "false")
  of vkEnv:
    result = newYamlNode(val.envVal)
  of vkList:
    var elems: seq[YamlNode] = @[]
    for el in val.elements:
      elems.add(toYamlNode(el))
    result = newYamlNode(elems)

proc toYamlNode*(blk: Block): YamlNode =
  var fields: seq[(YamlNode, YamlNode)] = @[]
  for pair in blk.pairs:
    fields.add((newYamlNode(pair.key), toYamlNode(pair.value)))
  for sub in blk.subBlocks:
    fields.add((newYamlNode(sub.name), toYamlNode(sub)))
  result = newYamlNode(fields)

proc toYamlNode*(config: YumlyConf): YamlNode =
  var fields: seq[(YamlNode, YamlNode)] = @[]
  for pair in config.pairs:
    fields.add((newYamlNode(pair.key), toYamlNode(pair.value)))
  for blk in config.blocks:
    fields.add((newYamlNode(blk.name), toYamlNode(blk)))
  result = newYamlNode(fields)

proc toYaml*(config: YumlyConf): string =
  let node = toYamlNode(config)
  var dumper = blockOnlyDumper()
  return dumper.dump(node)

proc toYaml*(val: Value): string =
  let node = toYamlNode(val)
  var dumper = blockOnlyDumper()
  return dumper.dump(node)
