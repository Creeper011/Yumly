##
# This module converts the AST into the YumYumy syntax
# For more information check: docs/yumyumy.md
##

import strutils, options
import ../../types/[ast, type_hints, values_defs]

type
  RenderCtx = object
    indent: int
    lines: seq[string]

proc pad(n: int): string =
  repeat("  ", n)

proc emit(ctx: var RenderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

func formatTypeHint(hint: Option[TypeHint], val: Value): string =
  if hint.isSome:
    let h = hint.get
    if h.kind == thList:
      if h.elementRaw.len > 0: return "list, " & h.elementRaw
      return "list"
    return h.raw
  if val.kind == vkList: "list"
  else: VALUES_DEF[val.kind].typeHint

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
