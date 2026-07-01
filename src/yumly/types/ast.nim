## Defines AST (Abstract Syntax Tree) after parsing it

import options
import ../types/[source, typehints]

when defined(yumlyEnv):
  type ValueKind* = enum
    vkString, vkInt, vkFloat, vkBool, vkList, vkEnv, vkObject
else:
  type ValueKind* = enum
    vkString, vkInt, vkFloat, vkBool, vkList, vkObject

type
  SchemaFieldKind* = enum
    sfValue, sfInlineBlock, sfTypedBlock

  SchemaField* = object
    key*: string
    line*, col*, endLine*, endCol*: SourcePos
    case kind*: SchemaFieldKind
    of sfValue:
      typeHint*: TypeHint
      defaultValue*: Option[Value]
    of sfInlineBlock:
      required*: bool
      fields*: seq[SchemaField]
    of sfTypedBlock:
      valueType*: TypeHint

  Schema* = ref object
    name*: string
    source*: SourceSpan
    fields*: seq[SchemaField]

  Value* = object
    # when env is enabled
    when defined(yumlyEnv):
      source*: SourceSpan
      case kind*: ValueKind
      of vkString: strVal*: string
      of vkInt: intVal*: int
      of vkFloat: floatVal*: float
      of vkBool: boolVal*: bool
      of vkList:
        elements*: seq[Item]
      of vkEnv:
        envName*: string
        envVal*: string
        envFound*: bool
        envDefault*: Option[string]
      of vkObject:
        schema*: Option[Schema]
        items*: seq[Item]
    # when env is not enabled
    else:
      source*: SourceSpan
      case kind*: ValueKind
      of vkString: strVal*: string
      of vkInt: intVal*: int
      of vkFloat: floatVal*: float
      of vkBool: boolVal*: bool
      of vkList:
        elements*: seq[Item]
      of vkObject:
        schema*: Option[Schema]
        items*: seq[Item] # can contain pairs and blocks

  ItemKind* = enum
    ikPair, ikValue, ikBlock, ikSchema

  Item* = object
    case kind*: ItemKind
    of ikPair:
      pair*: Pair
    of ikValue:
      value*: Value # can be a int, string, float, bool, env and a object
    of ikBlock:
      blk*: Block
    of ikSchema:
      schema*: Schema

  Pair* = object
    key*: string
    typeHint*: Option[TypeHint]
    value*: Value
    source*: SourceSpan

  Block* = ref object
    name*: string
    items*: seq[Item]
    source*: SourceSpan

  Include* = object
    target*: SourceFile
    source*: SourceSpan

  YumlyConf* = ref object
    items*: seq[Item]

  YumlyElementKind* = enum
    ekValue, ekBlock, ekSchema

  YumlyElement* = object
    case kind*: YumlyElementKind
    of ekValue: val*: Value
    of ekBlock: blk*: Block
    of ekSchema: schema*: Schema

converter toValue*(elem: YumlyElement): Value =
  if elem.kind == ekValue: elem.val
  else: raise newException(ValueError, "not a value")

converter toBlock*(elem: YumlyElement): Block =
  if elem.kind == ekBlock: elem.blk
  else: raise newException(ValueError, "not a block")

converter toSchema*(elem: YumlyElement): Schema =
  if elem.kind == ekSchema: elem.schema
  else: raise newException(ValueError, "not a schema")

template constraint*(pair: Pair): untyped =
  pair.typeHint

template constraint*(pair: var Pair): untyped =
  pair.typeHint
