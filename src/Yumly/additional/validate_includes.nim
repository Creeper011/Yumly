import os, strutils
import dotenv
import ../types/ast

const allowedIncludeExts = [".env"]

proc validateIncludes*(config: Config, errors: var seq[string]) =
    for incl in config.includes:
        if not os.fileExists(incl.includePath):
            errors.add(
                "Heeeh?! i can't find '" & incl.includePath & "' anywhere... (T_T)" &
                "\n  searched at: " & os.absolutePath(incl.includePath) &
                "\n  hint: check if the path is correct and the file actually exists"
            )
            continue

        # checks the file extension of env
        let sf = os.splitFile(incl.includePath)
        var ext = sf.ext.toLowerAscii()
        if ext.len == 0 and sf.name.toLowerAscii() == ".env":
            ext = ".env"
        if ext notin allowedIncludeExts:
            errors.add(
                "Mmm, this file type isn't supported in include { } ;-;" &
                "\n  file: '" & incl.includePath & "'" &
                "\n  got type: '" & ext & "'" &
                "\n  hint: only " & allowedIncludeExts.join(", ") & " files are supported for now"
            )
            continue

        if ext == ".env":
            try:
                let sfEnv   = os.splitFile(incl.includePath)
                let envDir  = if sfEnv.dir.len == 0: "." else: sfEnv.dir
                let envFile = sfEnv.name & sfEnv.ext
                load(envDir, envFile)
            except CatchableError as e:
                errors.add(
                "Ih... something went wrong while loading the .env file! (>_<)" &
                "\n  file: '" & incl.includePath & "'" &
                "\n  detail: " & e.msg
                )