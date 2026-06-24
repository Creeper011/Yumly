import std/[os, strutils, terminal, osproc]

proc extractNumber(folderName: string): int =
  ## Extracts the 4-digit number from a folder name like "y0003-pairs",
  ## "yT0003-pairs", or "xV0001-duplicated-pair".
  var numStr = ""
  var foundDigitStart = false
  for i in 1..<folderName.len:
    let ch = folderName[i]
    if ch in {'0'..'9'}:
      numStr.add(ch)
      foundDigitStart = true
    elif foundDigitStart:
      break # stop at first non-digit after digits started
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

proc getNextUnitNumber(): string =
  var maxNum = 0
  let unitsDir = "tests" / "unit"
  if dirExists(unitsDir):
    for entry in walkDir(unitsDir):
      if entry.kind == pcDir:
        let num = extractNumber(lastPathPart(entry.path))
        if num > maxNum:
          maxNum = num
  (maxNum + 1).intToStr().align(4, '0')

proc prompt(msg: string, default: string = ""): string =
  styledEcho fgCyan, "? ", fgWhite, msg, (if default.len > 0: " [" & default &
      "]" else: ""), ": ", resetStyle
  result = readLine(stdin).strip()
  if result == "" and default.len > 0:
    result = default

proc createUnitTest() =
  let testName = prompt(
    "What's the behavior being tested? (ex: classify literal)")
  let moduleFile = prompt(
    "Which module is under test? (ex: value_defs.nim)")
  let runner = prompt("Which runner? (nim/python)", "nim").toLowerAscii()

  if testName.len == 0 or moduleFile.len == 0:
    styledEcho fgRed, "Unit name and module are required."
    quit(1)
  if runner notin ["nim", "python"]:
    styledEcho fgRed, "Unit runner must be 'nim' or 'python'."
    quit(1)

  let number = getNextUnitNumber()
  let moduleName = moduleFile.splitFile.name
  let slug = testName.replace(" ", "-").toLowerAscii()
  let fileSlug = slug.replace("-", "_")
  let targetDir = "tests" / "unit" /
    ("U" & number & "[" & moduleName & "]-" & slug)
  createDir(targetDir)

  let extension = if runner == "python": ".py" else: ".nim"
  let fileName = "test_" & fileSlug & extension
  writeFile(targetDir / fileName, "")

  styledEcho fgGreen, styleBright,
    "\nTest successfully created at: ", targetDir

proc main() =
  styledEcho fgMagenta, styleBright, "=== Yumly Test Creator (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ==="

  let testKind = prompt("Create a fixture or unit test?",
      "fixture").toLowerAscii()
  if testKind == "unit" or testKind == "u":
    createUnitTest()
    return

  let testName = prompt("Heeeh... What's the name of the test? (ex: multiline strings)")
  if testName.len == 0:
    styledEcho fgRed, "Kyaa~! The test name cannot be empty! (x_x)"
    quit(1)

  let typeAns = prompt("Is this test valid (y), invalid (x), or stress (s)?",
      "y").toLowerAscii()
  let isValid = typeAns == "y" or typeAns == "yes"
  let isStress = typeAns == "s" or typeAns == "stress"
  let validStr = if isStress: "stress" elif isValid: "valid" else: "invalid"
  let idChar = if isStress: "s" elif isValid: "y" else: "x"

  let expectedCode = if isValid or isStress: "" else: prompt("Which diagnostic code is expected?")
  if not isValid and not isStress and expectedCode.len == 0:
    styledEcho fgRed, "Invalid fixtures require an expected diagnostic code."
    quit(1)

  let baseDir = "tests" / "fixtures" / validStr
  createDir(baseDir)

  let numStr = getNextNumber(validStr)
  let idPrefix = idChar

  let folderName = idPrefix & numStr & "-" & testName.replace(" ",
      "-").toLowerAscii()
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

    let editAns = prompt("Do you want to open '" & caseName &
        "' in your editor now? (y/n)", "n").toLowerAscii()
    if editAns == "y" or editAns == "yes":
      let editor = getEnv("EDITOR", "vim")
      styledEcho fgGreen, "Yay! Opening ", casePath, " in ", editor, "..."
      discard execCmd(editor & " " & casePath)

  let casesFormatted = "[\"" & casesSeq.join("\", \"") & "\"]"

  let validBoolStr = if isValid or isStress: "true" else: "false"
  let expectedCodeLine = if expectedCode.len > 0: "expectedCode ;string = \"" &
      expectedCode & "\"\n" else: ""

  let metadataContent = ";> Test file metadata for " & testName & " <;\n\n" &
                        "name ;string = \"" & testName & "\"\n" &
                        "valid ;bool = " & validBoolStr & ", number ;int = " &
                            numStr & "\n" &
                        expectedCodeLine &
                        "\ncases ;list[string] = " & casesFormatted & "\n"

  let metadataPath = targetDir / "metadata.yumly"
  writeFile(metadataPath, metadataContent)

  styledEcho fgGreen, styleBright, "\n✔ Yaaay! Test successfully created at: ", targetDir

when isMainModule:
  main()
