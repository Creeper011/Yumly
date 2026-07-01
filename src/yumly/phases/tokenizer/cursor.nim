import streams
import ../../types/source

type Cursor* = object
  stream*: Stream
  source*: SourceFile
  buf*: string
  pos*: int
  len*: int
  basePos*: int
  eof*: bool
  line*: int
  lineStart*: int

func initCursor*(stream: Stream, bufferSize: int = 4096,
    source: SourceFile = nil): Cursor =
  result.stream = stream
  result.source = source
  result.buf = newString(max(1, bufferSize))
  result.pos = 0
  result.len = 0
  result.basePos = 0
  result.eof = false
  result.line = 1
  result.lineStart = 0

func initCursor*(content: sink string, source: SourceFile = nil): Cursor =
  ## Creates a cursor over content that is already resident in memory.
  ##
  ## It deliberately uses the same cursor representation as the streaming
  ## path. `eof = true` tells the scanner that the complete input is already in
  ## `buf`, so no refill or `StringStream` layer is involved.
  result.stream = nil
  result.source = source
  result.buf = content
  result.pos = 0
  result.len = result.buf.len
  result.basePos = 0
  result.eof = true
  result.line = 1
  result.lineStart = 0

func absPos*(cursor: Cursor): int {.inline.} =
  cursor.basePos + cursor.pos

proc ensureCapacity(cursor: var Cursor, minCapacity: int) =
  if cursor.buf.len >= minCapacity: return

  var newSize = max(1, cursor.buf.len)
  while newSize < minCapacity:
    newSize = max(newSize + 1, newSize * 2)

  var grown = newString(newSize)
  if cursor.len > 0:
    copyMem(addr grown[0], addr cursor.buf[0], cursor.len)
  cursor.buf = grown

proc refill*(cursor: var Cursor, minBuffered: int = 1) =
  if cursor.eof: return

  let oldPos = cursor.pos
  let remaining = cursor.len - cursor.pos

  if remaining > 0 and oldPos > 0:
    moveMem(addr cursor.buf[0], addr cursor.buf[oldPos], remaining)

  cursor.basePos += oldPos
  cursor.pos = 0
  cursor.len = remaining

  cursor.ensureCapacity(max(cursor.len + 1, minBuffered))

  let free = cursor.buf.len - cursor.len
  let n = cursor.stream.readData(addr cursor.buf[cursor.len], free)
  if n <= 0: cursor.eof = true
  else: cursor.len += n

proc peekChar*(cursor: var Cursor, offset: int = 0): char {.inline.} =
  if offset < 0: return '\0'

  var idx = cursor.pos + offset
  while idx >= cursor.len and not cursor.eof:
    cursor.refill(offset + 1)
    idx = cursor.pos + offset
  if idx < cursor.len: result = cursor.buf[idx]
  else: result = '\0'

proc advanceBuffered*(cursor: var Cursor, character: char) {.inline.} =
  ## Advances over a character already read from `buf`.
  inc cursor.pos
  if character == '\n':
    inc cursor.line
    cursor.lineStart = cursor.basePos + cursor.pos

proc advanceBufferedTo*(cursor: var Cursor, afterLast: int) {.inline.} =
  ## Advances across a range that has already been scanned in the active
  ## buffer, updating line bookkeeping once without another `peekChar` pass.
  for i in cursor.pos..<afterLast:
    if cursor.buf[i] == '\n':
      inc cursor.line
      cursor.lineStart = cursor.basePos + i + 1
  cursor.pos = afterLast

proc advanceChar*(cursor: var Cursor): char {.inline.} =
  result = cursor.peekChar()
  if result == '\0': return
  cursor.advanceBuffered(result)

proc matchStr*(cursor: var Cursor, s: string): bool {.inline.} =
  for i, character in s:
    if cursor.peekChar(i) != character: return false
  for character in s:
    cursor.advanceBuffered(character)
  return true
