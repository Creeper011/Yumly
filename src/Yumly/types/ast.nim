##
# This module defines AST (Abstract Syntax Tree) after parsing it
##

import options
import ../types/type_hints

type
  # NOTE: filled in by the evaluator
  ValueKind* = enum 
    vkString, vkInt, vkFloat, vkBool, vkList, vkTuple, vkEnv

  Value* = object
    case kind*: ValueKind
    of vkString:    strVal*: string
    of vkInt:       intVal*: int
    of vkFloat:     floatVal*: float
    of vkBool:      boolVal*: bool
    of vkList, vkTuple:
      elements*: seq[Value]
    of vkEnv:
      envName*: string
      envVal*: string

  Pair* = object
    key*: string
    typeHint*: Option[TypeHint]
    value*: Value
    line*: int
    col*: int

  Block* = ref object
    name*: string
    pairs*: seq[Pair]
    subBlocks*: seq[Block]
    line*: int
    col*: int

  Include* = object
    includePath*: string

  YumlyConf* = ref object
    blocks*: seq[Block]
    pairs*: seq[Pair]
    includes*: seq[Include]