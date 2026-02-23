import nimpy
import types/ast
import serializers/parser_python, serializers/parser_yumly

proc loadYumly*(path: string = "config.yumly"): Config =
  parseConfig(path)

proc loadYumlyPy*(path: string): PyObject {.exportpy.} =
  parseConfigPy(path)