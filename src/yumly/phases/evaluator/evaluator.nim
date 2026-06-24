##
# This module evaluates the validated Yumly AST.
# It converts raw string values into native Nim types, resolves environment
# variables, and constructs the final YumlyConf, Block, and Pair objects.
##

import os, options
import ../../types/nodes, ../../types/type_hints, ../../types/ast,
    ../../types/token, ../../types/values_defs
import ../../error_messages

type
  EvalContextKind = enum ecBlock, ecPair, ecList

  EvalContext = object
    case kind: EvalContextKind
    of ecBlock:
      blk: Block
    of ecPair:
      pairKey: string
      pairTypeHint: Option[TypeHint]
      pairValue: Option[Value]
      pairLine: int
      pairCol: int
      pairSourceFile: string
    of ecList:
      elements: seq[Value]
      elemHint: Option[TypeHint]
      listSourceFile: string

proc evaluateEnv(node: YumNode): Value =
  let decodedDefault = if node.envDefault.isSome: some(decodeString(
      node.envDefault.get, node.line, node.col).strVal) else: none(string)
  # If VAR exists as "", keep it different from a missing VAR.
  let envFound = os.existsEnv(node.envName)
  let envVal =
    if envFound: os.getEnv(node.envName)
    elif decodedDefault.isSome: decodedDefault.get
    else: ""

  Value(kind: vkEnv, envName: node.envName, envVal: envVal, envFound: envFound,
      envDefault: decodedDefault, sourceFile: node.sourceFile)

func listElementHint(hint: Option[TypeHint]): Option[TypeHint] =
  if hint.isSome and hint.get.kind == thList:
    let typeHint = hint.get
    return some(TypeHint(kind: typeHint.elementKind, raw: typeHint.elementRaw,
        line: typeHint.line, col: typeHint.col))
  none(TypeHint)

proc newConfig(): YumlyConf =
  new(result)
  result.blocks = @[]
  result.pairs = @[]
  result.includes = @[]

proc addPair(config: YumlyConf, stack: var seq[EvalContext], pair: Pair) =
  # If a block is open, the pair belongs to that block instead of root.
  if stack.len > 0 and stack[^1].kind == ecBlock:
    stack[^1].blk.pairs.add(pair)
  else:
    config.pairs.add(pair)

proc addBlock(config: YumlyConf, stack: var seq[EvalContext], blk: Block) =
  # If a parent block is open, the closed block becomes its child block.
  if stack.len > 0 and stack[^1].kind == ecBlock:
    stack[^1].blk.subBlocks.add(blk)
  else:
    config.blocks.add(blk)

proc addValue(stack: var seq[EvalContext], value: Value) =
  # If there is no value owner, the stream emitted a scalar in an invalid place.
  if stack.len == 0:
    invalidNodeKindInEvaluateError("stream value without parent")

  case stack[^1].kind
  of ecPair:
    stack[^1].pairValue = some(value)
  of ecList:
    stack[^1].elements.add(value)
  of ecBlock:
    invalidNodeKindInEvaluateError("stream value inside block")

func arrayHint(stack: seq[EvalContext]): Option[TypeHint] =
  if stack.len == 0:
    return none(TypeHint)

  case stack[^1].kind
  of ecPair:
    stack[^1].pairTypeHint
  of ecList:
    stack[^1].elemHint
  of ecBlock:
    none(TypeHint)

proc evaluateScalar(node: YumNode): Value =
  case node.kind
  of nkLiteral:
    case node.token.kind
    of tkString: result = decodeString(node.rawValue, node.line, node.col)
    of tkLiteral: result = classifyLiteral(node.rawValue)
    else: invalidLiteralTokenError($node.token.kind)
    result.sourceFile = node.sourceFile
  of nkEnv:
    result = evaluateEnv(node)
  else:
    invalidNodeKindInEvaluateError($node.kind)

proc evaluateStreamNode(config: YumlyConf, stack: var seq[EvalContext],
    node: YumNode) =
  case node.kind
  of nkLiteral, nkEnv:
    stack.addValue(evaluateScalar(node))

  of nkArrayStart:
    stack.add(EvalContext(kind: ecList, elements: @[],
        elemHint: listElementHint(stack.arrayHint()),
        listSourceFile: node.sourceFile))

  of nkArrayEnd:
    # If the top context is not a list, this ']' has no matching '['.
    if stack.len == 0 or stack[^1].kind != ecList:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    stack.addValue(Value(kind: vkList, elements: ctx.elements,
        sourceFile: ctx.listSourceFile))

  of nkPairStart:
    stack.add(EvalContext(kind: ecPair, pairKey: node.key,
        pairTypeHint: node.typeHint, pairValue: none(Value),
        pairLine: node.line, pairCol: node.col,
        pairSourceFile: node.sourceFile))

  of nkPairEnd:
    # If the pair has no value yet, the stream closed it too early.
    if stack.len == 0 or stack[^1].kind != ecPair or stack[^1].pairValue.isNone:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    config.addPair(stack, Pair(key: ctx.pairKey, typeHint: ctx.pairTypeHint,
        value: ctx.pairValue.get, line: ctx.pairLine, col: ctx.pairCol,
        sourceFile: ctx.pairSourceFile))

  of nkBlockStart:
    var newBlock: Block
    new(newBlock)
    newBlock.name = node.name
    newBlock.line = node.line
    newBlock.col = node.col
    newBlock.sourceFile = node.sourceFile
    newBlock.pairs = @[]
    newBlock.subBlocks = @[]
    stack.add(EvalContext(kind: ecBlock, blk: newBlock))

  of nkBlockEnd:
    # If the top context is not a block, this '}' has no matching block start.
    if stack.len == 0 or stack[^1].kind != ecBlock:
      invalidNodeKindInEvaluateError($node.kind)
    let ctx = stack.pop()
    config.addBlock(stack, ctx.blk)

  of nkInclude:
    config.includes.add(Include(includePath: node.includePath,
        sourceFile: node.sourceFile))

  of nkEOF:
    invalidNodeKindInEvaluateError($node.kind)

proc evaluateNodes*(puller: NodePuller): YumlyConf =
  var stack: seq[EvalContext] = @[]
  result = newConfig()

  while true:
    let node = puller()
    if node.kind == nkEOF:
      # If EOF arrives with open contexts, a structural node was never closed.
      if stack.len > 0:
        invalidNodeKindInEvaluateError("unterminated stream")
      return
    result.evaluateStreamNode(stack, node)
