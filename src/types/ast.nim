##
# This module defines AST (Abstract Syntax Tree) types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import token, options

type
  ValueKind* = enum vkString, vkInt, vkFloat, vkEnv, vkBool

  Value* = object
    case kind*: ValueKind
    of vkString: str*: string
    of vkInt:    intVal*: int
    of vkFloat:  floatVal*: float
    of vkEnv:
      env*: string
      envVal*: string
    of vkBool:   boolVal*: bool

  Pair* = object
    key*: string
    typeHint*: Option[ValueKind]
    value*: Value

  Block* = object
    name*: string
    pairs*: seq[Pair]
    subBlocks*: seq[Block]

  Include* = object
    includePath*: string

  Config* = object
    blocks*: seq[Block]
    includes*: seq[Include]

  Parser* = object
    tokens*: seq[Token]
    pos*: int
