import streams

type Cursor* = object
  stream*: Stream
  buf*: string
  pos*: int
  len*: int
  basePos*: int
  eof*: bool
  line*: int
  lineStart*: int

func initCursor*(stream: Stream, bufferSize: int = 4096): Cursor =
  result.stream = stream
  result.buf = newString(max(1, bufferSize))
  result.pos = 0
  result.len = 0
  result.basePos = 0
  result.eof = false
  result.line = 1
  result.lineStart = 0

func absPos*(cursor: Cursor): int =
  cursor.basePos + cursor.pos

proc ensureCapacity(cursor: var Cursor, minCapacity: int) =
  if cursor.buf.len >= minCapacity: return

  var newSize = max(1, cursor.buf.len)
  while newSize < minCapacity:
    newSize = max(newSize + 1, newSize * 2)

  var grown = newString(newSize)
  for i in 0..<cursor.len:
    grown[i] = cursor.buf[i]
  cursor.buf = grown

proc refill*(cursor: var Cursor, minBuffered: int = 1) =
  if cursor.eof: return

  let oldPos = cursor.pos
  let remaining = cursor.len - cursor.pos

  if remaining > 0 and oldPos > 0:
    for i in 0..<remaining:
      cursor.buf[i] = cursor.buf[oldPos + i]

  cursor.basePos += oldPos
  cursor.pos = 0
  cursor.len = remaining

  cursor.ensureCapacity(max(cursor.len + 1, minBuffered))

  let free = cursor.buf.len - cursor.len
  let n = cursor.stream.readData(addr cursor.buf[cursor.len], free)
  if n <= 0: cursor.eof = true
  else: cursor.len += n

proc peekChar*(cursor: var Cursor, offset: int = 0): char =
  if offset < 0: return '\0'

  var idx = cursor.pos + offset
  while idx >= cursor.len and not cursor.eof:
    cursor.refill(offset + 1)
    idx = cursor.pos + offset
  if idx < cursor.len: result = cursor.buf[idx]
  else: result = '\0'

proc advanceChar*(cursor: var Cursor): char =
  result = cursor.peekChar()
  if result == '\0': return
  inc cursor.pos
  if result == '\n':
    inc cursor.line
    cursor.lineStart = cursor.basePos + cursor.pos

proc matchStr*(cursor: var Cursor, s: string): bool =
  for i, character in s:
    if cursor.peekChar(i) != character: return false
  for _ in 0..<s.len: discard cursor.advanceChar()
  return true
