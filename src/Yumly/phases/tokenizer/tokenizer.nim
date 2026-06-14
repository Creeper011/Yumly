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

func endCol(cursor: Cursor): int =
  cursor.absPos() - cursor.lineStart + 1

func token(cursor: Cursor, kind: TokenKind, line, col: int): Token =
  case kind
  of tkString, tkIdent, tkLiteral:
    Token(kind: kind, line: line, col: col, endLine: cursor.line,
        endCol: cursor.endCol(), value: "")
  else:
    Token(kind: kind, line: line, col: col, endLine: cursor.line,
        endCol: cursor.endCol())

func valueToken(cursor: Cursor, kind: TokenKind, line, col: int, value: string): Token =
  case kind
  of tkString, tkIdent, tkLiteral:
    Token(kind: kind, line: line, col: col, endLine: cursor.line,
        endCol: cursor.endCol(), value: value)
  else:
    Token(kind: kind, line: line, col: col, endLine: cursor.line,
        endCol: cursor.endCol())

proc tokenize*(stream: Stream, bufferSize: int = 4096): proc(): Token {.closure.} =
  var cursor = initCursor(stream, bufferSize)

  return proc(): Token {.closure.} =
    while true:
      let ch = cursor.peekChar()
      if ch == '\0':
        return cursor.token(tkEOF, cursor.line, cursor.endCol())

      if ch in {' ', '\t', '\r', '\n'}:
        discard cursor.advanceChar()
        continue

      let startPos = cursor.absPos()
      let line = cursor.line
      let col = startPos - cursor.lineStart + 1

      # Comments: ;> ... <;
      if cursor.matchStr(";>"):
        while true:
          if cursor.peekChar() == '\0':
            commentNotClosedError(line, col, cursor.line, cursor.endCol())
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
          if cursor.peekChar() notin {'0'..'9'}:
            invalidExponentError(line, col, cursor.line, cursor.endCol())
          while cursor.peekChar() in {'0'..'9'}: value.add(cursor.advanceChar())

        return cursor.valueToken(tkLiteral, line, col, value)

      case ch
      of '(': discard cursor.advanceChar(); return cursor.token(tkLParen, line, col)
      of ')': discard cursor.advanceChar(); return cursor.token(tkRParen, line, col)
      of '{': discard cursor.advanceChar(); return cursor.token(tkLBrace, line, col)
      of '}': discard cursor.advanceChar(); return cursor.token(tkRBrace, line, col)
      of '[': discard cursor.advanceChar(); return cursor.token(tkLBracket, line, col)
      of ']': discard cursor.advanceChar(); return cursor.token(tkRBracket, line, col)
      of '=': discard cursor.advanceChar(); return cursor.token(tkEquals, line, col)
      of ';': discard cursor.advanceChar(); return cursor.token(tkDeclaration, line, col)
      of ',': discard cursor.advanceChar(); return cursor.token(tkComma, line, col)
      of '$': discard cursor.advanceChar(); return cursor.token(tkDollar, line, col)

      of '"', '\'':
        let quoteChar = cursor.peekChar()
        var stringContent = ""

        # Multiline String: """
        if quoteChar == '"' and cursor.matchStr("\"\"\""):
          while true:
            let nextCh = cursor.peekChar()
            if nextCh == '\0':
              unclosedStringAtEofError(line, col, cursor.line, cursor.endCol())

            # Escaped triple quote
            if cursor.matchStr("\\\"\"\""):
              stringContent.add("\"\"\"")
              continue

            # End of multiline
            if cursor.matchStr("\"\"\""): break

            stringContent.add(cursor.advanceChar())

          return cursor.valueToken(tkString, line, col, stringContent)

        # Single-line String
        else:
          discard cursor.advanceChar() # skip opening quote
          while true:
            let nextCh = cursor.peekChar()
            if nextCh == '\0':
              unclosedStringAtEofError(line, col, cursor.line, cursor.endCol())
            if nextCh == quoteChar: discard cursor.advanceChar(); break
            if nextCh == '\n':
              unclosedStringError(line, col, cursor.line, cursor.endCol())

            if nextCh == '\\':
              stringContent.add(cursor.advanceChar()) # \
              stringContent.add(cursor.advanceChar()) # char
            else:
              stringContent.add(cursor.advanceChar())

          return cursor.valueToken(tkString, line, col, stringContent)

      else:
        if ch in IdentStartChars:
          var word = ""
          while isIdentContinue(cursor.peekChar()): word.add(cursor.advanceChar())

          if word == "true" or word == "false":
            return cursor.valueToken(tkLiteral, line, col, word)

          return cursor.valueToken(tkIdent, line, col, word)

        discard cursor.advanceChar()
        unexpectedCharError($ch, line, col, cursor.line, cursor.endCol())
