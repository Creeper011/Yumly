import strutils, options
import ../types/ast

type
  RenderCtx = object
    indent: int
    lines: seq[string]

proc pad(n: int): string =
  repeat("  ", n)

proc emit(ctx: var RenderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

proc formatType(hint: Option[TypeHint], kind: ValueKind): string =
  if hint.isSome:
    return hint.get.raw
  case kind
  of vkString: "string"
  of vkInt: "int"
  of vkFloat: "float"
  of vkBool: "bool"
  of vkList: "list"
  of vkTuple: "tuple"
  of vkEnv: "env"

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
    "\"" & val.envVal & "\""
  of vkList:
    var parts: seq[string] = @[]
    for el in val.elements:
      parts.add(formatValue(el))
    "[" & parts.join(", ") & "]"
  of vkTuple:
    var parts: seq[string] = @[]
    for el in val.elements:
      parts.add(formatValue(el))
    "(" & parts.join(", ") & ")"

proc renderPair(ctx: var RenderCtx, pair: Pair, isBlock: bool) =
  let t = formatType(pair.typeHint, pair.value.kind)
  let v = formatValue(pair.value)
  ctx.emit(pair.key & " (" & t & ") -> " & v)

proc renderBlock(ctx: var RenderCtx, blk: Block) =
  ctx.emit("[" & blk.name & "] (")
  inc ctx.indent

  for pair in blk.pairs:
    renderPair(ctx, pair, true)

  for sub in blk.subBlocks:
    renderBlock(ctx, sub)

  dec ctx.indent
  ctx.emit(")")

proc toYumyumy*(config: YumlyKind): string =
  var ctx = RenderCtx(indent: 0)

  ctx.emit("[")
  inc ctx.indent

  for pair in config.pairs:
    renderPair(ctx, pair, false)

  for blk in config.blocks:
    renderBlock(ctx, blk)

  dec ctx.indent
  ctx.emit("]")

  ctx.lines.join("\n")