##
# This module defines Nodes types for the Yumly configuration language. These types
# are used to represent the parsed structure of Yumly configuration files in memory.
##
import std/strutils
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

func nodeRepr(node: YumNode, indent: int): string =
    result = repeat("  ", indent) & $node.kind
    case node.kind
    of nkBlock:
        if node.name != "": result.add " \"" & node.name & "\""
    of nkPair:
        if node.key != "": result.add " [" & node.key & "]"
    of nkLiteral:
        if node.rawValue != "": result.add " = " & node.rawValue
    of nkInclude:
        if node.includePath != "": result.add " : " & node.includePath
    else: discard
    result.add "\n"
    for child in node.children:
        result.add nodeRepr(child, indent + 1)
    if node.kind == nkPair and node.valNode != nil:
        result.add nodeRepr(node.valNode, indent + 1)

func `$`*(node: YumNode): string =
    nodeRepr(node, 0)

type
  TokenPuller* = proc(): Token {.closure.}

  Parser* = object
    puller*: TokenPuller
    currentToken*: Token
    root*: YumNode
    recursionDepth*: int
