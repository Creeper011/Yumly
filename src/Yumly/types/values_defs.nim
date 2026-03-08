##
# This module defines the base types and definitions for Yumly values,
# including their decoding and encoding logic with support for different styles.
##

import ../types/ast
import strutils, sequtils

type 
  EncodingStyle* = enum
    styleYumly,
    styleYumyumy # yumyumy is a representative format

  ValueDef* = object
    typeHint*: string
    decode*: proc (raw: string): Value
    encode*: proc (val: Value, style: EncodingStyle): string

proc decodeString(raw: string): Value = 
  Value(kind: vkString, strVal: raw)
proc decodeInt(raw: string): Value = 
  Value(kind: vkInt, intVal: parseInt(raw))
proc decodeFloat(raw: string): Value = 
  Value(kind: vkFloat, floatVal: parseFloat(raw))
proc decodeBool(raw: string): Value = 
  if raw == "true":
    Value(kind: vkBool, boolVal: true)
  elif raw == "false":
    Value(kind: vkBool, boolVal: false)
  else:
    raise newException(ValueError, "Invalid boolean: " & raw)
proc decodeEnv(raw: string): Value =
  # value def doesn't do env val resolution (IO)
  Value(kind: vkEnv, envName: raw, envVal: "")
proc decodeList(raw: string): Value = 
  Value(kind: vkList, elements: @[])
proc decodeTuple(raw: string): Value = 
  Value(kind: vkTuple, elements: @[])

proc encodeValue*(val: Value, style: EncodingStyle = styleYumly): string # forward

proc encodeString(val: Value, style: EncodingStyle): string = 
  "\"" & val.strVal & "\""
proc encodeInt(val: Value, style: EncodingStyle): string = 
  $val.intVal
proc encodeFloat(val: Value, style: EncodingStyle): string = 
  $val.floatVal
proc encodeBool(val: Value, style: EncodingStyle): string = 
  if val.boolVal: "true" else: "false"

proc encodeEnv(val: Value, style: EncodingStyle): string = 
  case style
  of styleYumly: "$[\"" & val.envName & "\"]"
  #  Yumyumy uses the resolved value in quotes because is a representative format
  of styleYumyumy: "\"" & val.envVal & "\""

proc encodeList(val: Value, style: EncodingStyle): string =
  let elements = val.elements.mapIt(encodeValue(it, style)).join(", ")
  "[" & elements & "]"

proc encodeTuple(val: Value, style: EncodingStyle): string =
  let elements = val.elements.mapIt(encodeValue(it, style)).join(", ")
  case style
  of styleYumly: "[" & elements & "]"
  of styleYumyumy: "(" & elements & ")"

proc encodeValue*(val: Value, style: EncodingStyle = styleYumly): string =
  case val.kind
  of vkString: encodeString(val, style)
  of vkInt:    encodeInt(val, style)
  of vkFloat:  encodeFloat(val, style)
  of vkBool:   encodeBool(val, style)
  of vkEnv:    encodeEnv(val, style)
  of vkList:   encodeList(val, style)
  of vkTuple:  encodeTuple(val, style)

let VALUES_DEF*: array[ValueKind, ValueDef] = [
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
