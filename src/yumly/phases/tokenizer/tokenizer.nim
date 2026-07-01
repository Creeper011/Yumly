## Yumly Tokenizer.
## This module defines the tokenizer for the Yumly configuration language.
##
## It converts a Stream into tokens on-demand using a closure iterator.
##
## The tokenizer reads through a Cursor, which keeps a refillable slice of the
## stream in memory and tracks the absolute source position.
##
## For long token spans such as identifiers, digits, and string contents,
## it scans the current cursor buffer first and copies the contiguous range
## directly into the token value before moving the cursor position forward.
##
## When a span crosses the buffer boundary, the cursor refills and scanning
## continues from the next buffered slice.
##

import std/strutils, streams
import ../../errors/exceptions/parser/tokenizererrors
import ../../types/[source, token]
import cursor, helpers

func isIdent(character: char): bool {.inline.} =
  ## Checks if a character can continue an identifier.
  character in IdentChars or character in {'/', '.', '-'}

proc addBufferedSlice(cursor: var Cursor, value: var string, first,
    afterLast: int) {.inline.} =
  ## Copies a contiguous buffered span into a token value.
  ##
  ## This is the fast path for tokens that do not need character-by-character
  ## transformation. It copies directly from `cursor.buf` into the destination
  ## string and then moves `cursor.pos` to the first unconsumed character.
  if afterLast <= first:
    return

  let oldLen = value.len
  let sliceLen = afterLast - first
  value.setLen(oldLen + sliceLen)
  copyMem(addr value[oldLen], addr cursor.buf[first], sliceLen)
  cursor.pos = afterLast

proc addBufferedSliceWithLines(cursor: var Cursor, value: var string, first,
    afterLast: int) {.inline.} =
  ## Copies a buffered span and updates source-line tracking.
  ##
  ## Multiline strings can consume newlines inside a single fast-path span.
  ## `advanceChar()` normally updates `cursor.line` and `cursor.lineStart`;
  ## this helper mirrors that bookkeeping while still avoiding per-character
  ## string growth.
  if afterLast <= first:
    return

  let oldLen = value.len
  value.setLen(oldLen + afterLast - first)
  for i in first..<afterLast:
    value[oldLen + i - first] = cursor.buf[i]
    if cursor.buf[i] == '\n':
      inc cursor.line
      cursor.lineStart = cursor.basePos + i + 1
  cursor.pos = afterLast

proc takeDigits(cursor: var Cursor, value: var string) =
  ## Consumes one or more buffered digit runs into `value`.
  ##
  ## The cursor may reach the end of the current buffer before the number ends.
  ## Calling `peekChar()` at the start of each pass refills when necessary, so
  ## numbers remain correct across buffer boundaries.
  while true:
    discard cursor.peekChar()
    let first = cursor.pos
    var afterLast = first

    while afterLast < cursor.len and cursor.buf[afterLast] in {'0'..'9'}:
      inc afterLast

    if afterLast > first:
      cursor.addBufferedSlice(value, first, afterLast)
      continue

    break

proc takeIdent(cursor: var Cursor, value: var string) =
  ## Consumes an identifier continuation run into `value`.
  ##
  ## The caller is responsible for checking the first character with
  ## `IdentStartChars`; this helper consumes the rest of the identifier, possibly
  ## across multiple cursor refills.
  while true:
    discard cursor.peekChar()
    let first = cursor.pos
    var afterLast = first

    while afterLast < cursor.len and cursor.buf[afterLast].isIdent():
      inc afterLast

    if afterLast > first:
      cursor.addBufferedSlice(value, first, afterLast)
      continue

    break

proc takeSingleLineStringRun(cursor: var Cursor, value: var string,
    quoteChar: char) =
  ## Consumes plain content from a single-line string.
  ##
  ## This stops before the closing quote, a backslash escape, or a newline error.
  ## Escapes and diagnostics stay in the main string loop because they transform
  ## input or need precise error handling.
  while true:
    discard cursor.peekChar()
    let first = cursor.pos
    var afterLast = first

    while afterLast < cursor.len:
      let current = cursor.buf[afterLast]
      if current == quoteChar or current == '\\' or current == '\n':
        break
      inc afterLast

    if afterLast > first:
      cursor.addBufferedSlice(value, first, afterLast)
      continue

    break

proc takeMultilineStringRun(cursor: var Cursor, value: var string) =
  ## Consumes plain content from a multiline string.
  ##
  ## Multiline strings need line bookkeeping while scanning. This stops before a
  ## quote or backslash so escaped triple quotes and closing triple quotes are
  ## still handled by the main tokenizer loop.
  while true:
    discard cursor.peekChar()
    let first = cursor.pos
    var afterLast = first

    while afterLast < cursor.len:
      let current = cursor.buf[afterLast]
      if current == '\\' or current == '"':
        break
      inc afterLast

    if afterLast > first:
      cursor.addBufferedSliceWithLines(value, first, afterLast)
      continue

    break

when defined(yumlyTrivia):
  proc collectTrivia(cursor: var Cursor, includeNewline: bool): seq[Trivia] =
    while true:
      var consumed = false

      # Consume a contiguous whitespace run from the active buffer.
      var whitespaceLen = 0
      while true:
        discard cursor.peekChar()
        let whitespaceStart = cursor.pos
        var whitespaceEnd = whitespaceStart
        while whitespaceEnd < cursor.len and
            cursor.buf[whitespaceEnd] in {' ', '\t', '\r'}:
          inc whitespaceEnd
        cursor.pos = whitespaceEnd
        whitespaceLen += whitespaceEnd - whitespaceStart
        if whitespaceEnd == whitespaceStart:
          break

      if whitespaceLen > 0:
        result.add(Trivia(kind: tvWhitespace,
            len: SourcePos(whitespaceLen)))
        consumed = true

      # Consume newlines only when collecting leading trivia.
      if includeNewline and cursor.peekChar() == '\n':
        discard cursor.advanceChar()
        result.add(Trivia(kind: tvNewline))
        consumed = true

      if consumed:
        continue

      if cursor.peekChar() == ';' and cursor.peekChar(1) == '>':
        let start = cursor.tokenStart()
        discard cursor.matchStr(";>")
        var text = ""

        while true:
          discard cursor.peekChar()
          let first = cursor.pos
          var afterLast = first
          while afterLast < cursor.len and cursor.buf[afterLast] != '<':
            inc afterLast
          if afterLast > first:
            cursor.addBufferedSliceWithLines(text, first, afterLast)
            continue

          if cursor.peekChar() == '\0':
            commentNotClosedError(start.line, start.col, cursor.sourceLine, cursor.sourceCol)

          if cursor.matchStr("<;"):
            result.add(Trivia(kind: tvComment, text: text))
            break

          let current = cursor.peekChar()
          text.add(current)
          cursor.advanceBuffered(current)

        continue
      break
else:
  proc skipTrivia(cursor: var Cursor) =
    ## Consumes whitespace and comments without storing trivia.
    while true:
      discard cursor.peekChar()
      let whitespaceStart = cursor.pos
      var whitespaceEnd = whitespaceStart
      while whitespaceEnd < cursor.len and
          cursor.buf[whitespaceEnd] in {' ', '\t', '\r', '\n'}:
        inc whitespaceEnd

      if whitespaceEnd > whitespaceStart:
        cursor.advanceBufferedTo(whitespaceEnd)
        continue

      # Consume comments.
      if cursor.peekChar() == ';' and cursor.peekChar(1) == '>':
        let commentStart = cursor.tokenStart()
        discard cursor.matchStr(";>")
        while true:
          discard cursor.peekChar()
          let first = cursor.pos
          var afterLast = first
          while afterLast < cursor.len and cursor.buf[afterLast] != '<':
            inc afterLast
          if afterLast > first:
            cursor.advanceBufferedTo(afterLast)
            continue

          if cursor.peekChar() == '\0':
            commentNotClosedError(commentStart.line, commentStart.col, cursor.sourceLine,
                cursor.sourceCol)

          if cursor.matchStr("<;"):
            break

          let current = cursor.peekChar()
          cursor.advanceBuffered(current)
        continue
      break

type Tokenizer* = object
  ## Stateful tokenizer used by both direct and closure-based consumption.
  cursor: Cursor

func initTokenizer*(stream: Stream, bufferSize: int = 4096,
    sourceFile: SourceFile = nil): Tokenizer =
  result.cursor = initCursor(stream, bufferSize, sourceFile)

func initTokenizer*(content: sink string,
    sourceFile: SourceFile = nil): Tokenizer =
  result.cursor = initCursor(content, sourceFile)

proc tokenPuller(tokenizer: sink Tokenizer): TokenPuller

proc tokenize*(stream: Stream, bufferSize: int = 4096,
    sourceFile: SourceFile = nil): TokenPuller = # is a alias of: `proc(): Token {.closure.}`
  ## Tokenizes the stream and returns a token for each pulling.

  initTokenizer(stream, bufferSize, sourceFile).tokenPuller()

proc tokenize*(content: sink string,
    sourceFile: SourceFile = nil): TokenPuller =
  ## Tokenizes content that is already resident in memory.
  ##
  ## This preserves the same pull API and token representation as the stream
  ## overload while avoiding a `StringStream` and refill checks for content
  ## callers.
  initTokenizer(content, sourceFile).tokenPuller()

proc nextToken*(tokenizer: var Tokenizer): Token =
  ## Pulls one token without an indirect closure call.
  template cursor: untyped = tokenizer.cursor

  while true:
    when defined(yumlyTrivia):
      # collect leading with newlines
      let leading = cursor.collectTrivia(includeNewline = true)
    else:
      cursor.skipTrivia()

    let ch = cursor.peekChar()
    let start = cursor.tokenStart()

    when defined(yumlyTrivia):
      template emitToken(kind: TokenKind): Token =
        block:
          var tok = cursor.token(kind, start)
          tok.leading = leading
          # collect trailing without newlines
          tok.trailing = cursor.collectTrivia(includeNewline = false)
          tok

      template emitToken(kind: TokenKind, value: string): Token =
        block:
          var tok = cursor.token(kind, start, value)
          tok.leading = leading
          # collect trailing without newlines
          tok.trailing = cursor.collectTrivia(includeNewline = false)
          tok
    else:
      template emitToken(kind: TokenKind): Token =
        cursor.token(kind, start)

      template emitToken(kind: TokenKind, value: string): Token =
        cursor.token(kind, start, value)

    # if we have reached the end of the stream, return EOF
    if ch == '\0':
      return emitToken(tkEOF)

    # Tokenize numbers (with Exponent support)
    if ch in {'0'..'9'} or (ch in {'+', '-'} and cursor.peekChar(1) in {'0'..'9'}):
      # get first digits: e.g: 1234
      var value = newStringOfCap(16)
      value.add(ch)
      cursor.advanceBuffered(ch)
      cursor.takeDigits(value)

      # get second digits: e.g: 1234.56
      if cursor.peekChar() == '.':
        value.add('.')
        cursor.advanceBuffered('.')
        cursor.takeDigits(value)

      # get exponent: e.g: 1234e5
      if cursor.peekChar() in {'e', 'E'}:
        let exponent = cursor.peekChar()
        value.add(exponent)
        cursor.advanceBuffered(exponent)
        if cursor.peekChar() in {'+', '-'}:
          let sign = cursor.peekChar()
          value.add(sign)
          cursor.advanceBuffered(sign)
        if cursor.peekChar() notin {'0'..'9'}:
          invalidExponentError(start.line, start.col, cursor.sourceLine, cursor.sourceCol)
        cursor.takeDigits(value)

      return emitToken(tkLiteral, value)

    # Tokenize characters. e.g: (application) ; $ = [] {}
    case ch
    of '(':
      cursor.advanceBuffered(ch)
      return emitToken(tkLParen)
    of ')':
      cursor.advanceBuffered(ch)
      return emitToken(tkRParen)
    of '{':
      cursor.advanceBuffered(ch)
      return emitToken(tkLBrace)
    of '}':
      cursor.advanceBuffered(ch)
      return emitToken(tkRBrace)
    of '[':
      cursor.advanceBuffered(ch)
      return emitToken(tkLBracket)
    of ']':
      cursor.advanceBuffered(ch)
      return emitToken(tkRBracket)
    of '<':
      cursor.advanceBuffered(ch)
      return emitToken(tkLess)
    of '>':
      cursor.advanceBuffered(ch)
      return emitToken(tkGreater)
    of '=':
      cursor.advanceBuffered(ch)
      return emitToken(tkEquals)
    of ';':
      cursor.advanceBuffered(ch)
      return emitToken(tkSemiColon)
    of ',':
      cursor.advanceBuffered(ch)
      return emitToken(tkComma)
    of '@':
      cursor.advanceBuffered(ch)
      return emitToken(tkAt)
    of '*':
      cursor.advanceBuffered(ch)
      return emitToken(tkStar)
    of '!':
      cursor.advanceBuffered(ch)
      return emitToken(tkBang)
    of '$':
      cursor.advanceBuffered(ch)
      return emitToken(tkDollar)
    of '?': # same case as << and >>. if received a ?, then check if it's a double-interrogation.
              # later used for env defaults. e.g: $["VAR_NAME" ?? "DEFAULT_VALUE"]
      if cursor.matchStr("??"):
        return emitToken(tkDoubleInterrogation)
      cursor.advanceBuffered(ch)
      unexpectedCharError($ch, start.line, start.col, cursor.sourceLine, cursor.sourceCol)

    # Tokenization of strings (Multiline strings and single strings)
    of '"', '\'':
      let quoteChar = ch
      var stringContent = newStringOfCap(32)

      # Multiline String: """
      if quoteChar == '"' and cursor.matchStr("\"\"\""):
        while true:
          cursor.takeMultilineStringRun(stringContent)
          let nextCh = cursor.peekChar()
          if nextCh == '\0':
            unclosedStringAtEofError(start.line, start.col, cursor.sourceLine,
                cursor.sourceCol)

          # Escaped triple quote
          if cursor.matchStr("\\\"\"\""):
            stringContent.add("\"\"\"")
            continue

          # End of multiline
          if cursor.matchStr("\"\"\""): break

          stringContent.add(nextCh)
          cursor.advanceBuffered(nextCh)
        return emitToken(tkString, stringContent)

      # Single-line String
      else:
        cursor.advanceBuffered(quoteChar) # skip opening quote
        while true:
          cursor.takeSingleLineStringRun(stringContent, quoteChar)
          let nextCh = cursor.peekChar()

          # NOTE: revisar aqui, sobre o fechamento de string
          if nextCh == '\0':
            unclosedStringAtEofError(start.line, start.col, cursor.sourceLine,
                cursor.sourceCol)
          if nextCh == quoteChar:
            cursor.advanceBuffered(nextCh)
            break
          if nextCh == '\n':
            unclosedStringError(start.line, start.col, cursor.sourceLine, cursor.sourceCol)

          if nextCh == '\\':
            stringContent.add(nextCh)
            cursor.advanceBuffered(nextCh)
            let escaped = cursor.peekChar()
            if escaped == '\0':
              unclosedStringAtEofError(start.line, start.col,
                  cursor.sourceLine, cursor.sourceCol)
            stringContent.add(escaped)
            cursor.advanceBuffered(escaped)
          else:
            stringContent.add(nextCh)
            cursor.advanceBuffered(nextCh)

        return emitToken(tkString, stringContent)
    # fallback for `case ch`: if the current char isn't a special character,
    # try to tokenize it as an identifier or boolean.
    else:
      if ch in IdentStartChars:
        var word = newStringOfCap(16)
        cursor.takeIdent(word)

        # if the word is "true" or "false", return the token as a literal.
        if word == "true" or word == "false":
          return emitToken(tkLiteral, word)

        # if is anything else, return the token as an identifier.
        return emitToken(tkIdent, word)

      # If the current char is not a valid identifier start, it is unexpected.
      cursor.advanceBuffered(ch)
      unexpectedCharError($ch, start.line, start.col, cursor.sourceLine, cursor.sourceCol)

proc tokenPuller(tokenizer: sink Tokenizer): TokenPuller =
  ## Adapts the stateful tokenizer to the pipeline's existing pull contract.
  var tokenizer = tokenizer
  return proc(): Token {.closure.} =
    tokenizer.nextToken()

template withTokenPuller*(stream: Stream, pullToken: untyped, body: untyped) =
  ## Creates a token puller and always closes its input stream.
  block:
    let input = stream
    try:
      let pullToken = tokenize(input)
      body
    finally:
      input.close()

template withTokens*(stream: Stream, token: untyped, body: untyped) =
  ## Consumes every token, including EOF, and closes the input stream.
  withTokenPuller(stream, pullToken):
    while true:
      let token = pullToken()
      body
      if token.kind == tkEOF:
        break
