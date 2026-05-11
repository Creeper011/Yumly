##
# This module defines Nodes types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import token, options
import ../types/type_hints

type
  # NOTE: filled in by the parser

  NodeKind* = enum
    nkLiteral, # can be a: string, int, float, bool and env
    nkArray,
    nkBlock,
    nkPair,
    nkConfig, nkInclude

  YumNode* = ref object
    token*: Token
    children*: seq[YumNode]
    name*: string

    case kind*: NodeKind
    of nkLiteral:
      rawValue*: string
    of nkArray, nkBlock:
      discard           # use children and name field
    of nkConfig:
      hasIncludes*: Option[bool]
      hasTypeHints*: Option[bool]
      hasEnvVars*: Option[bool]
    of nkPair:
      key*: string
      typeHint*: Option[TypeHint]
      valNode*: YumNode # the value node can be a literal, array, block or global ref
    of nkInclude:
      includePath*: string
    line*, col*: int
    sourceFile*: string

type
  TokenPuller* = proc(): Token {.closure.}

  Parser* = object
    puller*: TokenPuller
    currentToken*: Token
    root*: YumNode
    recursionDepth*: int
