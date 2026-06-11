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

proc refill*(cursor: var Cursor) =
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

proc peekChar*(cursor: var Cursor, offset: int = 0): char =
  var idx = cursor.pos + offset
  while idx >= cursor.len and not cursor.eof:
    cursor.refill()
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
