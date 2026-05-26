##
# This module converts the AST into the YumYumy syntax
# For more information check: docs/yumyumy.md
##

import strutils, options
import ../types/ast, ../types/type_hints, ../types/values_defs
import ../utils/value_utils

type
  RenderCtx = object
    indent: int
    lines: seq[string]

proc pad(n: int): string =
  repeat("  ", n)

proc emit(ctx: var RenderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

func rawListElement(raw: string): string =
  let normalized = raw.strip()
  if normalized.startsWith("list[") and normalized.endsWith("]") and normalized.len > 6:
    return normalized[5 .. ^2].strip()
  if normalized.startsWith("list,") and normalized.len > 5:
    return normalized[5 .. ^1].strip()
  ""

func inferredTypeHint(val: Value): string =
  case val.kind
  of vkList:
    "list, " & inferListElementRaw(val)
  else:
    inferTypeHintRaw(val)

func formatTypeHint(hint: Option[TypeHint], val: Value): string =
  if hint.isSome:
    let hintValue = hint.get
    if hintValue.kind == thList:
      let elementRaw =
        if hintValue.elementRaw.len > 0: hintValue.elementRaw
        else: inferListElementRaw(val)
      return "list, " & elementRaw

    let raw = hintValue.raw.strip()
    if raw.len == 0:
      return inferredTypeHint(val)
    if raw == "list":
      return "list, " & inferListElementRaw(val)

    let elementRaw = rawListElement(raw)
    if elementRaw.len > 0:
      return "list, " & elementRaw

    return raw

  inferredTypeHint(val)

proc renderPair(ctx: var RenderCtx, pair: Pair) =
  let typeName = formatTypeHint(pair.typeHint, pair.value)
  let valueStr = encodeValue(pair.value, styleYumyumy)
  ctx.emit(pair.key & " (" & typeName & ") -> " & valueStr)

proc renderBlock(ctx: var RenderCtx, blk: Block) =
  ctx.emit("[" & blk.name & "] (")
  inc ctx.indent

  for pair in blk.pairs:
    renderPair(ctx, pair)

  for sub in blk.subBlocks:
    renderBlock(ctx, sub)

  dec ctx.indent
  ctx.emit(")")

proc toYumyumy*(config: YumlyConf): string =
  var ctx = RenderCtx(indent: 0)

  ctx.emit("[")
  inc ctx.indent

  for pair in config.pairs:
    renderPair(ctx, pair)

  for blk in config.blocks:
    renderBlock(ctx, blk)

  dec ctx.indent
  ctx.emit("]")

  return ctx.lines.join("\n")
