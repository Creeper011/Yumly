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
    nkLiteral, # can be a: string, int, float, bool
    nkEnv,
    nkArrayStart,
    nkArrayEnd,
    nkBlockStart,
    nkBlockEnd,
    nkPairStart,
    nkPairEnd,
    nkInclude,
    nkEOF

  YumNode* = ref object
    token*: Token
    name*: string

    case kind*: NodeKind
    of nkLiteral:
      rawValue*: string
    of nkEnv:
      envName*: string
      envDefault*: Option[string]
    of nkArrayStart, nkArrayEnd, nkBlockStart, nkBlockEnd:
      discard
    of nkPairStart:
      key*: string
      typeHint*: Option[TypeHint]
    of nkPairEnd:
      discard
    of nkInclude:
      includePath*: string
    of nkEOF:
      discard
    line*, col*: int
    sourceFile*: string

func nodeRepr(node: YumNode, indent: int): string =
  result = repeat("  ", indent) & $node.kind
  case node.kind
  of nkBlockStart:
    if node.name != "": result.add " \"" & node.name & "\""
  of nkPairStart:
    if node.key != "": result.add " [" & node.key & "]"
  of nkLiteral:
    if node.rawValue != "": result.add " = " & node.rawValue
  of nkEnv:
    if node.envName != "": result.add " $" & node.envName
    if node.envDefault.isSome: result.add " ?? " & node.envDefault.get
  of nkInclude:
    if node.includePath != "": result.add " : " & node.includePath
  of nkArrayEnd, nkBlockEnd, nkPairEnd, nkEOF:
    discard
  else:
    discard
  result.add "\n"

func `$`*(node: YumNode): string =
  nodeRepr(node, 0)

type
  # Closure aliases:
  TokenPuller* = proc(): Token {.closure.}
  NodePuller* = proc(): YumNode {.closure.}
