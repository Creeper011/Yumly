import ../tokenizer, ../parser, ../additional/validate
import ../types/ast
import ../yumly_file

const wireVersionHeader = "YUMLY1"

proc encodeString(buf: var string, s: string) =
  buf.add("S")
  buf.add($(s.len))
  buf.add(":")
  buf.add(s)

proc encodeInt(buf: var string, i: int) =
  let s = $i
  buf.add("I")
  buf.add($(s.len))
  buf.add(":")
  buf.add(s)

proc encodeFloat(buf: var string, f: float) =
  let s = $f
  buf.add("F")
  buf.add($(s.len))
  buf.add(":")
  buf.add(s)

proc encodeBool(buf: var string, b: bool) =
  buf.add("B")
  buf.add(if b: "1" else: "0")

proc encodeValue(buf: var string, value: Value)

proc encodeBlock(buf: var string, blk: Block) =
  let count = blk.pairs.len + blk.subBlocks.len
  buf.add("M")
  buf.add($(count))
  buf.add("{")
  for pair in blk.pairs:
    encodeString(buf, pair.key)
    encodeValue(buf, pair.value)
  for sub in blk.subBlocks:
    encodeString(buf, sub.name)
    encodeBlock(buf, sub)
  buf.add("}")

proc encodeConfig(buf: var string, config: Config) =
  buf.add("M")
  buf.add($(config.blocks.len))
  buf.add("{")
  for blk in config.blocks:
    encodeString(buf, blk.name)
    encodeBlock(buf, blk)
  buf.add("}")

proc encodeValue(buf: var string, value: Value) =
  case value.kind
  of vkString:
    encodeString(buf, value.str)
  of vkInt:
    encodeInt(buf, value.intVal)
  of vkFloat:
    encodeFloat(buf, value.floatVal)
  of vkBool:
    encodeBool(buf, value.boolVal)
  of vkEnv:
    encodeString(buf, value.envVal)

proc parseConfigYUMLYstruct*(path: string): string =
  try:
    checkFileExtension(path)
    let content = openFileContent(path)
    let tokens  = tokenize(content)
    var config  = generateAST(tokens)
    validateConfig(config)
    var buf = wireVersionHeader & " "
    encodeConfig(buf, config)
    return buf
  except CatchableError as e:
    let msg = e.msg
    return "ERR" & $(msg.len) & ":" & msg