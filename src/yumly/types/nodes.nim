## This module defines Nodes types used by Parser for the Yumly configuration language :3
##
## The parser consumes tokens on demand and returns YumNode events, so later
## phases can process the file as a stream instead of requiring a full AST.

import token, source, options
import ../types/typehints

when defined(yumlyEnv):
  type
    NodeKind* = enum
      nkLiteral,          # Can be a string, int, float or bool;
      nkEnv,              # Environment value expression;
      nkListStart,        # Opens a list value;
      nkListEnd,          # Closes the current list value;
      nkObjectStart,      # Opens an object value;
      nkObjectEnd,        # Closes the current object value;
      nkSchemaStart,      # Opens a schema;
      nkSchemaEnd,        # Closes the current schema;
      nkSchemaBlockStart, # Opens an inline block field inside a schema;
      nkSchemaBlockEnd,   # Closes an inline block field inside a schema;
      nkSchemaTypedBlock, # Declares an open, typed block field inside a schema;
      nkBlockStart,       # Opens a block;
      nkBlockEnd,         # Closes the current block;
      nkPairStart,        # Opens a key/value pair;
      nkPairEnd,          # Closes the current key/value pair;
      nkInclude,          # Include directive;
      nkEOF               # End of node stream;

    # Coerce Types for env values
    CoerceKind* = enum
      ckString, ckInt, ckFloat, ckBool

    CoerceType* = object
      raw*: string
      line*: SourcePos
      col*: SourcePos
      kind*: CoerceKind

else:

  type NodeKind* = enum
    nkLiteral,          # Can be a string, int, float or bool;
    nkListStart,        # Opens a list value;
    nkListEnd,          # Closes the current list value;
    nkObjectStart,      # Opens an object value;
    nkObjectEnd,        # Closes the current object value;
    nkSchemaStart,      # Opens a schema;
    nkSchemaEnd,        # Closes the current schema;
    nkSchemaBlockStart, # Opens an inline block field inside a schema;
    nkSchemaBlockEnd,   # Closes an inline block field inside a schema;
    nkSchemaTypedBlock, # Declares an open, typed block field inside a schema;
    nkBlockStart,       # Opens a block;
    nkBlockEnd,         # Closes the current block;
    nkPairStart,        # Opens a key/value pair;
    nkPairEnd,          # Closes the current key/value pair;
    nkInclude,          # Include directive;
    nkEOF               # End of node stream;

when defined(yumlyEnv):
  type YumNode* = ref object
    token*: Token
    name*: string

    case kind*: NodeKind
    of nkLiteral:
      rawValue*: string
    of nkEnv:
      envName*: string
      envDefault*: Option[string]
      coerceType*: Option[CoerceType] # Optional conversion for the resolved env value.
    of nkListStart, nkListEnd, nkObjectStart, nkObjectEnd, nkSchemaStart,
        nkSchemaEnd, nkSchemaBlockEnd, nkBlockStart, nkBlockEnd:
      discard
    of nkSchemaBlockStart:
      required*: bool
    of nkSchemaTypedBlock:
      blockType*: TypeHint
    of nkPairStart:
      key*: string
      typeHint*: Option[TypeHint]
    of nkPairEnd:
      discard
    of nkInclude:
      includesPath*: seq[string]
    of nkEOF:
      discard
    line*, col*: SourcePos
    sourceFile*: SourceFile

else:

  type YumNode* = ref object
    token*: Token
    name*: string

    case kind*: NodeKind
    of nkLiteral:
      rawValue*: string
    of nkListStart, nkListEnd, nkObjectStart, nkObjectEnd, nkSchemaStart,
        nkSchemaEnd, nkSchemaBlockEnd, nkBlockStart, nkBlockEnd:
      discard
    of nkSchemaBlockStart:
      required*: bool
    of nkSchemaTypedBlock:
      blockType*: TypeHint
    of nkPairStart:
      key*: string
      typeHint*: Option[TypeHint]
    of nkPairEnd:
      discard
    of nkInclude:
      includesPath*: seq[string]
    of nkEOF:
      discard
    line*, col*: SourcePos
    sourceFile*: SourceFile

type
  # Closure aliases
  NodePuller* = proc(): YumNode {.closure.}

when defined(yumlyEnv):
  func `$`*(node: YumNode): string =
    result = $node.kind
    case node.kind
    of nkBlockStart:
      if node.name != "": result.add(" (" & node.name & ")") # e.g: nkBlockStart (application)
    of nkSchemaStart:
      if node.name != "": result.add(" (" & node.name & ")") # e.g: nkSchemaStart (dependency)
    of nkSchemaBlockStart:
      if node.name != "": result.add(" (" & node.name &
          (if node.required: " required)" else: " optional)"))
    of nkSchemaTypedBlock:
      if node.name != "": result.add(" (" & node.name & " ;" &
          node.blockType.raw & ")")
    of nkObjectStart:
      if node.name != "": result.add(" (" & node.name & ")") # e.g: nkObjectStart (dependency)
    of nkPairStart:
      if node.key != "":
        result.add(" (" & node.key)
        if node.typeHint.isSome: result.add(" ;" & node.typeHint.get.raw)
        result.add(")") # e.g: nkPairStart (key ;string)
    of nkLiteral:
      if node.rawValue != "": result.add(" (" & node.rawValue & ")") # e.g: nkLiteral (1.5.6)
    of nkEnv:
      if node.envName != "": result.add(" (" & node.envName)
      if node.coerceType.isSome: result.add(" " & node.coerceType.get.raw)
      if node.envDefault.isSome: result.add(" " & node.envDefault.get)
      if node.envName != "": result.add(")") # e.g: nkEnv (MAIN_TOKEN int 0)
    of nkInclude:
      if node.includesPath.len > 0:
        result.add(" (")
        for i, path in node.includesPath:
          if i > 0: result.add(", ")
          result.add(path)
        result.add(")") # e.g: nkInclude (.env, other.yumly)
    of nkListEnd, nkObjectEnd, nkSchemaEnd, nkSchemaBlockEnd, nkBlockEnd,
        nkPairEnd, nkEOF:
      discard
    else:
      discard
else:
  func `$`*(node: YumNode): string =
    result = $node.kind
    case node.kind
    of nkBlockStart:
      if node.name != "": result.add(" (" & node.name & ")")
    of nkSchemaStart:
      if node.name != "": result.add(" (" & node.name & ")")
    of nkSchemaBlockStart:
      if node.name != "": result.add(" (" & node.name &
          (if node.required: " required)" else: " optional)"))
    of nkSchemaTypedBlock:
      if node.name != "": result.add(" (" & node.name & " ;" &
          node.blockType.raw & ")")
    of nkObjectStart:
      if node.name != "": result.add(" (" & node.name & ")")
    of nkPairStart:
      if node.key != "":
        result.add(" (" & node.key)
        if node.typeHint.isSome: result.add(" ;" & node.typeHint.get.raw)
        result.add(")")
    of nkLiteral:
      if node.rawValue != "": result.add(" (" & node.rawValue & ")")
    of nkInclude:
      if node.includesPath.len > 0:
        result.add(" (")
        for i, path in node.includesPath:
          if i > 0: result.add(", ")
          result.add(path)
        result.add(")")
    of nkListEnd, nkObjectEnd, nkSchemaEnd, nkSchemaBlockEnd, nkBlockEnd,
        nkPairEnd, nkEOF:
      discard
    else:
      discard
