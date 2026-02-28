import os
import std/terminal
import src/Yumly/libyumly

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

proc checkCommand(content: string): bool =
    if fileExists(content):
        info("Validating file...")
        result = validateFile(content)
    else:
        info("Validating content...")
        result = validateContent(content)

proc loadCommand(path: string): auto =
  loadYumly(path)

proc parseOutput() =
    let args = commandLineParams()

    if args.len < 2:
        error("usage: yumly <check|load> <file|content>")
        return

    let cmd = args[0]
    let value = args[1]

    try:
        case cmd
        of "check":
            if checkCommand(value):
                success("Check passed ✔")
            else:
                error("Check failed ✖")
        of "load":
            let data = loadCommand(value)
            echo data
            success("File loaded ✔")
        else:
            error("Unknown command: " & cmd)
    except CatchableError as err:
        error(err.msg)

parseOutput()