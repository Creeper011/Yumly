## Stable, read-only C interface for evaluated Yumly documents.
##
## Documents and errors are owned handles. Values are borrowed from a document
## and remain valid until that document is freed.

import ../../core/pipeline
import ../../types/[ast, errors, source]
import ../../errors/codes

type
  CStatus = enum
    csOk = 0
    csInvalidArgument = 1
    csIo = 2
    csParse = 3
    csNotFound = 4
    csType = 5
    csRange = 6
    csInternal = 7

  CValueKind = enum
    cvInvalid = 0
    cvString = 1
    cvInt = 2
    cvFloat = 3
    cvBool = 4
    cvList = 5
    cvObject = 6

  CField = object
    name: string
    value: CValue

  CValue = ref object
    case kind: CValueKind
    of cvString:
      stringValue: string
    of cvInt:
      intValue: int64
    of cvFloat:
      floatValue: float64
    of cvBool:
      boolValue: bool
    of cvList:
      elements: seq[CValue]
    of cvObject:
      fields: seq[CField]
    of cvInvalid:
      discard

  CDocument = ref object
    root: CValue

  CError = ref object
    message: string
    code: string
    path: string
    line: uint64
    column: uint64

proc toCValue(value: Value): CValue

proc objectFromItems(items: openArray[Item]): CValue =
  result = CValue(kind: cvObject, fields: @[])
  for item in items:
    case item.kind
    of ikPair:
      result.fields.add(CField(name: item.pair.key,
          value: toCValue(item.pair.value)))
    of ikBlock:
      if not item.blk.isNil:
        result.fields.add(CField(name: item.blk.name,
            value: objectFromItems(item.blk.items)))
    of ikValue, ikSchema:
      discard

{.push warning[UnreachableElse]: off.}
proc toCValue(value: Value): CValue =
  case value.kind
  of vkString:
    result = CValue(kind: cvString, stringValue: value.strVal)
  of vkInt:
    result = CValue(kind: cvInt, intValue: int64(value.intVal))
  of vkFloat:
    result = CValue(kind: cvFloat, floatValue: float64(value.floatVal))
  of vkBool:
    result = CValue(kind: cvBool, boolValue: value.boolVal)
  of vkList:
    result = CValue(kind: cvList, elements: @[])
    for item in value.elements:
      case item.kind
      of ikValue:
        result.elements.add(toCValue(item.value))
      of ikPair:
        result.elements.add(toCValue(item.pair.value))
      of ikBlock:
        if not item.blk.isNil:
          result.elements.add(objectFromItems(item.blk.items))
      of ikSchema:
        discard
  of vkObject:
    result = objectFromItems(value.items)
  else:
    when defined(yumlyEnv):
      result = CValue(kind: cvString, stringValue: value.envVal)
{.pop.}

proc primarySpan(error: ref Exception): SourceSpan =
  if error of YumlyError:
    let yumlyError = cast[ref YumlyError](error)
    if yumlyError.source.len > 0:
      return yumlyError.source[0]
  elif error of YumlyIOError:
    let ioError = cast[ref YumlyIOError](error)
    if ioError.source.len > 0:
      return ioError.source[0]

proc errorCode(error: ref Exception): string =
  if error of YumlyError:
    $cast[ref YumlyError](error).code
  elif error of YumlyIOError:
    $cast[ref YumlyIOError](error).code
  else:
    "internal"

proc newCError(error: ref Exception): CError =
  let span = primarySpan(error)
  result = CError(message: error.msg, code: errorCode(error),
      line: uint64(span.line), column: uint64(span.col))
  if not span.source.isNil:
    result.path = span.source.path
  GC_ref(result)

proc setError(output: ptr pointer, error: ref Exception) =
  if output != nil:
    output[] = cast[pointer](newCError(error))

proc clearErrorOutput(output: ptr pointer) =
  if output != nil:
    output[] = nil

proc statusFor(error: ref Exception): CStatus =
  if error of IOError: csIo
  elif error of ValueError: csParse
  else: csInternal

{.push cdecl.}
proc yumlyDocumentLoadFile(path: cstring, output: ptr pointer,
    errorOutput: ptr pointer): cint {.exportc: "yumly_document_load_file", dynlib.} =
  clearErrorOutput(errorOutput)
  if path == nil or output == nil:
    return cint(csInvalidArgument)
  output[] = nil
  try:
    let config = loadYumly($path)
    let document = CDocument(root: objectFromItems(config.items))
    GC_ref(document)
    output[] = cast[pointer](document)
    cint(csOk)
  except CatchableError as error:
    setError(errorOutput, error)
    cint(statusFor(error))

proc yumlyAbiVersion(): uint32 {.exportc: "yumly_abi_version", dynlib.} =
  1'u32

proc yumlyDocumentLoadContent(content, workingDir: cstring,
    output: ptr pointer, errorOutput: ptr pointer): cint {.
    exportc: "yumly_document_load_content", dynlib.} =
  clearErrorOutput(errorOutput)
  if content == nil or output == nil:
    return cint(csInvalidArgument)
  output[] = nil
  try:
    let directory = if workingDir == nil: "." else: $workingDir
    let config = loadYumlyContent($content, directory)
    let document = CDocument(root: objectFromItems(config.items))
    GC_ref(document)
    output[] = cast[pointer](document)
    cint(csOk)
  except CatchableError as error:
    setError(errorOutput, error)
    cint(statusFor(error))

proc yumlyDocumentFree(document: pointer) {.
    exportc: "yumly_document_free", dynlib.} =
  if document != nil:
    GC_unref(cast[CDocument](document))

proc yumlyDocumentRoot(document: pointer): pointer {.
    exportc: "yumly_document_root", dynlib.} =
  if document == nil:
    return nil
  cast[pointer](cast[CDocument](document).root)

proc yumlyValueKind(value: pointer): cint {.
    exportc: "yumly_value_kind", dynlib.} =
  if value == nil:
    return cint(cvInvalid)
  cint(cast[CValue](value).kind)

proc yumlyObjectGet(objectValue: pointer, key: cstring,
    output: ptr pointer): cint {.exportc: "yumly_object_get", dynlib.} =
  if objectValue == nil or key == nil or output == nil:
    return cint(csInvalidArgument)
  output[] = nil
  let value = cast[CValue](objectValue)
  if value.kind != cvObject:
    return cint(csType)
  for field in value.fields:
    if field.name == $key:
      output[] = cast[pointer](field.value)
      return cint(csOk)
  cint(csNotFound)

proc yumlyListSize(listValue: pointer, output: ptr csize_t): cint {.
    exportc: "yumly_list_size", dynlib.} =
  if listValue == nil or output == nil:
    return cint(csInvalidArgument)
  let value = cast[CValue](listValue)
  if value.kind != cvList:
    return cint(csType)
  output[] = csize_t(value.elements.len)
  cint(csOk)

proc yumlyListGet(listValue: pointer, index: csize_t,
    output: ptr pointer): cint {.exportc: "yumly_list_get", dynlib.} =
  if listValue == nil or output == nil:
    return cint(csInvalidArgument)
  output[] = nil
  let value = cast[CValue](listValue)
  if value.kind != cvList:
    return cint(csType)
  if uint64(index) >= uint64(value.elements.len):
    return cint(csRange)
  output[] = cast[pointer](value.elements[int(index)])
  cint(csOk)

proc yumlyValueGetString(valuePointer: pointer, output: ptr cstring,
    length: ptr csize_t): cint {.exportc: "yumly_value_get_string", dynlib.} =
  if valuePointer == nil or output == nil:
    return cint(csInvalidArgument)
  let value = cast[CValue](valuePointer)
  if value.kind != cvString:
    return cint(csType)
  output[] = value.stringValue.cstring
  if length != nil:
    length[] = csize_t(value.stringValue.len)
  cint(csOk)

proc yumlyValueGetInt(valuePointer: pointer, output: ptr int64): cint {.
    exportc: "yumly_value_get_int", dynlib.} =
  if valuePointer == nil or output == nil:
    return cint(csInvalidArgument)
  let value = cast[CValue](valuePointer)
  if value.kind != cvInt:
    return cint(csType)
  output[] = value.intValue
  cint(csOk)

proc yumlyValueGetFloat(valuePointer: pointer, output: ptr float64): cint {.
    exportc: "yumly_value_get_float", dynlib.} =
  if valuePointer == nil or output == nil:
    return cint(csInvalidArgument)
  let value = cast[CValue](valuePointer)
  if value.kind != cvFloat:
    return cint(csType)
  output[] = value.floatValue
  cint(csOk)

proc yumlyValueGetBool(valuePointer: pointer, output: ptr cint): cint {.
    exportc: "yumly_value_get_bool", dynlib.} =
  if valuePointer == nil or output == nil:
    return cint(csInvalidArgument)
  let value = cast[CValue](valuePointer)
  if value.kind != cvBool:
    return cint(csType)
  output[] = if value.boolValue: 1 else: 0
  cint(csOk)

proc yumlyErrorMessage(error: pointer): cstring {.
    exportc: "yumly_error_message", dynlib.} =
  if error == nil: nil else: cast[CError](error).message.cstring

proc yumlyErrorCode(error: pointer): cstring {.
    exportc: "yumly_error_code", dynlib.} =
  if error == nil: nil else: cast[CError](error).code.cstring

proc yumlyErrorPath(error: pointer): cstring {.
    exportc: "yumly_error_path", dynlib.} =
  if error == nil: nil else: cast[CError](error).path.cstring

proc yumlyErrorLine(error: pointer): uint64 {.
    exportc: "yumly_error_line", dynlib.} =
  if error == nil: 0'u64 else: cast[CError](error).line

proc yumlyErrorColumn(error: pointer): uint64 {.
    exportc: "yumly_error_column", dynlib.} =
  if error == nil: 0'u64 else: cast[CError](error).column

proc yumlyErrorFree(error: pointer) {.exportc: "yumly_error_free", dynlib.} =
  if error != nil:
    GC_unref(cast[CError](error))
{.pop.}
