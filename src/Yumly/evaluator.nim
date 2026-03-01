##
# This module evaluates the validated Yumly AST.
# It converts raw string values into native Nim types, resolves environment
# variables, and constructs the final Config, Block, and Pair objects.
##

import strutils, os, options
import types/ast

proc evaluateValue*(node: YumNode, hint: Option[TypeHint]): Value

proc evaluateListElements(nodes: seq[YumNode], hint: Option[TypeHint]): seq[Value] =
  var elements: seq[Value] = @[]
  
  let elemHint = if hint.isSome and hint.get.kind == thList:
      some(TypeHint(kind: hint.get.elementKind))
    else:
      none(TypeHint)

  for child in nodes:
    elements.add(evaluateValue(child, elemHint))
    
  return elements

proc isHeterogeneous(elements: seq[Value]): bool =
  if elements.len == 0:
    return false
  let first = elements[0].kind
  for el in elements:
    if el.kind != first:
      return true
  return false

proc evaluateValue*(node: YumNode, hint: Option[TypeHint]): Value =
  case node.kind:
  of nkString:
    return Value(kind: vkString, strVal: node.rawValue)
    
  of nkInt:
    return Value(kind: vkInt, intVal: parseInt(node.rawValue))
    
  of nkFloat:
    return Value(kind: vkFloat, floatVal: parseFloat(node.rawValue))
    
  of nkBool:
    return Value(kind: vkBool, boolVal: node.rawValue.toLowerAscii() == "true")
    
  of nkEnv:
    let realVal = os.getEnv(node.rawValue)
    return Value(kind: vkEnv, envName: node.rawValue, envVal: realVal)
    
  of nkArray:
    let elements = evaluateListElements(node.children, hint)
    
    if hint.isSome and hint.get.kind == thTuple:
      return Value(kind: vkTuple, elements: elements)
    elif hint.isNone and isHeterogeneous(elements):
      return Value(kind: vkTuple, elements: elements)
    else:
      return Value(kind: vkList, elements: elements)
    
  else:
    raise newException(Defect, "RAHHH >_<, invalid YumNode type: " & $node.kind)

proc evaluatePair*(node: YumNode): Pair =
  return Pair(
    key: node.key,
    typeHint: node.typeHint,
    value: evaluateValue(node.valNode, node.typeHint),
    line: node.line,
    col: node.col
  )

proc evaluateBlock*(node: YumNode): Block =
  var blk = Block(
    name: node.name, 
    line: node.line, 
    col: node.col, 
    pairs: @[], 
    subBlocks: @[]
  )
  
  for child in node.children:
    if child.kind == nkPair:
      blk.pairs.add(evaluatePair(child))
    elif child.kind == nkBlock:
      blk.subBlocks.add(evaluateBlock(child))
      
  return blk

proc evaluateConfig*(rootNode: YumNode): Config =
  var config = Config(blocks: @[], includes: @[])
  
  for child in rootNode.children:
    if child.kind == nkBlock:
      config.blocks.add(evaluateBlock(child))
    elif child.kind == nkPair:
      config.pairs.add(evaluatePair(child))
    elif child.kind == nkInclude:
      config.includes.add(Include(includePath: child.rawValue))
      
  return config
