import os
import ../../errors/exceptions/parser/ioerrors
import ../../types/source

const YumlySandboxDir* {.strdefine.} = "~"

proc getCanonicalPath*(rawPath: string, baseDir: string,
    source: SourceSpan): string =
  ## Resolves symlinks and returns an absolute, normalized path.
  let absoluteBase = if isAbsolute(baseDir): baseDir else: absolutePath(baseDir)
  let combined = if isAbsolute(rawPath): rawPath
                 else: normalizedPath(absoluteBase / rawPath)

  try:
    result = os.expandFilename(combined)
  except OSError:
    includeFileNotFoundError(rawPath, combined, source)

proc checkSandbox*(resolvedPath: string, source: SourceSpan) =
  when YumlySandboxDir != "":
    let canonSandbox = expandFilename(expandTilde(YumlySandboxDir))
    if not resolvedPath.isRelativeTo(canonSandbox):
      sandboxDirViolationError(resolvedPath, canonSandbox, source)
