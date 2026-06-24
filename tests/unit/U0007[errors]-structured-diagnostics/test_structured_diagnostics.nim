import std/unittest

import ../../../src/Yumly/types/errors

suite "structured diagnostics":
  test "derives a one-column range from a source position":
    let error = newYumlyError(
      "invalid value", 3, 7, "validator.invalid-value")

    check error.msg == "invalid value"
    check error.line == 3
    check error.col == 7
    check error.endLine == 3
    check error.endCol == 8
    check error.code == "validator.invalid-value"

  test "preserves an explicit multiline range":
    let error = newYumlyError(
      "unclosed string", 2, 4, 5, 9, "tokenizer.unclosed-string")

    check error.line == 2
    check error.col == 4
    check error.endLine == 5
    check error.endCol == 9
    check error.code == "tokenizer.unclosed-string"

  test "can be handled as a value error":
    let error: ref ValueError =
      newYumlyError("bad input", 1, 1, "parser.expected")

    check error.msg == "bad input"

  test "structured IO diagnostics remain IO errors":
    let error: ref IOError =
      newYumlyIOError("missing include", 2, 3, "include.not-found")

    check error.msg == "missing include"
