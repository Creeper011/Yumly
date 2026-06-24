import std/unittest

import ../../../src/Yumly/types/[ast, type_hints, values_defs]

suite "value type inference":
  test "infers primitive types":
    let value = Value(kind: vkInt, intVal: 42)
    check inferTypeString(value) == "int"
    check inferTypeKind(value) == thInt

  test "infers list element types":
    let value = Value(kind: vkList, elements: @[
      Value(kind: vkString, strVal: "first"),
      Value(kind: vkString, strVal: "second")
    ])
    let hint = inferTypeHintObject(value)

    check inferTypeString(value) == "list[string]"
    check hint.kind == thList
    check hint.elementKind == thString
    check hint.elementRaw == "string"

  test "uses a string element hint for empty lists":
    let value = Value(kind: vkList, elements: @[])
    let hint = inferTypeHintObject(value)

    check hint.raw == "list"
    check hint.elementKind == thString
    check hint.elementRaw == ""
