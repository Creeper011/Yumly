##
# This module defines AST (Abstract Syntax Tree) after parsing it
##

import options
import ../types/type_hints

type
  # NOTE: filled in by the evaluator
  ValueKind* = enum
    vkString, vkInt, vkFloat, vkBool, vkList, vkEnv

  Value* = object
    sourceFile*: string
    case kind*: ValueKind
    of vkString: strVal*: string
    of vkInt: intVal*: int
    of vkFloat: floatVal*: float
    of vkBool: boolVal*: bool
    of vkList:
      elements*: seq[Value]
    of vkEnv:
      envName*: string
      envVal*: string
      envFound*: bool
      envDefault*: Option[string]

  Pair* = object
    key*: string
    typeHint*: Option[TypeHint]
    value*: Value
    line*: int
    col*: int
    sourceFile*: string

  Block* = ref object
    name*: string
    pairs*: seq[Pair]
    subBlocks*: seq[Block]
    line*: int
    col*: int
    sourceFile*: string

  Include* = object
    includePath*: string
    sourceFile*: string

  YumlyConf* = ref object
    blocks*: seq[Block]
    pairs*: seq[Pair]
    includes*: seq[Include]

  YumlyElementKind* = enum
    ekValue, ekBlock

  YumlyElement* = object
    case kind*: YumlyElementKind
    of ekValue: val*: Value
    of ekBlock: blk*: Block

converter toValue*(elem: YumlyElement): Value =
  if elem.kind == ekValue: elem.val
  else: raise newException(ValueError, "not a value")

converter toBlock*(elem: YumlyElement): Block =
  if elem.kind == ekBlock: elem.blk
  else: raise newException(ValueError, "not a block")
