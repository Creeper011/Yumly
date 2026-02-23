##
# This module defines AST (Abstract Syntax Tree) types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import token, options

type
  ValueKind* = enum vkString, vkInt, vkFloat, vkEnv, vkBool, vkList, vkTuple

  TypeHintKind* = enum thString, thInt, thFloat, thBool, thEnv, thList, thTuple

  TypeHint* = object
    case kind*: TypeHintKind
    of thList:
      elementKind*: TypeHintKind
    else: discard

  Value* = object
    case kind*: ValueKind
    of vkString: str*: string
    of vkInt:    intVal*: int
    of vkFloat:  floatVal*: float
    of vkEnv:
      env*: string
      envVal*: string
    of vkBool:   boolVal*: bool
    of vkList:   items*: seq[Value]
    of vkTuple:  elements*: seq[Value]

  Pair* = object
    key*: string
    typeHint*: Option[TypeHint]
    value*: Value
    line*: int
    col*: int

  Block* = object
    name*: string
    pairs*: seq[Pair]
    subBlocks*: seq[Block]
    line*: int
    col*: int

  Include* = object
    includePath*: string

  Config* = object
    blocks*: seq[Block]
    includes*: seq[Include]

  Parser* = object
    tokens*: seq[Token]
    pos*: int
