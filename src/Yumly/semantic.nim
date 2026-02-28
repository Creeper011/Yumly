##
# Semantic helpers used by parser: literal classification and hint normalization.
##

import strutils, options
import types/ast
import types/token
import error_messages

proc normalizeTypeHint*(hint: TypeHint, line, col: int): TypeHint =
  ## Resolve hint names and apply defaults (no value inspection).
  let name = hint.raw.toLowerAscii()
  var kind = hint.kind
  if kind == thUnknown:
    case name
    of "string": kind = thString
    of "int":    kind = thInt
    of "float":  kind = thFloat
    of "bool":   kind = thBool
    of "env":    kind = thEnv
    of "list":   kind = thList
    of "tuple":  kind = thTuple
    else: unknownTypeHintError(hint.raw, line, col)

  if kind == thList:
    var elemKind = hint.elementKind
    var elemRaw = hint.elementRaw
    if elemKind == thUnknown and elemRaw.len > 0:
      case elemRaw.toLowerAscii()
      of "string": elemKind = thString
      of "int":    elemKind = thInt
      of "float":  elemKind = thFloat
      of "bool":   elemKind = thBool
      of "env":    elemKind = thEnv
      else: unknownTypeHintError(elemRaw, line, col)
    if elemKind == thUnknown:
      elemKind = thString
      elemRaw = "string"
    return TypeHint(kind: thList, raw: hint.raw, elementKind: elemKind, elementRaw: elemRaw)

  return TypeHint(kind: kind, raw: hint.raw)

proc literalToNode*(tok: Token): Option[YumNode] =
  ## Convert a literal token to a typed YumNode; return none for non-literals.
  case tok.kind
  of tkString:
    some(YumNode(kind: nkString, rawValue: tok.value, token: tok, line: tok.line, col: tok.col))
  of tkNumber:
    if '.' in tok.value or 'e' in tok.value or 'E' in tok.value:
      some(YumNode(kind: nkFloat, rawValue: tok.value, token: tok, line: tok.line, col: tok.col))
    else:
      some(YumNode(kind: nkInt, rawValue: tok.value, token: tok, line: tok.line, col: tok.col))
  of tkIdent:
    if tok.value == "true" or tok.value == "false":
      some(YumNode(kind: nkBool, boolVal: tok.value == "true", token: tok, line: tok.line, col: tok.col))
    else:
      none(YumNode)
  else:
    none(YumNode)
