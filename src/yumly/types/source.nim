## This defines how to interpret a source position in the Yumly configuration language :3
## As defined by -d:yumly32, the source change is to use integer values 32-bit instead of 64-bit.

when defined(yumly32):
    type SourcePos* = uint32 # NOTE: ~4gb file range
else:
    type SourcePos* = uint

type
  SourceFile* = ref object
    path*: string

  SourceSpan* = object
    source*: SourceFile
    line*: SourcePos
    col*: SourcePos
    endLine*: SourcePos
    endCol*: SourcePos

func sourceSpan*(source: SourceFile, line, col, endLine, endCol: SourcePos): SourceSpan =
  SourceSpan(source: source, line: line, col: col, endLine: endLine, endCol: endCol)

func sourceSpan*(source: SourceFile, line, col: SourcePos): SourceSpan =
  sourceSpan(source, line, col, line, col + SourcePos(1))
