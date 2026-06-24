import std/[streams, unittest]

import ../../../src/Yumly/phases/tokenizer/tokenizer
import ../../../src/Yumly/types/[errors, token]

suite "tokenizer source ranges":
  test "records exclusive ranges for tokens across lines":
    let pull = tokenize(
      newStringStream("name = \"Yumly\"\ncount = -12.5e+2"),
      bufferSize = 2)

    let name = pull()
    check name.kind == tkIdent
    check name.value == "name"
    check (name.line, name.col, name.endLine, name.endCol) == (1, 1, 1, 5)

    let equals = pull()
    check equals.kind == tkEquals
    check (equals.line, equals.col, equals.endLine, equals.endCol) ==
      (1, 6, 1, 7)

    let value = pull()
    check value.kind == tkString
    check value.value == "Yumly"
    check (value.line, value.col, value.endLine, value.endCol) ==
      (1, 8, 1, 15)

    let count = pull()
    check count.kind == tkIdent
    check count.value == "count"
    check (count.line, count.col, count.endLine, count.endCol) ==
      (2, 1, 2, 6)

    discard pull()
    let number = pull()
    check number.kind == tkLiteral
    check number.value == "-12.5e+2"
    check (number.line, number.col, number.endLine, number.endCol) ==
      (2, 9, 2, 17)

  test "records multiline string and eof ranges":
    let pull = tokenize(newStringStream("\"\"\"a\nb\"\"\""), bufferSize = 1)

    let value = pull()
    check value.kind == tkString
    check value.value == "a\nb"
    check (value.line, value.col, value.endLine, value.endCol) ==
      (1, 1, 2, 5)

    let eof = pull()
    check eof.kind == tkEOF
    check (eof.line, eof.col, eof.endLine, eof.endCol) == (2, 5, 2, 5)

  test "attaches the consumed range to tokenizer errors":
    let pull = tokenize(newStringStream("1e"), bufferSize = 1)

    try:
      discard pull()
      check false
    except YumlyError as error:
      check error.code == "tokenizer.invalid-exponent"
      check (error.line, error.col, error.endLine, error.endCol) ==
        (1, 1, 1, 3)
