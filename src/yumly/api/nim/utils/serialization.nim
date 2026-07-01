##
# Serialization utilities for Nim API
##

import std/tables
import ../../../types/ast
import ../../../core/[builders, pipeline]
import ../../../serializers/yumyumy/yumyumyencoder
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
    if inferType: cfg.addPair(key, value, typeHintFor(value))
    else: cfg.addPair(key, value)
  return dumpYumly(cfg)

func toYumly*(pairs: openArray[(string, Value, string)]): string =
  var cfg = newYumly()
  for (k, v, hint) in pairs:
    cfg.addPair(k, v, hint)
  return dumpYumly(cfg)

func toYumly*(t: Table[string, Value], inferType: bool = false): string =
  var cfg = newYumly()
  for key, value in t.pairs:
    if inferType: cfg.addPair(key, value, typeHintFor(value))
    else: cfg.addPair(key, value)
  return dumpYumly(cfg)

func toYumyumy*(config: YumlyConf): string =
  yumyumyencoder.toYumyumy(config)
