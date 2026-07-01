## Nim API/value/block/conf diagnostic raises.

func iteratorNonListError*() =
  raise newException(ValueError, "Cannot iterate over non-list value")

func blockNotFoundError*(name: string) =
  raise newException(KeyError, "Block not found: " & name)

func subBlockNotFoundError*(name: string) =
  raise newException(KeyError, "Sub-block not found: " & name)

func cannotAddToNonListError*() =
  raise newException(IndexDefect, "Cannot add to a non-list value")

func expectedTypeError*(expected: string, got: string) =
  raise newException(ValueError, "I expected " & expected & ", got " & got)

func notListError*() =
  raise newException(IndexDefect, "This value isn't a list")

func keyNotFoundError*(key: string) {.noReturn.} =
  raise newException(KeyError, "I can't find '" & key & "' in the YumlyConf")

func keyNotFoundInBlockError*(key: string, blkName: string) {.noReturn.} =
  raise newException(KeyError, "I can't find '" & key & "' in the block '" &
      blkName & "'")

func cannotIndexValueWithStringError*(key: string) =
  raise newException(ValueError, "Cannot index a value with string: '" & key & "'")

func cannotIndexBlockWithIntegerError*(index: int) =
  raise newException(ValueError, "Cannot index a block with integer index: " & $index)

func cannotIndexValueWithIntegerError*(index: int) =
  raise newException(ValueError, "Cannot index a non-list value with integer index: " & $index)

func cannotIndexSchemaWithStringError*(key: string) =
  raise newException(ValueError, "Cannot index a schema with string: '" & key & "'")

func cannotIndexSchemaWithIntegerError*(index: int) =
  raise newException(ValueError, "Cannot index a schema with integer index: " & $index)
