import std/[os, strutils, terminal, osproc]

proc getNextNumber(baseDir: string, idPrefix: string): string =
  var maxNum = 0
  if dirExists(baseDir):
    for kind, path in walkDir(baseDir):
      if kind == pcDir:
        let folderName = extractFilename(path)
        if folderName.startsWith(idPrefix):
          let numStr = folderName[idPrefix.len .. idPrefix.len + 3]
          try:
            let num = parseInt(numStr)
            if num > maxNum: maxNum = num
          except ValueError:
            discard
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
    
  let validAns = prompt("Is this test valid? (y/n)", "y").toLowerAscii()
  let isValid = validAns == "y" or validAns == "yes"
  let validStr = if isValid: "valid" else: "invalid"
  let idChar = if isValid: "y" else: "x"
  
  styledEcho fgYellow, "Available phases: T (Tokenizer), P (Parser), R (Resolver), V (Validator), E (Evaluator), LI (Load Include)"
  let phaseAns = prompt("Which phase? (Leave empty for full case)").toUpperAscii()
  
  let isFullCase = phaseAns == ""
  let phaseChar = if isFullCase: "" else: phaseAns
  let typeDir = if isFullCase: "full" else: "phases"
  
  let baseDir = "tests" / "fixtures" / validStr / typeDir
  createDir(baseDir)
  
  let idPrefix = idChar & phaseChar
  let numStr = getNextNumber(baseDir, idPrefix)
  
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
  
  let metadataContent = ";> Test file metadata template for unit tests <;\n\n" &
                        "name ;string = \"" & testName & "\"\n" &
                        "valid ;bool = " & validBoolStr & ", number ;int = " & numStr & "\n\n" &
                        phaseLine &
                        "cases ;list[string] = " & casesFormatted & "\n"
                        
  let metadataPath = targetDir / "metadata.yumly"
  writeFile(metadataPath, metadataContent)
  
  styledEcho fgGreen, styleBright, "\n✔ Yaaay! Test successfully created at: ", targetDir

when isMainModule:
  main()