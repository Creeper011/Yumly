import std/[streams, unittest]

import ../../../src/Yumly/phases/tokenizer/cursor

suite "tokenizer cursor":
  test "peeks across tiny buffer boundaries without consuming input":
    var cursor = initCursor(newStringStream("yumly"), bufferSize = 1)

    check cursor.peekChar(0) == 'y'
    check cursor.peekChar(4) == 'y'
    check cursor.absPos() == 0
    check cursor.advanceChar() == 'y'
    check cursor.absPos() == 1

  test "matches strings that span multiple refills":
    var cursor = initCursor(newStringStream(";>comment"), bufferSize = 1)

    check cursor.matchStr(";>")
    check cursor.absPos() == 2
    check cursor.peekChar() == 'c'

  test "does not consume a failed match":
    var cursor = initCursor(newStringStream("include"), bufferSize = 2)

    check not cursor.matchStr("inside")
    check cursor.absPos() == 0
    check cursor.peekChar() == 'i'

  test "tracks line starts while advancing":
    var cursor = initCursor(newStringStream("a\nbc"), bufferSize = 2)

    check cursor.advanceChar() == 'a'
    check cursor.advanceChar() == '\n'
    check cursor.line == 2
    check cursor.lineStart == 2
    check cursor.absPos() == 2
    check cursor.advanceChar() == 'b'
    check cursor.absPos() - cursor.lineStart + 1 == 2
