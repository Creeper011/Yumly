## File and include I/O diagnostic raises.

import ../../../types/[errors, source]
import ../../../utils/loc
import ../../common

func failedToLoadFile*(path: string, span: SourceSpan, error: string) =
  raise newYumlyIOError(
      yumlyDetailedMessage(ecIncludeLoadFailed,
      "Uhh... something went wrong while loading the " & path &
      " file! (>_<)\n" &
      "  file: '" & path & "'\n" &
      loc(span.line, span.col) & "\n" &
      "  detail: " & error,
      span.line, span.col),
      ecIncludeLoadFailed,
      @[span]
  )

func invalidFileExtensionError*(path: string) =
  raise newYumlyIOError(
      yumlyMessage(ecFileInvalidExtension,
      "Mmm, that file isn't mine! :< You named it as: '" & path &
      "'. I can only read files with .yumly, .yuy or .yu extension",
      SourcePos(0), SourcePos(0)),
      ecFileInvalidExtension,
      @[sourceSpan(SourceFile(path: path), SourcePos(0), SourcePos(0))])

func fileNotFoundError*(filePath: string) =
  raise newYumlyIOError(
      yumlyDetailedMessage(ecFileNotFound,
      "Heeeh?! I can't find the file anywhere... (T_T)\nI searched for: " &
      filePath &
      "\nHave you tried checking if the file path is correct?",
      SourcePos(0), SourcePos(0)),
      ecFileNotFound,
      @[sourceSpan(SourceFile(path: filePath), SourcePos(0), SourcePos(0))])

func fileTooLargeError*(path: string, fileSize: int64, limit: int) =
  raise newYumlyIOError(
      yumlyMessage(ecFileTooLarge,
      "Heeeh?! the file '" & path & "' is too large to parse! (" &
      $fileSize & " bytes, limit is " & $limit & " bytes) (>_<)",
      SourcePos(0), SourcePos(0)),
      ecFileTooLarge,
      @[sourceSpan(SourceFile(path: path), SourcePos(0), SourcePos(0))])

func couldNotOpenFileError*(path: string) =
  raise newYumlyIOError(
      yumlyMessage(ecFileOpenFailed, "AHHH, Could not open file: " & path,
      SourcePos(0), SourcePos(0)), ecFileOpenFailed,
      @[sourceSpan(SourceFile(path: path), SourcePos(0), SourcePos(0))])

func circularIncludeError*(path: string, span: SourceSpan) =
  raise newYumlyIOError(
      yumlyDetailedMessage(ecIncludeCircularImport,
      "Circular include detected! '" & path & "' is already being loaded\n" &
      loc(span.line, span.col),
      span.line, span.col),
      ecIncludeCircularImport, @[span])

func includeFileNotFoundError*(rawPath: string, absPath: string,
    span: SourceSpan) =
  raise newYumlyIOError(
      yumlyDetailedMessage(ecIncludeNotFound,
      "Heeeh?! i can't find '" & rawPath & "' anywhere... (T_T)\n" &
      "  searched at: " & absPath & "\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: check if the path is correct and the file actually exists",
      span.line, span.col),
      ecIncludeNotFound, @[span])

func dotenvIncludeDisabledError*(path: string, span: SourceSpan) =
  raise newYumlyError(
      yumlyDetailedMessage(ecIncludeDotenvDisabled,
      "Ehhh... .env includes are disabled in this Yumly build! >_<\n" &
      "  file: '" & path & "'\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: compile with -d:yumlyEnv -d:yumlyDotenv to enable include { \".env\" }.",
      span.line, span.col),
      ecIncludeDotenvDisabled, @[span])

func sandboxDirViolationError*(path: string, sandboxDir: string,
    span: SourceSpan) =
  raise newYumlyIOError(
      yumlyDetailedMessage(ecIncludeSandboxViolation,
      "Heeeh?! Security violation! Access to '" & path & "' is denied!\n" &
      "  sandbox dir: " & sandboxDir & "\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: includes must be within the sandbox directory",
      span.line, span.col),
      ecIncludeSandboxViolation, @[span])

func includeUnsupportedExtError*(filePath: string, ext: string,
    span: SourceSpan) =
  raise newYumlyError(
      yumlyDetailedMessage(ecIncludeUnsupportedExtension,
      "Mmm, this file type isn't supported in include { \"\" } ;-; \n" &
      "  file: '" & filePath & "'\n" &
      "  got type: '" & ext & "'\n" &
      loc(span.line, span.col) & "\n" &
      "  hint: include only .env, .yumly, .yuy or .yu files",
      span.line, span.col),
      ecIncludeUnsupportedExtension, @[span])
