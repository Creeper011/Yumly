import std/strutils
import ../../yumly/libyumly
import ../../yumly/types/[nodes, token]

when defined(yumlyJson):
  import std/json

when not defined(yumlyJson) or not defined(yumlyYaml):
  import ./display
  import ./cli_errors

type OutputFormat* = enum
  ofmtYumyumy, # Default
  ofmtYumly,   # -yu
  ofmtJson,    # -j / --json
  ofmtYaml     # -ya / --yaml

proc formatTokens*(res: PipelineResult): string =
  var tokens: seq[string] = @[]
  for token in res.tokens:
    tokens.add($token)
  tokens.join("\n")

proc formatNodes*(res: PipelineResult): string =
  var nodes: seq[string] = @[]
  for node in res.nodes:
    nodes.add($node)
  nodes.join("")

proc formatResult*(res: PipelineResult, format: OutputFormat = ofmtYumyumy): string =
  case res.stage
  of psTokenizer:
    return formatTokens(res)
  of psParser, psIncludes, psResolver:
    return formatNodes(res)
  of psEvaluator, psValidator:
    case format
    of ofmtJson:
      when defined(yumlyJson):
        return $toJson(res.config)
      else:
        cliError(cliMessage(
          "Ehhh... JSON support was not enabled at compile time! (>_<)",
          "JSON support was not enabled at compile time"), ceFormatDisabled)
        info("hint: recompile with -d:yumlyJson")
        quit(1)
    of ofmtYaml:
      when defined(yumlyYaml):
        return toYaml(res.config)
      else:
        cliError(cliMessage(
          "Ehhh... YAML support was not enabled at compile time! (>_<)",
          "YAML support was not enabled at compile time"), ceFormatDisabled)
        info("hint: recompile with -d:yumlyYaml")
        quit(1)
    of ofmtYumly:
      return dumpYumly(res.config)
    of ofmtYumyumy:
      return toYumyumy(res.config)
