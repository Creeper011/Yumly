##
# This module defines the base types and definitions for Yumly values,
# including their decoding and encoding logic with support for different styles.
##

import ../types/ast
import strutils, sequtils, options
import ../error_messages

type
  EncodingStyle* = enum
    styleYumly,
    styleYumyumy # NOTE: yumyumy is a representative format

  ValueDef* = object
    typeHint*: string
    decode*: proc (raw: string, line: int, col: int): Value {.noSideEffect.}
    encode*: proc (val: Value, style: EncodingStyle): string {.noSideEffect.}

func decodeEscapes(raw: string, line, col: int): string =
  var i = 0
  while i < raw.len:
    if raw[i] == '\\' and i + 1 < raw.len:
      case raw[i+1]:
      of 'n': result.add('\n'); i += 2
      of 't': result.add('\t'); i += 2
      of '\\': result.add('\\'); i += 2
      of '"': result.add('"'); i += 2
      of '\'': result.add('\''); i += 2
      else: invalidEscapeError(raw[i+1], line, col)
    else:
      result.add(raw[i]); i += 1

func encodeEscapes(raw: string): string =
  for ch in raw:
    case ch:
    of '\n': result.add("\\n")
    of '\t': result.add("\\t")
    of '\\': result.add("\\\\")
    of '"': result.add("\\\"")
    else: result.add(ch)

# Decode Methods

func decodeString*(raw: string, line, col: int): Value =
  Value(kind: vkString, strVal: decodeEscapes(raw, line, col))

func decodeInt*(raw: string, line, col: int): Value =
  Value(kind: vkInt, intVal: parseInt(raw))

func decodeFloat*(raw: string, line, col: int): Value =
  Value(kind: vkFloat, floatVal: parseFloat(raw))

func decodeBool*(raw: string, line, col: int): Value =
  if raw == "true":
    result = Value(kind: vkBool, boolVal: true)
  elif raw == "false":
    result = Value(kind: vkBool, boolVal: false)
  else:
    invalidBooleanError(raw)

func decodeEnv*(raw: string, line, col: int): Value =
  Value(kind: vkEnv, envName: raw, envVal: "")

func decodeList*(raw: string, line, col: int): Value =
  Value(kind: vkList, elements: @[])

func decodeTuple*(raw: string, line, col: int): Value =
  Value(kind: vkTuple, elements: @[])

# Encode Methods

func encodeValue*(val: Value, style: EncodingStyle = styleYumly): string

func encodeString(val: Value, style: EncodingStyle): string =
  case style
  of styleYumly: return "\"" & encodeEscapes(val.strVal) & "\""
  of styleYumyumy: return val.strVal

func encodeInt(val: Value, style: EncodingStyle): string =
  $val.intVal

func encodeFloat(val: Value, style: EncodingStyle): string =
  $val.floatVal

func encodeBool(val: Value, style: EncodingStyle): string =
  if val.boolVal: "true" else: "false"

func encodeEnv(val: Value, style: EncodingStyle): string =
  case style
  of styleYumly: "$[\"" & val.envName & "\"]"
  of styleYumyumy: "\"" & val.envVal & "\""

func encodeList(val: Value, style: EncodingStyle): string =
  let elements = val.elements.mapIt(encodeValue(it, style)).join(", ")
  "[" & elements & "]"

func encodeTuple(val: Value, style: EncodingStyle): string =
  let elements = val.elements.mapIt(encodeValue(it, style)).join(", ")
  case style
  of styleYumly: "[" & elements & "]"
  of styleYumyumy: "(" & elements & ")"

func encodeValue*(val: Value, style: EncodingStyle = styleYumly): string =
  case val.kind
  of vkString: encodeString(val, style)
  of vkInt: encodeInt(val, style)
  of vkFloat: encodeFloat(val, style)
  of vkBool: encodeBool(val, style)
  of vkEnv: encodeEnv(val, style)
  of vkList: encodeList(val, style)
  of vkTuple: encodeTuple(val, style)

const VALUES_DEF*: array[ValueKind, ValueDef] = [
  vkString: ValueDef(
    typeHint: "string",
    decode: decodeString,
    encode: encodeString
  ),
  vkInt: ValueDef(
    typeHint: "int",
    decode: decodeInt,
    encode: encodeInt
  ),
  vkFloat: ValueDef(
    typeHint: "float",
    decode: decodeFloat,
    encode: encodeFloat
  ),
  vkBool: ValueDef(
    typeHint: "bool",
    decode: decodeBool,
    encode: encodeBool
  ),
  vkList: ValueDef(
    typeHint: "list",
    decode: decodeList,
    encode: encodeList
  ),
  vkTuple: ValueDef(
    typeHint: "tuple",
    decode: decodeTuple,
    encode: encodeTuple
  ),
  vkEnv: ValueDef(
    typeHint: "env",
    decode: decodeEnv,
    encode: encodeEnv
  ),
]

func tryDecode*(raw: string, vk: ValueKind, line = 0, col = 0): Option[Value] =
  try: some(VALUES_DEF[vk].decode(raw, line, col))
  except: none(Value)

func classifyLiteral*(raw: string): Value =
  for vk in [vkBool, vkInt, vkFloat, vkString]:
    let response = tryDecode(raw, vk)
    if response.isSome: return response.get
  couldNotDecodeLiteralError(raw)
