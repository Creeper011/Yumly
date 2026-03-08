import strutils, options
import ../types/ast, ../types/type_hints, ../types/values_defs

type
  RenderCtx = object
    indent: int
    lines: seq[string]

proc pad(n: int): string =
  repeat("  ", n)

proc emit(ctx: var RenderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

proc formatTypeHint(hint: Option[TypeHint], kind: ValueKind): string =
  if hint.isSome:
    return hint.get.raw
  return VALUES_DEF[kind].typeHint

proc renderPair(ctx: var RenderCtx, pair: Pair) =
  let typeName = formatTypeHint(pair.typeHint, pair.value.kind)
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
