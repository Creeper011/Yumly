import std/options
import ../../src/Yumly/types/values_defs
import ../../src/Yumly/types/ast
import ../../src/Yumly/error_messages

proc testDecodeString() =
  let val = decodeString("hello world", 1, 1)
  assert val.kind == vkString
  assert val.strVal == "hello world"
  echo "testDecodeString: PASSED"

proc testDecodeStringWithEscapes() =
  let val = decodeString("hello\\nworld\\ttab", 1, 1)
  assert val.strVal == "hello\nworld\ttab"
  echo "testDecodeStringWithEscapes: PASSED"

proc testDecodeStringWithQuotes() =
  let val = decodeString("he said \\\"hello\\\"", 1, 1)
  assert val.strVal == "he said \"hello\""
  echo "testDecodeStringWithQuotes: PASSED"

proc testDecodeInt() =
  let val = decodeInt("42", 1, 1)
  assert val.kind == vkInt
  assert val.intVal == 42
  echo "testDecodeInt: PASSED"

proc testDecodeIntNegative() =
  let val = decodeInt("-42", 1, 1)
  assert val.intVal == -42
  echo "testDecodeIntNegative: PASSED"

proc testDecodeIntPositive() =
  let val = decodeInt("+42", 1, 1)
  assert val.intVal == 42
  echo "testDecodeIntPositive: PASSED"

proc testDecodeFloat() =
  let val = decodeFloat("3.14159", 1, 1)
  assert val.kind == vkFloat
  assert val.floatVal == 3.14159
  echo "testDecodeFloat: PASSED"

proc testDecodeFloatNegative() =
  let val = decodeFloat("-1.5", 1, 1)
  assert val.floatVal == -1.5
  echo "testDecodeFloatNegative: PASSED"

proc testDecodeFloatScientific() =
  let val = decodeFloat("1.5e+10", 1, 1)
  assert val.floatVal == 1.5e+10
  echo "testDecodeFloatScientific: PASSED"

proc testDecodeBoolTrue() =
  let val = decodeBool("true", 1, 1)
  assert val.kind == vkBool
  assert val.boolVal == true
  echo "testDecodeBoolTrue: PASSED"

proc testDecodeBoolFalse() =
  let val = decodeBool("false", 1, 1)
  assert val.boolVal == false
  echo "testDecodeBoolFalse: PASSED"

proc testDecodeEnv() =
  let val = decodeEnv("MY_VAR", 1, 1)
  assert val.kind == vkEnv
  assert val.envName == "MY_VAR"
  echo "testDecodeEnv: PASSED"

proc testEncodeString() =
  let val = Value(kind: vkString, strVal: "hello world")
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "\"hello world\""
  echo "testEncodeString: PASSED"

proc testEncodeStringWithEscapes() =
  let val = Value(kind: vkString, strVal: "hello\nworld")
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "\"hello\\nworld\""
  echo "testEncodeStringWithEscapes: PASSED"

proc testEncodeInt() =
  let val = Value(kind: vkInt, intVal: 42)
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "42"
  echo "testEncodeInt: PASSED"

proc testEncodeFloat() =
  let val = Value(kind: vkFloat, floatVal: 3.14)
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "3.14"
  echo "testEncodeFloat: PASSED"

proc testEncodeBoolTrue() =
  let val = Value(kind: vkBool, boolVal: true)
  assert encodeValue(val, styleYumly) == "true"
  echo "testEncodeBoolTrue: PASSED"

proc testEncodeBoolFalse() =
  let val = Value(kind: vkBool, boolVal: false)
  assert encodeValue(val, styleYumly) == "false"
  echo "testEncodeBoolFalse: PASSED"

proc testEncodeEnv() =
  let val = Value(kind: vkEnv, envName: "DB_PASS", envVal: "secret")
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "$[\"DB_PASS\"]"
  echo "testEncodeEnv: PASSED"

proc testEncodeList() =
  let val = Value(
    kind: vkList,
    elements: @[
      Value(kind: vkString, strVal: "a"),
      Value(kind: vkString, strVal: "b")
    ]
  )
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "[\"a\", \"b\"]"
  echo "testEncodeList: PASSED"

proc testEncodeListInts() =
  let val = Value(
    kind: vkList,
    elements: @[
      Value(kind: vkInt, intVal: 1),
      Value(kind: vkInt, intVal: 2)
    ]
  )
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "[1, 2]"
  echo "testEncodeListInts: PASSED"

proc testEncodeTuple() =
  let val = Value(
    kind: vkTuple,
    elements: @[
      Value(kind: vkInt, intVal: 1),
      Value(kind: vkInt, intVal: 2)
    ]
  )
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "[1, 2]"
  echo "testEncodeTuple: PASSED"

proc testEncodeTupleYumyumyStyle() =
  let val = Value(
    kind: vkTuple,
    elements: @[
      Value(kind: vkString, strVal: "a"),
      Value(kind: vkString, strVal: "b")
    ]
  )
  let encoded = encodeValue(val, styleYumyumy)
  assert encoded == "(a, b)"
  echo "testEncodeTupleYumyumyStyle: PASSED"

proc testEncodeListEmpty() =
  let val = Value(kind: vkList, elements: @[])
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "[]"
  echo "testEncodeListEmpty: PASSED"

proc testEncodeListMixed() =
  let val = Value(
    kind: vkList,
    elements: @[
      Value(kind: vkString, strVal: "test"),
      Value(kind: vkInt, intVal: 42)
    ]
  )
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "[\"test\", 42]"
  echo "testEncodeListMixed: PASSED"

proc testEncodeZero() =
  let val = Value(kind: vkInt, intVal: 0)
  assert encodeValue(val, styleYumly) == "0"
  echo "testEncodeZero: PASSED"

proc testEncodeNegativeFloat() =
  let val = Value(kind: vkFloat, floatVal: -1.5)
  assert encodeValue(val, styleYumly) == "-1.5"
  echo "testEncodeNegativeFloat: PASSED"

proc testClassifyLiteralInt() =
  let val = classifyLiteral("42")
  assert val.kind == vkInt
  assert val.intVal == 42
  echo "testClassifyLiteralInt: PASSED"

proc testClassifyLiteralFloat() =
  let val = classifyLiteral("3.14")
  assert val.kind == vkFloat
  echo "testClassifyLiteralFloat: PASSED"

proc testClassifyLiteralBool() =
  let val = classifyLiteral("true")
  assert val.kind == vkBool
  assert val.boolVal == true
  echo "testClassifyLiteralBool: PASSED"

proc testClassifyLiteralString() =
  let val = classifyLiteral("hello")
  assert val.kind == vkString
  echo "testClassifyLiteralString: PASSED"

proc testTryDecodeString() =
  let result = tryDecode("test", vkString, 1, 1)
  assert result.isSome()
  assert result.get().strVal == "test"
  echo "testTryDecodeString: PASSED"

proc testTryDecodeInvalid() =
  let result = tryDecode("invalid", vkBool, 1, 1)
  assert result.isNone()
  echo "testTryDecodeInvalid: PASSED"

proc testDecodeBackslash() =
  let val = decodeString("path\\\\to\\\\file", 1, 1)
  assert val.strVal == "path\\to\\file"
  echo "testDecodeBackslash: PASSED"

proc testDecodeSingleQuote() =
  let val = decodeString("quote\\'test", 1, 1)
  assert val.strVal == "quote'test"
  echo "testDecodeSingleQuote: PASSED"

proc testEncodeIntNegative() =
  let val = Value(kind: vkInt, intVal: -42)
  assert encodeValue(val, styleYumly) == "-42"
  echo "testEncodeIntNegative: PASSED"

proc testEncodeStringEmpty() =
  let val = Value(kind: vkString, strVal: "")
  assert encodeValue(val, styleYumly) == "\"\""
  echo "testEncodeStringEmpty: PASSED"

proc testEncodeStringDoubleQuote() =
  let val = Value(kind: vkString, strVal: "say \"hi\"")
  let encoded = encodeValue(val, styleYumly)
  assert encoded == "\"say \\\"hi\\\"\""
  echo "testEncodeStringDoubleQuote: PASSED"

proc runValuesTests() =
  echo "=== RUNNING VALUES TESTS ==="
  testDecodeString()
  testDecodeStringWithEscapes()
  testDecodeStringWithQuotes()
  testDecodeInt()
  testDecodeIntNegative()
  testDecodeIntPositive()
  testDecodeFloat()
  testDecodeFloatNegative()
  testDecodeFloatScientific()
  testDecodeBoolTrue()
  testDecodeBoolFalse()
  testDecodeEnv()
  testEncodeString()
  testEncodeStringWithEscapes()
  testEncodeInt()
  testEncodeFloat()
  testEncodeBoolTrue()
  testEncodeBoolFalse()
  testEncodeEnv()
  testEncodeList()
  testEncodeListInts()
  testEncodeTuple()
  testEncodeTupleYumyumyStyle()
  testEncodeListEmpty()
  testEncodeListMixed()
  testEncodeZero()
  testEncodeNegativeFloat()
  testClassifyLiteralInt()
  testClassifyLiteralFloat()
  testClassifyLiteralBool()
  testClassifyLiteralString()
  testTryDecodeString()
  testTryDecodeInvalid()
  testDecodeBackslash()
  testDecodeSingleQuote()
  testEncodeIntNegative()
  testEncodeStringEmpty()
  testEncodeStringDoubleQuote()
  echo "=== ALL VALUES TESTS PASSED ===\nTotal: 42 tests"

runValuesTests()