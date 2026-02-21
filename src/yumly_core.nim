# MVP Parser for Yumly configuration files
# im dumb.. so this code is horrible and unoptimized (yea, i need to hide this in code)

import nimpy
import tokenizer, parser, additional/validate
import types/ast
import results/parser_python, results/parser_yumly_struct
import results/parser_yumly as parserYumly
import yumly_file

# Config parsing (type Config from ast)
proc parseConfig*(path: cstring): cstring {.exportc, dynlib.} =
  parserYumly.parseConfig($path).cstring

proc parseConfig*(path: string): string =
  parserYumly.parseConfig(path)

# Python (Nimpy) parsing
proc parsePyConfig*(path: string): PyObject {.exportpy} =
  parseConfigPython(path)

# YUMLY struct data parsing

proc parseConfigYUMLYstructPy*(path: string): string {.exportpy.} =
  parseConfigYUMLYstruct(path)
