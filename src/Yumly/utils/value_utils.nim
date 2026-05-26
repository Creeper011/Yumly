import std/options
import ../types/[ast, type_hints]

func isHeterogeneous*(elements: seq[Value]): bool =
  if elements.len == 0: return false
  let first = elements[0].kind
  for el in elements:
    if el.kind != first: return true
  false

func isHomogeneous*(elements: seq[Value]): bool =
  not isHeterogeneous(elements)

func inferTypeHintRaw*(val: Value): string
func inferTypeHintKind*(val: Value): TypeHintKind

func inferListElementKind*(val: Value): TypeHintKind =
  if val.kind == vkList and val.elements.len > 0:
    return inferTypeHintKind(val.elements[0])
  thString

func inferListElementRaw*(val: Value): string =
  if val.kind == vkList and val.elements.len > 0:
    return inferTypeHintRaw(val.elements[0])
  "string"

func inferTypeHintRaw*(val: Value): string =
  case val.kind
  of vkString: return "string"
  of vkInt: return "int"
  of vkFloat: return "float"
  of vkBool: return "bool"
  of vkList:
    return "list[" & inferListElementRaw(val) & "]"
  of vkTuple: return "tuple"
  of vkEnv: return "env"

func inferTypeHintKind*(val: Value): TypeHintKind =
  case val.kind
  of vkString: return thString
  of vkInt: return thInt
  of vkFloat: return thFloat
  of vkBool: return thBool
  of vkList: return thList
  of vkTuple: return thTuple
  of vkEnv: return thEnv

func inferTypeHintObject*(val: Value): TypeHint =
  let raw = inferTypeHintRaw(val)
  case val.kind
  of vkList:
    TypeHint(
      raw: raw,
      kind: thList,
      elementKind: inferListElementKind(val),
      elementRaw: inferListElementRaw(val)
    )
  else:
    TypeHint(raw: raw, kind: inferTypeHintKind(val))

func inferArrayKind*(elements: seq[Value], hint: Option[TypeHint] = none(TypeHint)): ValueKind =
  if hint.isSome:
    case hint.get.kind
    of thTuple: return vkTuple
    of thList: return vkList
    else: discard

  if isHeterogeneous(elements): vkTuple else: vkList

func inferArrayValue*(elements: seq[Value], hint: Option[TypeHint] = none(TypeHint)): Value =
  case inferArrayKind(elements, hint)
  of vkTuple: Value(kind: vkTuple, elements: elements)
  else: Value(kind: vkList, elements: elements)

proc ensureInferredTypeHint*(pair: var Pair) =
  if pair.typeHint.isNone:
    pair.typeHint = some(inferTypeHintObject(pair.value))

proc applyInferredTypeHints*(pairs: var seq[Pair]) =
  for pair in pairs.mitems:
    ensureInferredTypeHint(pair)

proc applyInferredTypeHints*(blocks: var seq[Block]) =
  for blk in blocks.mitems:
    applyInferredTypeHints(blk.pairs)
    applyInferredTypeHints(blk.subBlocks)

proc applyInferredTypeHints*(config: var YumlyConf) =
  applyInferredTypeHints(config.pairs)
  applyInferredTypeHints(config.blocks)
