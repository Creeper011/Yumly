##
# Serialization utilities for Nim API
##

import std/tables
import ../../types/ast
import ../../utils/value_utils
import ../../core/builders
import ../../core/pipeline
import modifications

func toYumly*(config: YumlyConf): string =
  return dumpYumly(config)

proc writeYumly*(config: var YumlyConf, path: string, inferType: bool = false) =
  if inferType:
    applyTypeHints(config)
  writeFile(path, dumpYumly(config))

func toYumly*(pairs: openArray[(string, Value)],
    inferType: bool = false): string =
  var cfg = newYumly()
  for (key, value) in pairs:
    let hint = if inferType: inferTypeHintRaw(value) else: ""
    cfg.addPair(key, value, hint)
  return dumpYumly(cfg)

func toYumly*(pairs: openArray[(string, Value, string)]): string =
  var cfg = newYumly()
  for (k, v, hint) in pairs:
    cfg.addPair(k, v, hint)
  return dumpYumly(cfg)

func toYumly*(t: Table[string, Value], inferType: bool = false): string =
  var cfg = newYumly()
  for key, value in t.pairs:
    let hint = if inferType: inferTypeHintRaw(value) else: ""
    cfg.addPair(key, value, hint)
  return dumpYumly(cfg)
