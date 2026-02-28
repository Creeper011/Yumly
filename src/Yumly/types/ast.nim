##
# This module defines AST (Abstract Syntax Tree) types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import token, options

type
  # filled in by the parser and validated by validator
  TypeHintKind* = enum thUnknown, thString, thInt, thFloat, thBool, thEnv, thList, thTuple

  TypeHint* = object
    raw*: string
    case kind*: TypeHintKind
    of thList:
      elementKind*: TypeHintKind
      elementRaw*: string
    else: discard

  NodeKind* = enum 
    nkString, nkInt, nkFloat, nkBool, 
    nkEnv,
    nkArray,
    nkBlock,
    nkPair,
    nkConfig, nkInclude

  YumNode* = ref object
    token*: Token
    case kind*: NodeKind
    of nkString, nkInt, nkFloat, nkEnv, nkInclude:
      rawValue*: string
    of nkBool:
      boolVal*: bool
    of nkArray, nkConfig, nkBlock:
      children*: seq[YumNode]
      name*: string
    of nkPair:
      key*: string
      typeHint*: Option[TypeHint]
      valNode*: YumNode
      
    line*, col*: int

  # filled in by the evaluator
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
    pairs*: seq[Pair]
    includes*: seq[Include]

  Parser* = object
    tokens*: seq[Token]
    pos*: int
    recursionDepth*: int
