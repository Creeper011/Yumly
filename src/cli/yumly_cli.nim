import std/os
import ../yumly/libyumly
import ../yumly/types/errors
import src/display
import src/display_errors
import src/format

func parseStage(stage: string): PipelineStage =
  case stage
  of "T": psTokenizer
  of "P": psParser
  of "LI": psIncludes
  of "R": psResolver
  of "V": psValidator
  of "E": psEvaluator
  else: psEvaluator

proc checkCommand*(content: string) =
  if fileExists(content):
    info("Validating file...")
    discard loadYumly(content)
    return

  info("Validating content...")
  discard loadYumlyContent(content)

proc loadCommand*(content: string, until: PipelineStage,
    format: OutputFormat = ofmtYumyumy): string =
  let res = if fileExists(content):
    loadYumly(content, until)
  else:
    loadYumlyContent(content, until)
  formatResult(res, format)

proc runCli*(args: seq[string] = commandLineParams()) =
  if args.len < 2:
    error("usage: yumly-cli <check|load> <file|content> [-u <stage>] [-yu] [-j] [--yaml]")
    quit(1)

  let cmd = args[0]
  let value = args[1]
  let fallbackSourcePath = if fileExists(value): value else: ""
  let fallbackSourceContent = if fallbackSourcePath.len == 0: value else: ""
  var untilStage = psValidator
  var format = ofmtYumyumy

  var i = 2
  while i < args.len:
    case args[i]
    of "-u", "--until":
      inc i
      if i < args.len:
        untilStage = parseStage(args[i])
    of "-yu", "--yumly":
      format = ofmtYumly
    of "-j", "--json":
      format = ofmtJson
    of "-ya", "--yaml":
      format = ofmtYaml
    else:
      error("Oh... unknown command: " & args[i])
      quit(1)
    inc i

  try:
    case cmd
    of "check":
      checkCommand(value)
      success("Check passed ✔")
    of "load":
      let data = loadCommand(value, untilStage, format)
      echo data
      success("File loaded ✔")
    else:
      error("Unknown command: " & cmd)
      quit(1)

  except YumlyError as err:
    printDiagnostic(err, fallbackSourcePath, fallbackSourceContent)
    quit(1)

  except YumlyIOError as err:
    printDiagnostic(err, fallbackSourcePath, fallbackSourceContent)
    quit(1)

  except CatchableError as err:
    error(err.msg)
    quit(1)

when isMainModule:
  runCli()
