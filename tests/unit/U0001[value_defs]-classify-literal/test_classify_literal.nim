import std/unittest

import ../../../src/Yumly/types/[ast, values_defs]

suite "classifyLiteral":
  test "classifies booleans before other literals":
    let value = classifyLiteral("true")
    check value.kind == vkBool
    check value.boolVal

  test "classifies integers":
    let value = classifyLiteral("-42")
    check value.kind == vkInt
    check value.intVal == -42

  test "classifies floats":
    let value = classifyLiteral("3.5")
    check value.kind == vkFloat
    check value.floatVal == 3.5

  test "falls back to strings":
    let value = classifyLiteral("yumly")
    check value.kind == vkString
    check value.strVal == "yumly"
