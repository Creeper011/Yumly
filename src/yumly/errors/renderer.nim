## Optional human-readable renderer for Yumly errors.
##
## Importing this module opts a frontend into source-file reading and formatted
## snippets. The parser and the structured error types do not depend on it.

import std/[options, os, strutils]
import ../types/[errors, source]
import ./codes

type LabeledSourceSpan = object
  span: SourceSpan
  message: string
  primary: bool

func spaces(count: int): string =
  if count > 0: repeat(" ", count) else: ""

proc displayPath(path: string): string =
  if path.len == 0:
    return ""
  try:
    let relative = relativePath(path, getCurrentDir())
    if relative.len > 0 and not relative.startsWith(".."):
      return relative
  except OSError:
    discard
  path

proc sourcePath(span: SourceSpan, fallbackPath: string): string =
  if span.source != nil: span.source.path
  elif fallbackPath.len > 0 and fileExists(fallbackPath): fallbackPath
  else: ""

proc readSource(path: string): Option[string] =
  if path.len == 0:
    return none(string)
  try: some(readFile(path))
  except CatchableError: none(string)

func sourceLine(source: string, targetLine: SourcePos): Option[string] =
  if targetLine == 0:
    return none(string)
  var currentLine = SourcePos(1)
  for line in source.splitLines():
    if currentLine == targetLine:
      return some(line)
    inc currentLine
  none(string)

proc sourceText(span: SourceSpan, fallbackPath,
    fallbackContent: string): string =
  if span.source != nil:
    let loaded = readSource(span.source.path)
    if loaded.isSome: return loaded.get
    return ""
  let path = sourcePath(span, fallbackPath)
  if path.len > 0:
    let loaded = readSource(path)
    if loaded.isSome: return loaded.get
  fallbackContent

func caretPrefix(line: string, col: SourcePos): string =
  let prefixLen = max(0, int(col) - 1)
  var consumed = 0
  for ch in line:
    if consumed >= prefixLen: break
    result.add(if ch == '\t': '\t' else: ' ')
    inc consumed
  if consumed < prefixLen:
    result.add(spaces(prefixLen - consumed))

func caretWidth(span: SourceSpan, line: string): int =
  let startOffset = max(0, int(span.col) - 1)
  let remaining = max(1, line.len - startOffset)
  if span.endLine == span.line and span.endCol > span.col:
    min(remaining, max(1, int(span.endCol - span.col)))
  elif span.endLine > span.line:
    remaining
  else:
    1

proc formatLabeledSources(labels: openArray[LabeledSourceSpan],
    fallbackPath, fallbackContent: string): seq[string] =
  var gutterWidth = 1
  var displayedSource = ""
  for label in labels:
    gutterWidth = max(gutterWidth, ($label.span.line).len)
  for label in labels:
    if label.span.line == 0 or label.span.col == 0:
      continue
    let source = sourceText(label.span, fallbackPath, fallbackContent)
    if source.len == 0: continue
    let line = source.sourceLine(label.span.line)
    if line.isNone: continue
    let path = sourcePath(label.span, fallbackPath)
    if path.len > 0 and path != displayedSource:
      result.add("  --> " & displayPath(path) & ":" & $label.span.line &
        ":" & $label.span.col)
      displayedSource = path
    let firstContextLine = max(SourcePos(1), label.span.line - min(
        label.span.line - SourcePos(1), SourcePos(2)))
    for contextLineNumber in firstContextLine ..< label.span.line:
      let contextLine = source.sourceLine(contextLineNumber)
      if contextLine.isSome:
        result.add("  " & align($contextLineNumber, gutterWidth) & " | " &
          contextLine.get)
    let lineText = line.get
    let gutter = align($label.span.line, gutterWidth)
    let marker = if label.primary: "^" else: "-"
    result.add("  " & gutter & " | " & lineText)
    result.add("  " & spaces(gutterWidth) & " | " &
      caretPrefix(lineText, label.span.col) &
      repeat(marker, caretWidth(label.span, lineText)) & " " & label.message)

proc formatSimpleError(message: string, code: ErrorCode,
    sources: openArray[SourceSpan], fallbackPath,
    fallbackContent: string): string =
  var lines = @[message]
  if sources.len > 0:
    let labels = [LabeledSourceSpan(span: sources[0], message: "", primary: true)]
    lines.add(formatLabeledSources(labels, fallbackPath, fallbackContent))
  if code != ecNone:
    lines.add("  code: " & $code)
  let path =
    if sources.len > 0: sourcePath(sources[0], fallbackPath)
    else: ""
  if path.len > 0:
    lines.add("  file: " & displayPath(path))
  lines.join("\n")

proc formatError*(error: ref YumlyError, fallbackPath = "",
    fallbackContent = ""): string =
  formatSimpleError(error.msg, error.code, error.source, fallbackPath,
    fallbackContent)

proc formatError*(error: ref YumlyIOError, fallbackPath = "",
    fallbackContent = ""): string =
  formatSimpleError(error.msg, error.code, error.source, fallbackPath,
    fallbackContent)
