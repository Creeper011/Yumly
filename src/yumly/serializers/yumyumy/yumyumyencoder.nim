#
# This module converts the AST into the YumYumy syntax
# For more information check: docs/yumyumy.md
#

import options
import ../../types/[ast, typehints]

type
  RenderCtx = object
    indent: int
    buffer: string

func beginLine(ctx: var RenderCtx) =
  ## Starts a new output line and writes the current indentation.
  if ctx.buffer.len > 0:
    ctx.buffer.add('\n')
  for _ in 0..<ctx.indent:
    ctx.buffer.add("  ")

func emit(ctx: var RenderCtx, line: string) =
  ## Emits a complete line using the current indentation.
  ctx.beginLine()
  ctx.buffer.add(line)

func addEscaped(buffer: var string, raw: string) =
  for ch in raw:
    case ch
    of '\n': buffer.add("\\n")
    of '\r': buffer.add("\\r")
    of '\t': buffer.add("\\t")
    of '\\': buffer.add("\\\\")
    of '"': buffer.add("\\\"")
    else: buffer.add(ch)

func inferredTypeName(value: Value): string =
  when defined(yumlyEnv):
    case value.kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkList: "list"
    of vkEnv: "env"
    of vkObject: "object"
  else:
    case value.kind
    of vkString: "string"
    of vkInt: "int"
    of vkFloat: "float"
    of vkBool: "bool"
    of vkList: "list"
    of vkObject: "object"

func formatTypeHint(hint: Option[TypeHint], val: Value): string =
  if hint.isSome:
    let h = hint.get
    if h.kind == thList:
      if h.elementRaw.len > 0: return "list, " & h.elementRaw
      return "list"
    when defined(yumlyEnv):
      if h.kind == thEnv:
        return "env"
    return h.raw
  inferredTypeName(val)

func renderValue(ctx: var RenderCtx, value: Value)
func renderItem(ctx: var RenderCtx, item: Item)
func renderPair(ctx: var RenderCtx, pair: Pair)
func renderBlock(ctx: var RenderCtx, blk: Block)

func renderList(ctx: var RenderCtx, value: Value) =
  if value.elements.len == 0:
    ctx.buffer.add("[]")
    return

  ctx.buffer.add("[")
  inc ctx.indent
  for item in value.elements:
    ctx.renderItem(item)
  dec ctx.indent
  ctx.beginLine()
  ctx.buffer.add("]")

func renderObject(ctx: var RenderCtx, value: Value) =
  if value.schema.isSome:
    ctx.buffer.add("<")
    ctx.buffer.add(value.schema.get.name)
    ctx.buffer.add("> ")

  if value.items.len == 0:
    ctx.buffer.add("{}")
    return

  ctx.buffer.add("{")
  inc ctx.indent
  for item in value.items:
    ctx.renderItem(item)
  dec ctx.indent
  ctx.beginLine()
  ctx.buffer.add("}")

func renderValue(ctx: var RenderCtx, value: Value) =
  when not defined(yumlyEnv):
    {.push warning[UnreachableElse]: off.}
  case value.kind
  of vkString:
    ctx.buffer.addEscaped(value.strVal)
  of vkInt:
    ctx.buffer.add($value.intVal)
  of vkFloat:
    ctx.buffer.add($value.floatVal)
  of vkBool:
    ctx.buffer.add(if value.boolVal: "true" else: "false")
  of vkList:
    ctx.renderList(value)
  of vkObject:
    ctx.renderObject(value)
  else:
    when defined(yumlyEnv):
      if value.kind == vkEnv:
        ctx.buffer.add('"')
        ctx.buffer.addEscaped(value.envVal)
        ctx.buffer.add('"')
  when not defined(yumlyEnv):
    {.pop.}

func renderPair(ctx: var RenderCtx, pair: Pair) =
  ## Renders a `key (type) -> value`, expanding composite values below it.
  ctx.beginLine()
  ctx.buffer.add(pair.key)
  ctx.buffer.add(" (")
  ctx.buffer.add(formatTypeHint(pair.typeHint, pair.value))
  ctx.buffer.add(") -> ")
  ctx.renderValue(pair.value)

func renderBlock(ctx: var RenderCtx, blk: Block) =
  ctx.beginLine()
  ctx.buffer.add("[")
  ctx.buffer.add(blk.name)
  ctx.buffer.add("] (")

  if blk.items.len == 0:
    ctx.buffer.add(")")
    return

  inc ctx.indent
  for item in blk.items:
    ctx.renderItem(item)
  dec ctx.indent
  ctx.beginLine()
  ctx.buffer.add(")")

func renderItem(ctx: var RenderCtx, item: Item) =
  case item.kind
  of ikPair:
    ctx.renderPair(item.pair)
  of ikValue:
    ctx.beginLine()
    ctx.renderValue(item.value)
  of ikBlock:
    ctx.renderBlock(item.blk)
  of ikSchema:
    raise newException(ValueError, "a schema cannot be encoded inside a value")

func toYumyumy*(config: YumlyConf): string =
  ## Converts an evaluated Yumly config into the YumYumy display format.
  var ctx = RenderCtx(indent: 0)

  ctx.emit("[")
  inc ctx.indent

  for item in config.items:
    case item.kind
    of ikPair:
      renderPair(ctx, item.pair)
    of ikBlock:
      renderBlock(ctx, item.blk)
    of ikValue, ikSchema:
      discard

  dec ctx.indent
  ctx.emit("]")

  return ctx.buffer
