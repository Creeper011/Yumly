
type
  TypeHintKind* = enum thUnknown, thString, thInt, thFloat, thBool, thEnv, thList, thTuple

  TypeHint* = object
    raw*: string
    line*: int
    col*: int
    case kind*: TypeHintKind
    of thList:
      elementKind*: TypeHintKind
      elementRaw*: string
    else: discard