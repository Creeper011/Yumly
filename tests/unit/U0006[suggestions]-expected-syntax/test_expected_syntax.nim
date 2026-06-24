import std/[options, unittest]

import ../../../src/yumly/types/[errors, token]
import ../../../src/yumly/utils/suggestions

suite "suggestExpected":
  test "suggests missing delimiters":
    let eofToken = Token(
      kind: tkEOF, line: 1, col: 12, endLine: 1, endCol: 12)

    check suggestExpected(expEquals, eofToken).get() ==
      "place '=' between the key and its value"
    check suggestExpected(expRBrace, eofToken).get() ==
      "close the block with '}' before the end of the file"
    check suggestExpected(expComma, eofToken).get() ==
      "separate list items with ','"
    check suggestExpected(expBlockComma, eofToken).get() ==
      "separate pairs and nested blocks with ','"

  test "recognizes a misspelled include":
    let braceToken = Token(
      kind: tkLBrace, line: 1, col: 8, endLine: 1, endCol: 9)
    let previousToken = Token(
      kind: tkIdent, line: 1, col: 1, endLine: 1, endCol: 7,
      value: "includ")

    check suggestExpected(
      expEquals, braceToken, some(previousToken)).get() ==
      "did you mean 'include'?"

  test "recognizes type hints missing the declaration marker":
    let keyToken = Token(
      kind: tkIdent, line: 1, col: 1, endLine: 1, endCol: 9,
      value: "fullName")
    let hintToken = Token(
      kind: tkIdent, line: 1, col: 10, endLine: 1, endCol: 16,
      value: "string")

    check suggestExpected(expEquals, hintToken, some(keyToken)).get() ==
      "type hints start with ';': write 'fullName ;string = ...'"

  test "suggests corrected type hints missing the declaration marker":
    let keyToken = Token(
      kind: tkIdent, line: 1, col: 1, endLine: 1, endCol: 5,
      value: "name")
    let typoHintToken = Token(
      kind: tkIdent, line: 1, col: 6, endLine: 1, endCol: 11,
      value: "strng")

    check suggestExpected(expEquals, typoHintToken, some(keyToken)).get() ==
      "type hints start with ';': write 'name ;string = ...'"

  test "recognizes type hints missing the type name":
    let declarationToken = Token(
      kind: tkDeclaration, line: 1, col: 10, endLine: 1, endCol: 11)
    let equalsToken = Token(
      kind: tkEquals, line: 1, col: 12, endLine: 1, endCol: 13)

    check suggestExpected(expIdentifier, equalsToken, some(declarationToken)).get() ==
      "type hints need a name after ';': use ;string, ;int, ;float, ;bool, ;env, or ;list"

  test "suggests known type hints":
    check suggestTypeHint("lsit").get() == "list"
    check suggestTypeHint("unknown").isNone
