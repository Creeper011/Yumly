import nimpy
import serializers/parser_python, serializers/parser_yumly

proc loadYumly*(path: string = "config.yumly"): string =
  parseConfig(path)

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  parseConfigPy(path)