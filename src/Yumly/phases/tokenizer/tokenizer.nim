##
#  This module defines the tokenizer for the Yumly configuration language.
#  It converts a Stream into tokens on-demand using a closure iterator.
##

import std/strutils, streams
import ../../types/token
import ../../error_messages
import cursor

func isIdentContinue(character: char): bool =
  character in IdentChars or character in {'/', '.', '-'}

proc tokenize*(stream: Stream, bufferSize: int = 4096): proc(): Token {.closure.} =
  var cursor = initCursor(stream, bufferSize)

  return proc(): Token {.closure.} =
    while true:
      let ch = cursor.peekChar()
      if ch == '\0':
        return Token(kind: tkEOF, line: cursor.line, col: cursor.absPos() - cursor.lineStart + 1)

      if ch in {' ', '\t', '\r', '\n'}:
        discard cursor.advanceChar()
        continue

      let startPos = cursor.absPos()
      let line = cursor.line
      let col = startPos - cursor.lineStart + 1

      # Comments: ;> ... <;
      if cursor.matchStr(";>"):
        while true:
          if cursor.peekChar() == '\0': commentNotClosedError(line, col)
          if cursor.matchStr("<;"): break
          discard cursor.advanceChar()
        continue

      # Numbers (with Exponent support)
      if ch in {'0'..'9'} or (ch in {'+', '-'} and cursor.peekChar(1) in {'0'..'9'}):
        var value = ""
        value.add(cursor.advanceChar())
        while cursor.peekChar() in {'0'..'9'}: value.add(cursor.advanceChar())

        if cursor.peekChar() == '.':
          value.add(cursor.advanceChar())
          while cursor.peekChar() in {'0'..'9'}: value.add(cursor.advanceChar())

        if cursor.peekChar() in {'e', 'E'}:
          value.add(cursor.advanceChar())
          if cursor.peekChar() in {'+', '-'}: value.add(cursor.advanceChar())
          if cursor.peekChar() notin {'0'..'9'}: invalidExponentError(line, col)
          while cursor.peekChar() in {'0'..'9'}: value.add(cursor.advanceChar())

        return Token(kind: tkLiteral, line: line, col: col, value: value)

      case ch
      of '(': discard cursor.advanceChar(); return Token(kind: tkLParen, line: line, col: col)
      of ')': discard cursor.advanceChar(); return Token(kind: tkRParen, line: line, col: col)
      of '{': discard cursor.advanceChar(); return Token(kind: tkLBrace, line: line, col: col)
      of '}': discard cursor.advanceChar(); return Token(kind: tkRBrace, line: line, col: col)
      of '[': discard cursor.advanceChar(); return Token(kind: tkLBracket, line: line, col: col)
      of ']': discard cursor.advanceChar(); return Token(kind: tkRBracket, line: line, col: col)
      of '=': discard cursor.advanceChar(); return Token(kind: tkEquals, line: line, col: col)
      of ';': discard cursor.advanceChar(); return Token(kind: tkDeclaration, line: line, col: col)
      of ',': discard cursor.advanceChar(); return Token(kind: tkComma, line: line, col: col)
      of '$': discard cursor.advanceChar(); return Token(kind: tkDollar, line: line, col: col)

      of '"', '\'':
        let quoteChar = cursor.peekChar()
        var stringContent = ""

        # Multiline String: """
        if quoteChar == '"' and cursor.matchStr("\"\"\""):
          while true:
            let nextCh = cursor.peekChar()
            if nextCh == '\0': unclosedStringAtEofError()

            # Escaped triple quote
            if cursor.matchStr("\\\"\"\""):
              stringContent.add("\"\"\"")
              continue

            # End of multiline
            if cursor.matchStr("\"\"\""): break

            stringContent.add(cursor.advanceChar())

          return Token(kind: tkString, line: line, col: col, value: stringContent)

        # Single-line String
        else:
          discard cursor.advanceChar() # skip opening quote
          while true:
            let nextCh = cursor.peekChar()
            if nextCh == '\0': unclosedStringAtEofError()
            if nextCh == quoteChar: discard cursor.advanceChar(); break
            if nextCh == '\n': unclosedStringError(line, col)

            if nextCh == '\\':
              stringContent.add(cursor.advanceChar()) # \
              stringContent.add(cursor.advanceChar()) # char
            else:
              stringContent.add(cursor.advanceChar())

          return Token(kind: tkString, line: line, col: col, value: stringContent)

      else:
        if ch in IdentStartChars:
          var word = ""
          while isIdentContinue(cursor.peekChar()): word.add(cursor.advanceChar())

          if word == "true" or word == "false":
            return Token(kind: tkLiteral, line: line, col: col, value: word)

          return Token(kind: tkIdent, line: line, col: col, value: word)

        unexpectedCharError($ch, line, col)
        discard cursor.advanceChar()
