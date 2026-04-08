##
# This module handles symbol resolution, interpolation, and circular reference detection.
##

import strutils
import tables
import ../types/nodes, ../types/ast, ../types/token
import ../types/values_defs
import ../error_messages

proc collectSymbols*(rootNode: YumNode): Table[string, YumNode] =
  # collect all symbols declared at root level and return them as a table
  for child in rootNode.children:
    if child.kind != nkSymbolDecl:
      continue

    # check if symbol has already seen in result (duplicate symbol with same name)
    if result.hasKey(child.key):
      duplicateSymbolError(child.key, child.line, child.col)

    # add symbol to result table
    result[child.key] = child

# Fostforward declarations
proc resolveValueNode(node: YumNode, symbols: Table[string, YumNode], stack: var seq[string]): YumNode
proc interpolateSymbols*(rawTemplate: string, line, col: int, symbols: Table[string, YumNode], stack: var seq[string]): string
 
proc evaluateSymbolNode(node: YumNode): Value =
  if node.kind != nkLiteral:
    evaluateLiteralExpectedError($node.kind)

  case node.token.kind
  of tkString, tkBang:
    result = decodeString(node.rawValue, node.line, node.col)
  of tkLiteral:
    result = classifyLiteral(node.rawValue)
  else:
    invalidLiteralTokenError($node.token.kind)

proc renderLiteralNode(node: YumNode, symbolName: string): string =
  if node.kind != nkLiteral:
    literalCannotInterpolateError(symbolName, node.line, node.col)

  let value = evaluateSymbolNode(node)
  case value.kind
  of vkString:
    result = value.strVal
  of vkInt:
    result = $value.intVal
  of vkFloat:
    result = $value.floatVal
  of vkBool:
    result = (if value.boolVal: "true" else: "false")
  of vkEnv:
    result = value.envVal
  of vkList, vkTuple:
    collectionCannotInterpolateError(symbolName, node.line, node.col)

proc resolveSymbolValue(name: string, line, col: int, symbols: Table[string, YumNode], stack: var seq[string]): YumNode =
  if not symbols.hasKey(name):
    unknownSymbolError(name, line, col)

  if name in stack:
    let cycle = (stack & @[name]).join(" -> @")
    circularSymbolRefError(cycle, line, col)

  stack.add(name)
  result = resolveValueNode(symbols[name].valNode, symbols, stack)
  discard stack.pop()

proc resolveValueNode(node: YumNode, symbols: Table[string, YumNode],
                      stack: var seq[string]): YumNode =
  case node.kind
  of nkLiteral:
    # if the literal is a string with interpolation, resolve it    
    if node.token.kind == tkBang:
      let raw = interpolateSymbols(node.rawValue, node.line, node.col, symbols, stack)
      return YumNode(
        kind: nkLiteral,
        rawValue: raw,
        token: Token(kind: tkString, value: raw, line: node.line, col: node.col),
        line: node.line,
        col: node.col
      )
    # if it's a normal literal, just return it
    return node

  of nkGlobalRef:
    return resolveSymbolValue(node.refName, node.line, node.col, symbols, stack)

  of nkArray:
    result = YumNode(kind: nkArray, children: @[], name: node.name,
                     token: node.token, line: node.line, col: node.col)
    for child in node.children:
      result.children.add(resolveValueNode(child, symbols, stack))

  else:
    return node

proc interpolateSymbols*(rawTemplate: string, line, col: int, symbols: Table[string, YumNode], stack: var seq[string]): string =
  var i = 0
  while i < rawTemplate.len:
    # if raw template starts with '@' followed by an identifier and is in IdentStartChars, try to resolve it as a symbol reference
    if rawTemplate[i] == '@' and i + 1 < rawTemplate.len and rawTemplate[i + 1] in IdentStartChars:
      # get the name of the symbol reference after '@'
      let start = i + 1
      # 
      i += 2
      while i < rawTemplate.len and rawTemplate[i] in IdentChars + {'/', '.', '-'}:
        i += 1
      let name = rawTemplate[start ..< i]
      let resolvedNode = resolveSymbolValue(name, line, col, symbols, stack)
      result.add(renderLiteralNode(resolvedNode, name))
      continue

    result.add(rawTemplate[i])
    i += 1

proc resolveSymbolsInTree(node: YumNode, symbols: Table[string, YumNode], stack: var seq[string]) =
  case node.kind
  of nkPair:
    node.valNode = resolveValueNode(node.valNode, symbols, stack)

  of nkSymbolDecl:
    node.valNode = resolveValueNode(node.valNode, symbols, stack)

  of nkArray, nkBlock, nkConfig:
    for child in node.children:
      resolveSymbolsInTree(child, symbols, stack)

  else:
    discard

proc resolveSymbols*(rootNode: YumNode) =
  if rootNode.kind != nkConfig:
    return

  let symbols = collectSymbols(rootNode)
  var stack: seq[string] = @[]
  resolveSymbolsInTree(rootNode, symbols, stack)