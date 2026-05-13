import std/[os, strutils, terminal, options, sugar]
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/api/nim_api

type
  Phase = enum
    pTokenizer = "T",
    pParser = "P",
    pResolver = "R",
    pValidator = "V",
    pEvaluator = "E",
    pLoadInclude = "LI"

  TestResult = object
    name: string
    id: string
    passed: bool
    error: string

proc toPipelineStage(p: Phase): PipelineStage =
  case p
  of pTokenizer: psTokenizer
  of pParser: psParser
  of pResolver, pLoadInclude: psResolver
  of pValidator: psValidator
  of pEvaluator: psEvaluator
proc runTest(dir: string, id: string): seq[TestResult] =
  let metadataPath = dir / "metadata.yumly"
  if not fileExists(metadataPath): return @[]

  let meta = loadYumly(metadataPath)
  let nameVal = meta.safeGet("name")
  let validVal = meta.safeGet("valid")
  let phaseVal = meta.safeGet("phase")
  let casesVal = meta.safeGet("cases")

  if nameVal.isNone or validVal.isNone or phaseVal.isNone or casesVal.isNone:
    var missing: seq[string]
    if nameVal.isNone: missing.add("'name'")
    if validVal.isNone: missing.add("'valid'")
    if phaseVal.isNone: missing.add("'phase'")
    if casesVal.isNone: missing.add("'cases'")
    return @[TestResult(name: "Metadata Error", id: id, passed: false, 
             error: "Ehhh... missing mandatory fields in metadata.yumly: " & missing.join(", "))]

  let testName = nameVal.get().getStr()
  let isValidExpected = validVal.get().getBool()
  let phaseStr = phaseVal.get().getStr()
  let cases = casesVal.get().getElems()
  let envs = meta.safeGet("envs").map(it => it.getElems()).get(@[]) # envs are optional

  let phase = try: parseEnum[Phase](phaseStr) 
              except ValueError: 
                return @[TestResult(name: "Metadata Error", id: id, passed: false, 
                         error: "Heeeh?! Invalid phase '" & phaseStr & "' in metadata.yumly (>_<)")]

  let targetStage = phase.toPipelineStage()

  for e in envs:
    putEnv(e.getStr(), "true") # TODO: remove envs after ran test ;-;

  for caseVal in cases:
    let caseFile = caseVal.getStr()
    let fullPath = dir / caseFile
    var res = TestResult(name: testName & " (" & caseFile & ")", id: id, passed: false)

    try:
      discard loadYumly(fullPath, targetStage)
      res.passed = isValidExpected
      if not res.passed:
        res.error = "Kyaa~! Expected failure, but it passed! (o_O)"
    except CatchableError as e:
      res.passed = not isValidExpected
      if not res.passed:
        res.error = e.msg

    result.add(res)

proc main() =
  let fixturesDir = "tests" / "fixtures"
  var total, passedCount = 0
  var failures: seq[TestResult] = @[]

  styledEcho fgMagenta, styleBright, "\n=== Yumly Test Runner (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ===\n"

  for kind in ["valid", "invalid"]:
    let kindPath = fixturesDir / kind / "phases"
    if not dirExists(kindPath): continue

    for folder in walkDir(kindPath):
      if folder.kind != pcDir: continue
      
      let dirName = lastPathPart(folder.path)
      for result in runTest(folder.path, dirName):
        inc total
        if result.passed:
          inc passedCount
          styledEcho fgGreen, "  [YAY!] ", fgWhite, result.id, " - ", result.name
        else:
          styledEcho fgRed, "  [KYAA] ", fgWhite, result.id, " - ", result.name
          failures.add(result)

  styledEcho fgBlue, styleBright, "\n✨ Summary: ", 
             if passedCount == total: fgGreen else: fgRed, $passedCount, "/", $total, " passed! :3"

  if failures.len > 0:
    styledEcho fgRed, styleBright, "\n--- Failures (>_<) ---"
    for f in failures:
      styledEcho fgYellow, "\n> ", f.id, ": ", f.name
      echo f.error
    quit(1)

main()
