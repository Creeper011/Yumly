##
# A mini library to construct Ylwa files programmatically.
# Ylwa is a representative language for benchmarking.
##

import std/strutils

type
  YlwaWriter* = object
    output: string
    indentLevel: int

func newYlwaWriter*(): YlwaWriter =
  ## Creates a new YlwaWriter instance.
  YlwaWriter(output: "", indentLevel: 0)

func indent(w: YlwaWriter): string =
  "  ".repeat(w.indentLevel)

func validateIdent(identifier: string) =
  if identifier.len == 0:
    raise newException(ValueError, "Ylwa identifier cannot be empty")
  for character in identifier:
    if character in {';', ':', '\n', '\r', ','}:
      raise newException(ValueError, "Invalid character in Ylwa identifier: " & character)

func validateValue(val: string) =
  for character in val:
    if character in {',', ';', ':', '<', '>'}:
      raise newException(ValueError, "Invalid character in Ylwa value: " & character)

proc addComment*(w: var YlwaWriter, comment: string) =
  ## Adds a multiline comment block (.> ... <.)
  let baseIndent = w.indent()
  w.output.add(baseIndent & ".> " & comment.replace("\n", "\n" & baseIndent &
      "  ") & " <.\n\n")

proc beginBlock*(w: var YlwaWriter, name: string) =
  ## Starts a block (~ Name :)
  validateIdent(name)
  w.output.add(w.indent() & "~ " & name & " :\n")
  inc w.indentLevel

proc addField*(w: var YlwaWriter, name, value: string) =
  ## Adds a field-value pair (- Name ; Value,)
  validateIdent(name)
  validateValue(value)
  w.output.add(w.indent() & "- " & name & " ; " & value & ",\n")

proc addField*(w: var YlwaWriter, name, value, comment: string) =
  ## Adds a field-value pair with a comment (- Name ; Value, .> Comment <.)
  validateIdent(name)
  validateValue(value)
  w.output.add(w.indent() & "- " & name & " ; " & value & ", .> " & comment & " <.\n")

proc endBlock*(w: var YlwaWriter) =
  ## Ends the current block (:)
  if w.indentLevel > 0:
    dec w.indentLevel
  w.output.add(w.indent() & ":\n\n")

func toString*(w: YlwaWriter): string =
  ## Returns the generated Ylwa string.
  w.output
