# MVP Parser for Yumly configuration files

import nimpy
import results/parser_python, results/parser_yumly_struct
import results/parser_yumly as parserYumly

# Config parsing (type Config from ast)
proc parseConfig*(path: cstring): cstring {.exportc, dynlib.} =
  parserYumly.parseConfig($path).cstring

proc parseConfig*(path: string): string =
  parserYumly.parseConfig(path)

proc loadYumly*(path: string = "config.yumly"): string =
  parseConfig(path)

# Python (Nimpy) parsing
proc parsePyConfig*(path: string): PyObject {.exportpy} =
  parseConfigPython(path)

# YUMLY struct data parsing

proc parseConfigYUMLYstructPy*(path: string): string {.exportpy.} =
  parseConfigYUMLYstruct(path)
