##
# A mini library to construct Ylwa files programmatically.
# Ylwa is a representative language for benchmarking.
##

import std/strutils

type
  YlwaWriter* = object
    output: string

func newYlwaWriter*(): YlwaWriter =
  ## Creates a new YlwaWriter instance.
  YlwaWriter(output: "")

proc addHeader*(w: var YlwaWriter, header: string) =
  ## Adds a top-level header (e.g., .> Title <.)
  w.output.add(".> " & header & " <.\n\n")

proc addComment*(w: var YlwaWriter, comment: string) =
  ## Adds a multiline comment block.
  w.output.add(".> \n  " & comment.replace("\n", "\n  ") & "\n.< \n\n")

proc beginBlock*(w: var YlwaWriter, name: string) =
  ## Starts a block (~ Name :)
  w.output.add("~ " & name & " :\n")

proc addField*(w: var YlwaWriter, name, value: string) =
  ## Adds a field-value pair (- Name ; Value,)
  # Values in Ylwa are strings, no specific typing.
  w.output.add("  - " & name & " ; " & value & ",\n")

proc endBlock*(w: var YlwaWriter) =
  ## Ends the current block (:)
  w.output.add(":\n\n")

func toString*(w: YlwaWriter): string =
  ## Returns the generated Ylwa string.
  w.output
