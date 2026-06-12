import os, dotenv
import ../../error_messages

proc loadEnvFile*(resolvedPath: string, line, col: int) =
  try:
    let sfEnv = os.splitFile(resolvedPath)
    let envDir = if sfEnv.dir.len == 0: "." else: sfEnv.dir
    let envFile = sfEnv.name & sfEnv.ext
    load(envDir, envFile)
  except CatchableError as error:
    failedToLoadFile(resolvedPath, line, col, error.msg)
