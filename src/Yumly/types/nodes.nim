##
# This module defines Nodes types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import token, options
import ../types/type_hints

type
  # filled in by the parser

  NodeKind* = enum 
    nkLiteral, # can be a: string, int, float, bool and env
    nkArray,
    nkBlock,
    nkPair,
    nkConfig, nkInclude

  YumNode* = ref object
    token*: Token
    case kind*: NodeKind
    of nkLiteral:
      rawValue*: string
    of nkArray, nkConfig, nkBlock:
      children*: seq[YumNode]
      name*: string
    of nkPair:
      key*: string
      typeHint*: Option[TypeHint]
      valNode*: YumNode
    of nkInclude:
      includePath*: string
      
    line*, col*: int

  Parser* = object
    tokens*: seq[Token]
    pos*: int
    recursionDepth*: int