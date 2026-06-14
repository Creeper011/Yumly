import std/[options, unittest]

import ../src/Yumly/utils/suggestions

suite "suggestClosest":
  test "returns the nearest candidate":
    check suggestClosest("strng", ["string", "int"]).get() == "string"

  test "matches without case sensitivity":
    check suggestClosest("INCLUD", ["include"]).get() == "include"

  test "respects an explicit distance":
    check suggestClosest("abc", ["abcdef"], 2).isNone

  test "does not suggest exact or empty values":
    check suggestClosest("string", ["string"]).isNone
    check suggestClosest("", ["string"]).isNone
