import std/unittest

import ../../../src/Yumly/types/[ast, values_defs]

suite "value decoders":
  test "decodes escaped strings":
    let value = decodeString("line 1\\nline 2\\t\\\"ok\\\"", 1, 1)
    check value.kind == vkString
    check value.strVal == "line 1\nline 2\t\"ok\""

  test "decodes primitive values":
    check decodeInt("42", 1, 1).intVal == 42
    check decodeFloat("2.5", 1, 1).floatVal == 2.5
    check decodeBool("false", 1, 1).boolVal == false

  test "decodes environment references":
    let value = decodeEnv("HOME", 1, 1)
    check value.kind == vkEnv
    check value.envName == "HOME"
    check value.envVal == ""

  test "rejects invalid booleans":
    expect ValueError:
      discard decodeBool("yes", 1, 1)
