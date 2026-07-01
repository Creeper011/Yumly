## Type hints used by the parser, resolver, validator, and serializers.
import source

when defined(yumlyEnv):
  type TypeHintKind* = enum
    thUnknown, thString, thInt, thFloat, thBool, thEnv, thList
else:
  type TypeHintKind* = enum
    thUnknown, thString, thInt, thFloat, thBool, thList

type
  TypeHint* = object
    raw*: string
    line*: SourcePos
    col*: SourcePos
    case kind*: TypeHintKind
    of thList:
      elementKind*: TypeHintKind
      elementRaw*: string
    else: discard
