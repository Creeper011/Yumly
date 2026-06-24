import os
import ../../error_messages

const YumlySandboxDir* {.strdefine.} = "~"

proc getCanonicalPath*(rawPath: string, baseDir: string, line,
    col: int): string =
  ## Resolves symlinks and returns an absolute, normalized path.
  let absoluteBase = if isAbsolute(baseDir): baseDir else: absolutePath(baseDir)
  let combined = if isAbsolute(rawPath): rawPath
                 else: normalizedPath(absoluteBase / rawPath)

  try:
    result = os.expandFilename(combined)
  except OSError:
    includeFileNotFoundError(rawPath, combined, line, col)

proc checkSandbox*(resolvedPath: string, line, col: int) =
  when YumlySandboxDir != "":
    let canonSandbox = expandFilename(expandTilde(YumlySandboxDir))
    if not resolvedPath.isRelativeTo(canonSandbox):
      sandboxDirViolationError(resolvedPath, canonSandbox, line, col)
