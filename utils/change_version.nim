import os, strutils

const
    files = @[
        "Yumly.nimble",
        "pyproject.toml",
    ]   

proc parseOutputVersion(): string =
    let args = commandLineParams()
    if args.len < 1:
        echo "Usage: change_version <new_version>"
        quit()
    args[0]

proc changeVersion(version: string) =
    let root = currentSourcePath().parentDir() / ".."
    for file in files:
        let path = root / file
        let content = readFile(path)
        var lines = content.splitLines()
        for i, line in lines:
            if line.strip().startsWith("version"):
                let quoteStart = line.find('"')
                let quoteEnd = line.rfind('"')
                if quoteStart != -1 and quoteEnd != -1 and quoteStart != quoteEnd:
                    lines[i] = line[0..quoteStart] & version & line[quoteEnd..^1]
        writeFile(path, lines.join("\n"))

parseOutputVersion().changeVersion()