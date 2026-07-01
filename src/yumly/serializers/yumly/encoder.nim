#
import std/[options, strutils]
import ../../types/[ast, typehints]

type
  EncoderCtx = object
    indent: int
    lines: seq[string]

const Indent = "  "

template pad(n: int): string =
  repeat(Indent, n)

template emit(ctx: var EncoderCtx, line: string) =
  ctx.lines.add(pad(ctx.indent) & line)

func addEscaped(buffer: var string, raw: string) =
  for ch in raw:
    case ch
    of '\n': buffer.add("\\n")
    of '\r': buffer.add("\\r")
    of '\t': buffer.add("\\t")
    of '\\': buffer.add("\\\\")
    of '"': buffer.add("\\\"")
    else: buffer.add(ch)

func addValue(buffer: var string, value: Value)
func addItem(buffer: var string, item: Item)

func addPairValue(buffer: var string, pair: Pair) =
  buffer.add(pair.key)
  if pair.typeHint.isSome:
    buffer.add(" ;")
    buffer.add(pair.typeHint.get.raw)
  buffer.add(" = ")
  buffer.addValue(pair.value)

func addBlockValue(buffer: var string, blk: Block) =
  buffer.add("(")
  buffer.add(blk.name)
  buffer.add(") {")
  for i, item in blk.items:
    if i > 0:
      buffer.add(", ")
    buffer.addItem(item)
  buffer.add("}")

func addObjectValue(buffer: var string, value: Value) =
  if value.schema.isSome:
    buffer.add("<")
    buffer.add(value.schema.get.name)
    buffer.add("> ")
  buffer.add("{")
  for i, item in value.items:
    if i > 0:
      buffer.add(", ")
    buffer.addItem(item)
  buffer.add("}")

func addItem(buffer: var string, item: Item) =
  case item.kind
  of ikPair:
    buffer.addPairValue(item.pair)
  of ikValue:
    buffer.addValue(item.value)
  of ikBlock:
    buffer.addBlockValue(item.blk)
  of ikSchema:
    raise newException(ValueError, "a schema cannot be encoded inside a value")

when defined(yumlyEnv):
  func addValue(buffer: var string, value: Value) =
    case value.kind
    of vkString:
      buffer.add('"'); buffer.addEscaped(value.strVal); buffer.add('"')
    of vkInt:
      buffer.add($value.intVal)
    of vkFloat:
      buffer.add($value.floatVal)
    of vkBool:
      buffer.add(if value.boolVal: "true" else: "false")
    of vkEnv:
      buffer.add("$[\""); buffer.add(value.envName); buffer.add("\"")
      if value.envDefault.isSome:
        buffer.add(" ?? \""); buffer.addEscaped(value.envDefault.get); buffer.add('"')
      buffer.add("]")
    of vkList:
      buffer.add("[")
      for i, item in value.elements:
        if i > 0: buffer.add(", ")
        buffer.addItem(item)
      buffer.add("]")
    of vkObject:
      buffer.addObjectValue(value)
else:
  func addValue(buffer: var string, value: Value) =
    case value.kind
    of vkString:
      buffer.add('"'); buffer.addEscaped(value.strVal); buffer.add('"')
    of vkInt:
      buffer.add($value.intVal)
    of vkFloat:
      buffer.add($value.floatVal)
    of vkBool:
      buffer.add(if value.boolVal: "true" else: "false")
    of vkList:
      buffer.add("[")
      for i, item in value.elements:
        if i > 0: buffer.add(", ")
        buffer.addItem(item)
      buffer.add("]")
    of vkObject:
      buffer.addObjectValue(value)

func formatTypeHint(hint: Option[TypeHint]): string =
  if hint.isSome:
    let h = hint.get
    if h.kind == thList and h.raw == "list" and h.elementRaw != "":
      return " ;list[" & h.elementRaw & "]"
    return " ;" & h.raw
  ""

func formatPair(pair: Pair): string =
  result = pair.key & formatTypeHint(pair.typeHint) & " = "
  result.addValue(pair.value)

func renderItems(ctx: var EncoderCtx, items: openArray[Item])

func renderSchemaFields(ctx: var EncoderCtx, fields: openArray[SchemaField]) =
  for field in fields:
    case field.kind
    of sfValue:
      var line = field.key & formatTypeHint(some(field.typeHint))
      if field.defaultValue.isSome:
        line.add(" = ")
        line.addValue(field.defaultValue.get)
      ctx.emit(line)
    of sfInlineBlock:
      ctx.emit(field.key & " ;blk" &
          (if field.required: " {" else: " = {"))
      inc ctx.indent
      ctx.renderSchemaFields(field.fields)
      dec ctx.indent
      ctx.emit("}")
    of sfTypedBlock:
      ctx.emit(field.key & " ;blk[" & field.valueType.raw & "]")

func renderBlock(ctx: var EncoderCtx, blk: Block) =
  ctx.emit("(" & blk.name & ") {")
  inc ctx.indent
  ctx.renderItems(blk.items)
  dec ctx.indent
  ctx.emit("}")

func renderSchema(ctx: var EncoderCtx, schema: Schema) =
  ctx.emit("[" & schema.name & "] {")
  inc ctx.indent
  ctx.renderSchemaFields(schema.fields)
  dec ctx.indent
  ctx.emit("}")

func renderItems(ctx: var EncoderCtx, items: openArray[Item]) =
  ## Every item is emitted on its own line, so Yumly's newline separator makes
  ## commas unnecessary. Iterating the single Item sequence preserves the exact
  ## relative order of pairs, blocks, schemas, and expanded include content.
  for item in items:
    case item.kind
    of ikPair:
      ctx.emit(formatPair(item.pair))
    of ikBlock:
      ctx.renderBlock(item.blk)
    of ikSchema:
      ctx.renderSchema(item.schema)
    of ikValue:
      raise newException(ValueError,
          "a standalone value cannot be serialized at configuration scope")

func dumpYumly*(config: YumlyConf): string =
  var ctx = EncoderCtx(indent: 0)

  # Include expansion can place an imported configuration item before a schema
  # declared later in the root file. A standalone Yumly document nevertheless
  # requires every schema before its configuration body, so serialize the type
  # namespace first while preserving order within each partition.
  for item in config.items:
    if item.kind == ikSchema:
      ctx.renderSchema(item.schema)

  for item in config.items:
    case item.kind
    of ikPair:
      ctx.emit(formatPair(item.pair))
    of ikBlock:
      ctx.renderBlock(item.blk)
    of ikSchema:
      discard
    of ikValue:
      raise newException(ValueError,
          "a standalone value cannot be serialized at configuration scope")

  ctx.lines.join("\n")
