##
#  This module defines the tokenizer for the Yumly configuration language.
#  It converts a Stream into tokens on-demand using a closure iterator.
##

import std/strutils, streams
import ../types/token
import ../error_messages

type Cursor = object
  stream: Stream
  buf: string
  pos: int
  len: int
  basePos: int
  eof: bool
  line: int
  lineStart: int

proc initCursor(stream: Stream, bufferSize: int = 4096): Cursor =
  result.stream = stream
  result.buf = newString(max(1, bufferSize))
  result.pos = 0
  result.len = 0
  result.basePos = 0
  result.eof = false
  result.line = 1
  result.lineStart = 0

proc absPos(cursor: Cursor): int =
  cursor.basePos + cursor.pos

proc refill(cursor: var Cursor) =

  # skips refill if the buffer next token is an eof
  if cursor.eof: return

  let remaining = cursor.len - cursor.pos

  # if theres something in buffer
  if remaining > 0:
    if remaining == cursor.buf.len:
      let newSize = max(1, cursor.buf.len * 2)
      var grown = newString(newSize)
      for i in 0..<remaining: grown[i] = cursor.buf[cursor.pos + i]
      cursor.buf = grown
    else:
      #
      for i in 0..<remaining: cursor.buf[i] = cursor.buf[cursor.pos + i]

  cursor.basePos += cursor.pos
  cursor.pos = 0
  cursor.len = remaining
  let free = cursor.buf.len - cursor.len
  if free <= 0:
    cursor.eof = true
    return
  let n = cursor.stream.readData(addr cursor.buf[cursor.len], free)
  if n <= 0: cursor.eof = true
  else: cursor.len += n

proc peekChar(cursor: var Cursor, offset: int = 0): char =
  var idx = cursor.pos + offset
  while idx >= cursor.len and not cursor.eof:
    cursor.refill()
    idx = cursor.pos + offset
  if idx < cursor.len: result = cursor.buf[idx]
  else: result = '\0'

proc advanceChar(cursor: var Cursor): char =
  result = cursor.peekChar()
  if result == '\0': return
  inc cursor.pos
  if result == '\n':
    inc cursor.line
    cursor.lineStart = cursor.basePos + cursor.pos

proc matchStr(cursor: var Cursor, s: string): bool =
  for i, character in s:
    if cursor.peekChar(i) != character: return false
  for _ in 0..<s.len: discard cursor.advanceChar()
  return true

proc isIdentContinue(character: char): bool =
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
