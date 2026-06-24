import os, strutils, osproc

const
  files = @[
      "Yumly.nimble",
      "pyproject.toml",
  ]

proc parseOutputVersion(): (string, bool) =
  let args = commandLineParams()
  if args.len < 1:
    echo """
        Usage: change_version <new_version> <-tag>
        
        <new_version> : the new version to set
        <-tag>      : optional, if true, will add a git tag to the new version with prefix 'v'
        """
    quit()
  (args[0], args.len > 1 and args[1] == "-tag")

proc changeVersion(version: string, addTag: bool) =
  let root = currentSourcePath().parentDir() / ".."
  for file in files:
    let path = root / file
    if not path.fileExists():
      echo "Error: File not found: " & path
      quit(1)
    let content = readFile(path)
    var lines = content.splitLines()
    for i, line in lines:
      if line.strip().startsWith("version"):
        let quoteStart = line.find('"')
        let quoteEnd = line.rfind('"')
        if quoteStart != -1 and quoteEnd != -1 and quoteStart != quoteEnd:
          lines[i] = line[0..quoteStart] & version & line[quoteEnd..^1]
    writeFile(path, lines.join("\n"))
  if addTag:
    let result = execCmd("git tag v" & version)
    if result != 0:
      echo "Error: Failed to add git tag"
      quit(1)

let (version, addTag) = parseOutputVersion()
changeVersion version, addTag
