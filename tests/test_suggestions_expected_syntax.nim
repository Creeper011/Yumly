import std/[options, unittest]

import ../src/Yumly/types/[errors, token]
import ../src/Yumly/utils/suggestions

suite "suggestExpected":
  test "suggests missing delimiters":
    let eofToken = Token(
      kind: tkEOF, line: 1, col: 12, endLine: 1, endCol: 12)

    check suggestExpected(expEquals, eofToken).get() ==
      "place '=' between the key and its value"
    check suggestExpected(expRBrace, eofToken).get() ==
      "close the block with '}' before the end of the file"

  test "recognizes a misspelled include":
    let braceToken = Token(
      kind: tkLBrace, line: 1, col: 8, endLine: 1, endCol: 9)
    let previousToken = Token(
      kind: tkIdent, line: 1, col: 1, endLine: 1, endCol: 7,
      value: "includ")

    check suggestExpected(
      expEquals, braceToken, some(previousToken)).get() ==
      "did you mean 'include'?"

  test "suggests known type hints":
    check suggestTypeHint("lsit").get() == "list"
    check suggestTypeHint("unknown").isNone
