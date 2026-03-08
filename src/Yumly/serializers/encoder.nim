import strutils, options
import ../types/ast, ../types/type_hints, ../types/values_defs

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

proc formatPair(pair: Pair): string =
  ## formats a single pair: key ;type = value
  let typeHintStr = formatTypeHint(pair.typeHint)
  let valueStr = encodeValue(pair.value)
  result = pair.key & typeHintStr & " = " & valueStr

proc renderPairs(ctx: var EncoderCtx, pairs: seq[Pair], isRoot: bool, hasBlocksAfter: bool) =
  for i, pair in pairs:
    let isLastPair = (i == pairs.len - 1)
    # no commas if is in root
    let needsComma = not isRoot and (not isLastPair or hasBlocksAfter)
    let comma = if needsComma: "," else: ""
    
    ctx.emit(formatPair(pair) & comma)

proc renderBlock(ctx: var EncoderCtx, blk: Block, isRoot: bool, isLastInScope: bool) =
  ctx.emit("(" & blk.name & ") {")
  inc ctx.indent
  
  let hasPairs = blk.pairs.len > 0
  let hasSubBlocks = blk.subBlocks.len > 0

  if hasPairs:
    renderPairs(ctx, blk.pairs, isRoot = false, hasBlocksAfter = hasSubBlocks)
  
  if hasPairs and hasSubBlocks:
    ctx.emitRaw("")
    
  if hasSubBlocks:
    for i, sub in blk.subBlocks:
      let isLastSub = (i == blk.subBlocks.len - 1)
      renderBlock(ctx, sub, isRoot = false, isLastInScope = isLastSub)
      if not isLastSub:
        ctx.emitRaw("")
    
  dec ctx.indent
  
  # blocks at root level never have trailing commas.
  # inside blocks, commas separate siblings.
  let needsComma = not isRoot and not isLastInScope
  let comma = if needsComma: "," else: ""
  ctx.emit("}" & comma)

proc dumpYumly*(config: YumlyConf): string =
  var ctx = EncoderCtx(indent: 0)

  # include always on top with no commas
  for incl in config.includes:
    ctx.emit("include { " & incl.includePath & " }")

  let hasIncludes = config.includes.len > 0
  let hasPairs = config.pairs.len > 0
  let hasBlocks = config.blocks.len > 0

  if hasIncludes and (hasPairs or hasBlocks):
    ctx.emitRaw("")

  # root pairs one per line
  if hasPairs:
    renderPairs(ctx, config.pairs, isRoot = true, hasBlocksAfter = hasBlocks)

  if hasPairs and hasBlocks:
    ctx.emitRaw("")

  # root blocks
  if hasBlocks:
    for i, blk in config.blocks:
      let isLast = (i == config.blocks.len - 1)
      renderBlock(ctx, blk, isRoot = true, isLastInScope = isLast)
      if not isLast:
        ctx.emitRaw("")

  return ctx.lines.join("\n")
