import std/[os, strutils, terminal, osproc, algorithm, sequtils]

proc extractNumber(folderName: string): int =
  ## Extracts the 4-digit number from a folder name like "yT0003-pairs" or "xV0001-duplicated-pair"
  ## The number always starts after the identifier prefix (1-2 chars) and phase prefix (0-2 chars).
  var numStr = ""
  var foundDigitStart = false
  for i in 1..<folderName.len:
    let ch = folderName[i]
    if ch in {'0'..'9'}:
      numStr.add(ch)
      foundDigitStart = true
    elif foundDigitStart:
      break  # stop at first non-digit after digits started
  if numStr.len >= 4:
    try:
      return parseInt(numStr[0..3])
    except ValueError:
      return 0
  return 0

proc getNextNumber(kind: string): string =
  var maxNum = 0
  let fixturesDir = "tests" / "fixtures"
  let kindPath = fixturesDir / kind
  if dirExists(kindPath):
    for entry in walkDir(kindPath):
      if entry.kind == pcDir:
        let folderName = lastPathPart(entry.path)
        let num = extractNumber(folderName)
        if num > maxNum: maxNum = num
  maxNum += 1
  return maxNum.intToStr().align(4, '0')

proc prompt(msg: string, default: string = ""): string =
  styledEcho fgCyan, "? ", fgWhite, msg, (if default.len > 0: " [" & default & "]" else: ""), ": ", resetStyle
  result = readLine(stdin).strip()
  if result == "" and default.len > 0:
    result = default

proc main() =
  styledEcho fgMagenta, styleBright, "=== Yumly Test Creator (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ==="
  
  let testName = prompt("Heeeh... What's the name of the test? (ex: multiline strings)")
  if testName.len == 0:
    styledEcho fgRed, "Kyaa~! The test name cannot be empty! (x_x)"
    quit(1)
    
  let typeAns = prompt("Is this test valid (y), invalid (x), or stress (s)?", "y").toLowerAscii()
  let isValid = typeAns == "y" or typeAns == "yes"
  let isStress = typeAns == "s" or typeAns == "stress"
  let isInvalid = typeAns == "x" or typeAns == "no" or typeAns == "n"
  
  let validStr = if isStress: "stress" elif isValid: "valid" else: "invalid"
  let idChar = if isStress: "s" elif isValid: "y" else: "x"
  
  styledEcho fgYellow, "Available phases: T (Tokenizer), P (Parser), LI (Load Include), R (Resolver), V (Validator), E (Evaluator)"
  let phaseAns = prompt("Which phase? (Leave empty for full case)").toUpperAscii()
  
  let isFullCase = phaseAns == ""
  let phaseChar = if isFullCase: "" else: phaseAns
  
  let baseDir = "tests" / "fixtures" / validStr
  createDir(baseDir)
  
  let numStr = getNextNumber(validStr)
  let idPrefix = idChar & phaseChar
  
  let folderName = idPrefix & numStr & "-" & testName.replace(" ", "_").toLowerAscii()
  let targetDir = baseDir / folderName
  
  createDir(targetDir)
  
  let numCasesStr = prompt("Mmm... How many case files will this test have?", "1")
  var numCases = 1
  try:
    numCases = parseInt(numCasesStr)
  except ValueError:
    styledEcho fgRed, "Ehhh... Invalid number, I'll just use 1 okay? >_<"
    numCases = 1
    
  var casesSeq: seq[string] = @[]
  
  for i in 1..numCases:
    let defaultFileName = if numCases == 1: "test.yumly" else: "case" & $i & ".yumly"
    let caseName = prompt("Name of the case file " & $i, defaultFileName)
    let casePath = targetDir / caseName
    writeFile(casePath, "")
    casesSeq.add(caseName)
    
    let editAns = prompt("Do you want to open '" & caseName & "' in your editor now? (y/n)", "n").toLowerAscii()
    if editAns == "y" or editAns == "yes":
      let editor = getEnv("EDITOR", "vim")
      styledEcho fgGreen, "Yay! Opening ", casePath, " in ", editor, "..."
      discard execCmd(editor & " " & casePath)
  
  let casesFormatted = "[\"" & casesSeq.join("\", \"") & "\"]"
  
  let validBoolStr = if isValid: "true" else: "false"
  let phaseLine = if isFullCase: "" else: "phase ;string = \"" & phaseAns & "\"\n"
  
  let metadataContent = ";> Test file metadata for " & testName & " <;\n\n" &
                        "name ;string = \"" & testName & "\"\n" &
                        "valid ;bool = " & validBoolStr & ", number ;int = " & numStr & "\n" &
                        phaseLine &
                        "\ncases ;list[string] = " & casesFormatted & "\n"
                        
  let metadataPath = targetDir / "metadata.yumly"
  writeFile(metadataPath, metadataContent)
  
  styledEcho fgGreen, styleBright, "\n✔ Yaaay! Test successfully created at: ", targetDir

when isMainModule:
  main()