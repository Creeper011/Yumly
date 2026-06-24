import std/unittest

import ../../../src/Yumly/types/[ast, values_defs]

suite "encodeValue":
  test "encodes strings with Yumly escaping":
    let value = Value(kind: vkString, strVal: "line 1\n\"line 2\"")
    check encodeValue(value) == "\"line 1\\n\\\"line 2\\\"\""

  test "encodes primitive values":
    check encodeValue(Value(kind: vkInt, intVal: 42)) == "42"
    check encodeValue(Value(kind: vkFloat, floatVal: 2.5)) == "2.5"
    check encodeValue(Value(kind: vkBool, boolVal: true)) == "true"

  test "encodes lists recursively":
    let value = Value(kind: vkList, elements: @[
      Value(kind: vkInt, intVal: 1),
      Value(kind: vkString, strVal: "two")
    ])
    check encodeValue(value) == "[1, \"two\"]"

  test "uses resolved environment values in yumyumy":
    let value = Value(kind: vkEnv, envName: "HOME", envVal: "/tmp/home",
        envFound: true)
    check encodeValue(value, styleYumly) == "$[\"HOME\"]"
    check encodeValue(value, styleYumyumy) == "\"/tmp/home\""
