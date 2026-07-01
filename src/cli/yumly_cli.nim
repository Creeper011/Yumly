import std/[os, strutils]
import ../yumly/libyumly
import ../yumly/types/errors
import src/display
import src/display_errors
import src/format
import src/help
import src/cli_errors

when defined(yumlycliCute):
  {.compile: "random_message.c".}

  proc randomMessage(): cstring {.importc: "random_message".}

proc failArgument(code: CliErrorCode, cuteMessage, plainMessage: string) =
  cliError(cliMessage(cuteMessage, plainMessage), code)
  quit(1)

proc requireLoadOption(command, option: string) =
  if command != "load":
    failArgument(
      ceOptionCommandMismatch,
      "Ehhh... '" & option & "' only belongs to load! >_<",
      "Option " & option & " is only valid for the load command")

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

proc loadCommand*(content: string, until: PipelineStage): PipelineResult =
  if fileExists(content):
    loadYumly(content, until)
  else:
    info("Loading it as a content .")
    loadYumlyContent(content, until)

proc consumeCommand(content: string, until: PipelineStage) =
  if fileExists(content):
    consumeYumly(content, until)
  else:
    consumeYumlyContent(content, until)

proc runCli*(args: seq[string] = commandLineParams()) =
  if args.len == 0:
    printHelp()
    return

  if args[0] in ["help", "-h", "--help"]:
    if args.len == 1:
      printHelp()
    elif args[1] in ["load", "check"]:
      printHelp(args[1])
    else:
      failArgument(
        ceUnknownHelpTopic,
        "Ehhh... i don't have help for '" & args[1] & "' >_<",
        "Unknown help topic: " & args[1])
    return

  let cmd = args[0]
  if cmd notin ["check", "load"]:
    failArgument(
      ceUnknownCommand,
      "Heyy!! i don't know the command '" & cmd & "' >_<",
      "Unknown command: " & cmd)

  if args.len < 2:
    failArgument(
      ceMissingInput,
      "Ehhh... what am i supposed to " & cmd & "? >_<",
      "Missing file or content for command: " & cmd)

  let value = args[1]
  let fallbackSourcePath = if fileExists(value): value else: ""
  let fallbackSourceContent = if fallbackSourcePath.len == 0: value else: ""
  var untilStage = psValidator
  var format = ofmtYumyumy
  var renderOutput = true
  var showSuccess = true

  var i = 2
  while i < args.len:
    case args[i]
    of "-h", "--help":
      printHelp(cmd)
      return
    of "-u", "--until":
      requireLoadOption(cmd, args[i])
      inc i
      if i >= args.len or args[i].startsWith("-"):
        failArgument(
          ceMissingStage,
          "Heyy!! --until needs a pipeline stage! >_<",
          "Missing pipeline stage after --until")
      if args[i] notin ["T", "P", "LI", "R", "E", "V"]:
        failArgument(
          ceUnknownStage,
          "Stage '" & args[i] & "' doesn't exist, silly :3",
          "Unknown pipeline stage: " & args[i])
      untilStage = parseStage(args[i])
    of "-yu", "--yumly":
      requireLoadOption(cmd, args[i])
      format = ofmtYumly
    of "-j", "--json":
      requireLoadOption(cmd, args[i])
      format = ofmtJson
    of "-ya", "--yaml":
      requireLoadOption(cmd, args[i])
      format = ofmtYaml
    of "--no-output":
      requireLoadOption(cmd, args[i])
      renderOutput = false
    of "-q", "--quiet":
      requireLoadOption(cmd, args[i])
      renderOutput = false
      showSuccess = false
    else:
      failArgument(
        ceUnknownOption,
        "Oh... what is '" & args[i] & "'? i don't know her (ㆆ_ㆆ)",
        "Unknown option: " & args[i])
    inc i

  try:
    case cmd
    of "check":
      checkCommand(value)
      checked()
    of "load":
      if renderOutput:
        let result = loadCommand(value, untilStage)
        echo formatResult(result, format)
      else:
        consumeCommand(value, untilStage)
      if showSuccess:
        when defined(yumlycliCute):
          loaded($randomMessage())
        else:
          loaded()

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
