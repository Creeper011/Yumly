import std/[os, strutils, strformat]

const 
  SEARCH_DIR = "./src"
  MARKERS = @["# TODO", "# FIXME", "# NOTE"]
  ALLOWED_EXTENSIONS = @[".nim"]

const 
  RESET = "\e[0m"
  BOLD = "\e[1m"
  DIM = "\e[2m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  PURPLE = "\e[35m"

type ArgsResponse = object
  markers: seq[string]
  directory: string

proc parseLine(markers: seq[string], line: string, lineIndex: int, path: string) = 
  # exclude all content before todo marker
  for marker in markers:
    let todoIndex = line.find(marker)
    if todoIndex != -1: # if found something
      let todoContent = line[todoIndex..^1] # the start from the marker to the end of the line
      echo fmt"[{marker}] {DIM}{path} (line: {lineIndex}, col: {todoIndex}){RESET}: {BOLD}{todoContent}{RESET}"

proc walkOnSearchDir(directory: string, markers: seq[string]) =
  for path in walkDirRec(directory):
    let (_, _, ext) = splitFile(path)
    if ext.toLowerAscii() in ALLOWED_EXTENSIONS:
      try:
        var i = 0
        for line in lines(path):
          i += 1
          parseLine(markers, line, i, path)
      except:
        echo fmt"{RED}Error reading file: {path}{RESET}"

proc parseMarkers(args: seq[string], start: int): (seq[string], int) =
  var markers: seq[string] = @[]
  var i = start
  while i < args.len and not args[i].startsWith("-"):
    markers.add(args[i])
    i += 1

  (markers, i - 1)

proc parseArgs(): ArgsResponse =
  result.markers = MARKERS
  result.directory = SEARCH_DIR
  let args = commandLineParams()
  if args.len > 0:
    var i = 0
    while i < args.len:
      case args[i]
      of "--help", "-h":
        echo fmt"{PURPLE}✧{RESET} Usage:"
        echo fmt"  {BOLD}markers_finder -m \"# TODO\" \"# FIXME\" ./src{RESET}"
        quit(0)
      of "--markers", "-m":
        if i + 1 < args.len:
          let (parsed, newI) = parseMarkers(args, i + 1)
          if parsed.len > 0:
            result.markers = parsed
          i = newI
      else:
        if dirExists(args[i]):
          result.directory = args[i]
      i += 1
  result
              
when isMainModule:
  let args = parseArgs()
  let displayDir = if args.directory == SEARCH_DIR: "Yumly" else: args.directory
  echo fmt"{PURPLE}✧{RESET} Scanning all files in {PURPLE}{displayDir}{RESET} source code..."
  walkOnSearchDir(args.directory, args.markers)
  echo fmt"{GREEN}✧{RESET} Done!"