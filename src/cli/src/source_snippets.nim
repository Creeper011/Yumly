import std/[options, os, strutils]

type SourceSpan* = object
  sourceFile*: string
  line*, col*: int
  endLine*, endCol*: int

func hasSnippetLocation(span: SourceSpan): bool =
  span.line > 0 and span.col > 0

func spaces(count: int): string =
  if count <= 0:
    result = ""
  else:
    result = repeat(" ", count)

proc sourcePath*(span: SourceSpan, fallbackPath: string): string =
  if span.sourceFile.len > 0:
    return span.sourceFile
  if fallbackPath.len > 0 and fileExists(fallbackPath):
    return fallbackPath
  ""

proc readSource(path: string): Option[string] =
  if path.len == 0:
    return none(string)

  try:
    some(readFile(path))
  except CatchableError:
    none(string)

func sourceLine(source: string, targetLine: int): Option[string] =
  if targetLine <= 0:
    return none(string)

  var currentLine = 1
  for line in source.splitLines():
    if currentLine == targetLine:
      return some(line)
    inc currentLine

  none(string)

proc sourceText(span: SourceSpan, fallbackPath, fallbackContent: string): string =
  if span.sourceFile.len > 0:
    let loaded = readSource(span.sourceFile)
    if loaded.isSome:
      return loaded.get
    return ""

  let path = sourcePath(span, fallbackPath)
  if path.len > 0:
    let loaded = readSource(path)
    if loaded.isSome:
      return loaded.get

  fallbackContent

func caretPrefix(line: string, col: int): string =
  let prefixLen = max(0, col - 1)
  var consumed = 0

  for ch in line:
    if consumed >= prefixLen:
      break
    if ch == '\t':
      result.add('\t')
    else:
      result.add(' ')
    inc consumed

  if consumed < prefixLen:
    result.add(spaces(prefixLen - consumed))

func caretWidth(span: SourceSpan, line: string): int =
  let startOffset = max(0, span.col - 1)
  let remaining = max(1, line.len - startOffset)

  if span.endLine == span.line and span.endCol > span.col:
    return min(remaining, max(1, span.endCol - span.col))

  if span.endLine > span.line:
    return remaining

  1

proc formatSourceSnippet*(span: SourceSpan, fallbackPath = "", fallbackContent = ""): seq[string] =
  if not span.hasSnippetLocation:
    return

  let source = sourceText(span, fallbackPath, fallbackContent)
  if source.len == 0:
    return

  let line = source.sourceLine(span.line)
  if line.isNone:
    return

  let lineText = line.get
  let gutter = $span.line
  result.add("  " & gutter & " | " & lineText)
  result.add("  " & spaces(gutter.len) & " | " &
    caretPrefix(lineText, span.col) &
    repeat("^", caretWidth(span, lineText)))
