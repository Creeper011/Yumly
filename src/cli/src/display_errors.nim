import std/[os, strutils]
import ../../yumly/types/errors
import ./display
import ./source_snippets

type CliDiagnostic* = object
  message*: string
  code*: string
  sourceFile*: string
  line*, col*: int
  endLine*, endCol*: int

func hasLocation(diagnostic: CliDiagnostic): bool =
  diagnostic.line > 0 or diagnostic.col > 0

func hasSpan(diagnostic: CliDiagnostic): bool =
  diagnostic.endLine > diagnostic.line or
    (diagnostic.endLine == diagnostic.line and diagnostic.endCol >
        diagnostic.col + 1)

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

func toSourceSpan(diagnostic: CliDiagnostic): SourceSpan =
  SourceSpan(sourceFile: diagnostic.sourceFile, line: diagnostic.line,
    col: diagnostic.col, endLine: diagnostic.endLine,
    endCol: diagnostic.endCol)

proc diagnosticSourcePath(diagnostic: CliDiagnostic,
    fallbackPath: string): string =
  sourcePath(diagnostic.toSourceSpan, fallbackPath)

func shouldShowSnippet(diagnostic: CliDiagnostic): bool =
  diagnostic.code != "include.load-failed"

proc diagnosticSnippetLines(diagnostic: CliDiagnostic, fallbackPath = "",
    fallbackContent = ""): seq[string] =
  if not diagnostic.shouldShowSnippet:
    return

  formatSourceSnippet(diagnostic.toSourceSpan, fallbackPath, fallbackContent)

func detailLinesAreIndented(lines: seq[string]): bool =
  if lines.len <= 1:
    return false

  for i in 1 .. lines.high:
    if lines[i].len > 0 and not lines[i].startsWith("  "):
      return false

  true

func messageWithSnippet(message: string, snippet: seq[string]): seq[string] =
  if snippet.len == 0:
    result.add(message)
    return

  let messageLines = message.splitLines()
  if messageLines.len == 0:
    result.add(snippet)
    return

  if detailLinesAreIndented(messageLines):
    result.add(messageLines[0])
    result.add(snippet)
    for i in 1 .. messageLines.high:
      result.add(messageLines[i])
  else:
    result.add(message)
    result.add(snippet)

proc extraDiagnosticLines(diagnostic: CliDiagnostic,
    fallbackPath = ""): seq[string] =
  if diagnostic.code.len > 0:
    result.add("  code: " & diagnostic.code)
  let path = diagnosticSourcePath(diagnostic, fallbackPath)
  if path.len > 0:
    result.add("  file: " & displayPath(path))
  if diagnostic.hasLocation() and diagnostic.hasSpan():
    result.add("  range: " & $diagnostic.line & ":" & $diagnostic.col & "-" &
      $diagnostic.endLine & ":" & $diagnostic.endCol)

proc formatDiagnostic*(diagnostic: CliDiagnostic, fallbackPath = "",
    fallbackContent = ""): string =
  var lines = messageWithSnippet(diagnostic.message,
    diagnosticSnippetLines(diagnostic, fallbackPath, fallbackContent))
  lines.add(extraDiagnosticLines(diagnostic, fallbackPath))
  lines.join("\n")

proc printDiagnostic*(diagnostic: CliDiagnostic, fallbackPath = "",
    fallbackContent = "") =
  error(formatDiagnostic(diagnostic, fallbackPath, fallbackContent))

func toCliDiagnostic*(err: ref YumlyError): CliDiagnostic =
  CliDiagnostic(message: err.msg, code: err.code, sourceFile: err.sourceFile,
    line: err.line, col: err.col, endLine: err.endLine, endCol: err.endCol)

func toCliDiagnostic*(err: ref YumlyIOError): CliDiagnostic =
  CliDiagnostic(message: err.msg, code: err.code, sourceFile: err.sourceFile,
    line: err.line, col: err.col, endLine: err.endLine, endCol: err.endCol)

proc printDiagnostic*(err: ref YumlyError, fallbackPath = "",
    fallbackContent = "") =
  printDiagnostic(err.toCliDiagnostic(), fallbackPath, fallbackContent)

proc printDiagnostic*(err: ref YumlyIOError, fallbackPath = "",
    fallbackContent = "") =
  printDiagnostic(err.toCliDiagnostic(), fallbackPath, fallbackContent)
