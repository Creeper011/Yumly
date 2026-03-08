##
# This module evaluates the validated Yumly AST.
# It converts raw string values into native Nim types, resolves environment
# variables, and constructs the final YumlyConf, Block, and Pair objects.
##

import os, options
import types/nodes, types/token, types/type_hints, types/ast
import types/values_defs

proc isEnvNode(node: YumNode): bool =
  node.kind == nkLiteral and node.token.kind == tkDollar

proc evaluateValue*(node: YumNode, hint: Option[TypeHint]): Value

proc evaluateListElements(nodes: seq[YumNode], hint: Option[TypeHint]): seq[Value] =
  let elemHint =
    if hint.isSome and hint.get.kind == thList:
      some(TypeHint(kind: hint.get.elementKind, raw: hint.get.elementRaw,
                    line: hint.get.line, col: hint.get.col))
    else:
      none(TypeHint)
  for child in nodes:
    result.add(evaluateValue(child, elemHint))

proc isHeterogeneous(elements: seq[Value]): bool =
  if elements.len == 0: return false
  let first = elements[0].kind
  for el in elements:
    if el.kind != first: return true
  false

proc evaluateValue*(node: YumNode, hint: Option[TypeHint]): Value =
  case node.kind
  of nkLiteral:
    if isEnvNode(node):
      # Resolve the env variable at evaluation time
      return Value(kind: vkEnv, envName: node.rawValue,
                   envVal: os.getEnv(node.rawValue))

    for vk in [vkBool, vkInt, vkFloat, vkString]:
      try:
        return VALUES_DEF[vk].decode(node.rawValue)
      except:
        discard

    # Unreachable in practice; strings never fail to decode
    raise newException(Defect,
      "RAHHH >_<, could not decode literal: '" & node.rawValue & "'")

  of nkArray:
    let elements = evaluateListElements(node.children, hint)
    if hint.isSome and hint.get.kind == thTuple:
      return Value(kind: vkTuple, elements: elements)
    elif hint.isNone and isHeterogeneous(elements):
      return Value(kind: vkTuple, elements: elements)
    else:
      return Value(kind: vkList, elements: elements)

  else:
    raise newException(Defect,
      "RAHHH >_<, invalid YumNode kind in evaluateValue: " & $node.kind)

proc evaluatePair*(node: YumNode): Pair =
  Pair(
    key:      node.key,
    typeHint: node.typeHint,
    value:    evaluateValue(node.valNode, node.typeHint),
    line:     node.line,
    col:      node.col
  )

proc evaluateBlock*(node: YumNode): Block =
  result = Block(name: node.name, line: node.line, col: node.col,
                 pairs: @[], subBlocks: @[])
  for child in node.children:
    case child.kind
    of nkPair:  result.pairs.add(evaluatePair(child))
    of nkBlock: result.subBlocks.add(evaluateBlock(child))
    else: discard

proc evaluateConfig*(rootNode: YumNode): YumlyConf =
  result = YumlyConf(blocks: @[], pairs: @[], includes: @[])
  for child in rootNode.children:
    case child.kind
    of nkBlock:   result.blocks.add(evaluateBlock(child))
    of nkPair:    result.pairs.add(evaluatePair(child))
    of nkInclude: result.includes.add(Include(includePath: child.includePath))
    else: discard