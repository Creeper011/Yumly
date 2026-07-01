import os, dotenv
import ../../errors/exceptions/parser/ioerrors
import ../../types/source

proc loadEnvFile*(resolvedPath: string, source: SourceSpan) =
  try:
    let sfEnv = os.splitFile(resolvedPath)
    let envDir = if sfEnv.dir.len == 0: "." else: sfEnv.dir
    let envFile = sfEnv.name & sfEnv.ext
    load(envDir, envFile)
  except CatchableError as error:
    failedToLoadFile(resolvedPath, source, error.msg)
