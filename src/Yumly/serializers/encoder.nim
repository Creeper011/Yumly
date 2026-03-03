import strutils, options
import ../types/ast

type
  EncoderCtx = object
    indent: int
    lines: seq[string]

template pad(n: int): string =
  repeat("    ", n)

template emit(ctx: var EncoderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

template emitRaw(ctx: var EncoderCtx, line: string) =
  ctx.lines.add(line)

proc formatTypeHint(hint: Option[TypeHint]): string =
  if hint.isSome:
    return " ;" & hint.get.raw
  return ""

proc formatValue(val: Value): string =
  case val.kind
  of vkString:
    "\"" & val.strVal & "\""
  of vkInt:
    $val.intVal
  of vkFloat:
    $val.floatVal
  of vkBool:
    if val.boolVal: "true" else: "false"
  of vkEnv:
    "$[\"" & val.envVal & "\"]"
  of vkList:
    var parts: seq[string] = @[]
    for el in val.elements:
      parts.add(formatValue(el))
    "[" & parts.join(", ") & "]"
  of vkTuple:
    var parts: seq[string] = @[]
    for el in val.elements:
      parts.add(formatValue(el))
    "[" & parts.join(", ") & "]"

proc renderPair(ctx: var EncoderCtx, pair: Pair, isLast: bool) =
  let t = formatTypeHint(pair.typeHint)
  let v = formatValue(pair.value)
  let comma = if isLast: "" else: ","
  ctx.emit(pair.key & t & " = " & v & comma)

proc renderBlock(ctx: var EncoderCtx, blk: Block) =
  ctx.emit("(" & blk.name & ") {")
  inc ctx.indent

  let totalPairs = blk.pairs.len
  for i, pair in blk.pairs:
    # If there are subblocks, no comma after the last pair unless there are no subblocks? Actually in Yumly commas separate pairs.
    # Usually pairs end with a comma, except the last one in the block (or before subblocks, though usually they can have commas too).
    let isLast = (i == totalPairs - 1) and (blk.subBlocks.len == 0)
    renderPair(ctx, pair, isLast)

  if totalPairs > 0 and blk.subBlocks.len > 0:
    ctx.emitRaw("") # empty line between pairs and subblocks

  for i, sub in blk.subBlocks:
    renderBlock(ctx, sub)
    if i < blk.subBlocks.len - 1:
      ctx.emitRaw("") # empty line between sibling subblocks

  dec ctx.indent
  ctx.emit("}")

proc dumpYumly*(config: YumlyKind): string =
  var ctx = EncoderCtx(indent: 0)

  for inc_stmt in config.includes:
    ctx.emit("include { " & inc_stmt.includePath & " }")

  if config.includes.len > 0 and (config.pairs.len > 0 or config.blocks.len > 0):
    ctx.emitRaw("")

  let totalPairs = config.pairs.len
  for i, pair in config.pairs:
    let isLast = (i == totalPairs - 1) and (config.blocks.len == 0)
    renderPair(ctx, pair, isLast)

  if config.pairs.len > 0 and config.blocks.len > 0:
    ctx.emitRaw("")

  for i, blk in config.blocks:
    renderBlock(ctx, blk)
    if i < config.blocks.len - 1:
      ctx.emitRaw("")

  return ctx.lines.join("\n")
