
type
  # NOTE: tkUnknown is for if the type hint is absent
  TypeHintKind* = enum thUnknown, thString, thInt, thFloat, thBool, thEnv, thList

  TypeHint* = object
    raw*: string
    line*: int
    col*: int
    case kind*: TypeHintKind
    of thList:
      elementKind*: TypeHintKind
      elementRaw*: string
    else: discard
