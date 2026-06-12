import ../src/Yumly/libyumly
import ../src/Yumly/types/nodes
import ../src/Yumly/types/token
import ../src/Yumly/phases/tokenizer/tokenizer
import std/[terminal, os, strutils, streams]

when defined(yumlyJson):
    import std/json

template info(msg: string) =
    setForegroundColor(fgYellow)
    echo msg
    resetAttributes()

template success(msg: string) =
    setForegroundColor(fgGreen)
    echo msg
    resetAttributes()

template error(msg: string) =
    setForegroundColor(fgRed)
    echo msg
    resetAttributes()

func parseStage(stage: string): PipelineStage =
    case stage
    of "T": psTokenizer
    of "P": psParser
    of "LI": psIncludes
    of "R": psResolver
    of "V": psValidator
    of "E": psEvaluator
    else: psEvaluator

proc checkCommand(content: string): bool =
    if fileExists(content):
        info("Validating file...")
        result = validateFile(content)
    else:
        info("Validating content...")
        result = validateContent(content)

type OutputFormat = enum
    ofmtYumyumy,   # Default
    ofmtYumly,     # -y
    ofmtJson,      # -j / --json
    ofmtYaml       # --yaml

proc tokenizeCommand(content: string): string =
    let src = if fileExists(content): readFile(content) else: content
    let stream = newStringStream(src)
    let puller = tokenize(stream)
    var tokens: seq[string] = @[]
    while true:
        let token = puller()
        tokens.add($token)
        if token.kind == tkEOF: break
    stream.close()
    tokens.join("\n")

proc loadCommand(content: string, until: PipelineStage, format: OutputFormat = ofmtYumyumy): string =
    if until == psTokenizer:
        return tokenizeCommand(content)

    let res = if fileExists(content):
        loadYumly(content, until)
    else:
        loadYumlyContent(content, until)
    case res.stage
    of psParser, psIncludes, psResolver, psValidator:
        return $res.ast
    of psEvaluator:
        case format
        of ofmtJson:
            when defined(yumlyJson):
                return $toJson(res.config)
            else:
                error("Ehhh... JSON support was not enabled at compile time! (>_<)")
                info("hint: recompile with -d:yumlyJson")
                quit(1)
        of ofmtYaml:
            when defined(yumlyYaml):
                return toYaml(res.config)
            else:
                error("Ehhh... YAML support was not enabled at compile time! (>_<)")
                info("hint: recompile with -d:yumlyYaml")
                quit(1)
        of ofmtYumly:
            return dumpYumly(res.config)
        of ofmtYumyumy:
            return toYumyumy(res.config)
    else:
        return $res.stage & " finished"

proc parseOutput() =
    let args = commandLineParams()

    if args.len < 2:
        error("usage: yumly-cli <check|load> <file|content> [-u <stage>] [-y] [-j] [--yaml]")
        quit(1)

    let cmd = args[0]
    let value = args[1]
    var untilStage = psEvaluator
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
            if checkCommand(value):
                success("Check passed ✔")
            else:
                error("Check failed ✖")
                quit(1)
        of "load":
            let data = loadCommand(value, untilStage, format)
            echo data
            success("File loaded ✔")
        else:
            error("Unknown command: " & cmd)
            quit(1)
    except CatchableError as err:
        error(err.msg)
        quit(1)

parseOutput()
