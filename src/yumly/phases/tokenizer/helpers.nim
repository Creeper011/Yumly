import ../../types/[source, token]
import cursor

func sourceLine*(cursor: Cursor): SourcePos {.inline.} =
  SourcePos(cursor.line)

func sourceCol*(cursor: Cursor): SourcePos {.inline.} =
  SourcePos(cursor.absPos() - cursor.lineStart + 1)

func tokenStart*(cursor: Cursor): SourceSpan {.inline.} =
  sourceSpan(cursor.source, cursor.sourceLine(), cursor.sourceCol())

# Procedures to create an Token object

proc token*(cursor: var Cursor, kind: TokenKind, start: SourceSpan,
    value: sink string): Token {.inline.} =
  ## Creates a token object with a value.
  let endLine = cursor.sourceLine()
  let endCol = cursor.sourceCol()

  case kind
  of tkString, tkIdent, tkLiteral:
    result = Token(kind: kind, value: value)
  else:
    result = Token(kind: kind)

  # fills the common fields from Token
  result.source = sourceSpan(start.source, start.line, start.col, endLine, endCol)

proc token*(cursor: var Cursor, kind: TokenKind,
    start: SourceSpan): Token {.inline.} =
  ## Creates a token object without a value.
  cursor.token(kind, start, "")
