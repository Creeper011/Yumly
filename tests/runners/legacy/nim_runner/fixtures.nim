import std/[os, strutils, terminal, options, times, osproc]
import ../../../../src/yumly/api/nim/api
import ../../../../src/yumly/types/[ast, errors]
import benchmark
import memory

type
  TestResult = object
    name: string
    id: string
    passed: bool
    hasAssertion: bool
    error: string

const BenchmarkWorkerPrefix = "YUM_BENCHMARK\t"

proc collectFixtureBenchmark(
  benchmarkId,
  fullPath: string,
  report: var BenchmarkReport
): Option[string]

proc runTest(dir: string, id: string, report: var BenchmarkReport): seq[TestResult] =
  let metadataPath = dir / "metadata.yumly"
  if not fileExists(metadataPath):
    return @[TestResult(
      name: "Metadata Error", id: id, passed: false,
      error: "missing metadata.yumly")]

  let meta = try: loadYumly(metadataPath)
             except CatchableError as e:
               return @[TestResult(name: "Metadata Error", id: id, passed: false,
                        error: "Kyaa! Failed to load metadata: " & e.msg)]

  let nameVal = meta.findPair("name")
  let validVal = meta.findPair("valid")
  let numberVal = meta.findPair("number")
  let casesVal = meta.findPair("cases")

  if nameVal.isNone or validVal.isNone or numberVal.isNone or casesVal.isNone:
    var missing: seq[string]
    if nameVal.isNone: missing.add("'name'")
    if validVal.isNone: missing.add("'valid'")
    if numberVal.isNone: missing.add("'number'")
    if casesVal.isNone: missing.add("'cases'")
    return @[TestResult(name: "Metadata Error", id: id, passed: false,
             error: "Ehhh... missing mandatory fields in metadata.yumly: " &
             missing.join(", "))]

  let testName = nameVal.get().getStr()
  let isValidExpected = validVal.get().getBool()
  let cases = casesVal.get().getList()
  if cases.len == 0:
    return @[TestResult(name: "Metadata Error", id: id, passed: false,
      error: "'cases' must contain at least one file")]

  let expectedCodeVal = meta.findPair("expectedCode")
  if not isValidExpected and expectedCodeVal.isNone:
    return @[TestResult(name: "Metadata Error", id: id, passed: false,
      error: "invalid fixtures require 'expectedCode'")]

  # Execute pre-suite Python script in a sandboxed subprocess
  let preSuiteVal = meta.findPair("preSuiteEval")
  if preSuiteVal.isSome:
    let code = preSuiteVal.get().getStr()
    let pythonBin = findExe("python3")
    if pythonBin == "":
      return @[TestResult(name: "Pre-suite Error", id: id, passed: false,
               error: "Python3 not found in PATH")]
    let script = "import os, sys\nos.chdir(\"" & dir.replace("\\",
        "\\\\").replace("\"", "\\\"") &
        "\")\nsys.path.insert(0, os.getcwd())\n" & code
    let tmpFile = getTempDir() / "yumly_presuite_" & id & ".py"
    writeFile(tmpFile, script)
    let cmd = quoteShell(pythonBin) & " " & quoteShell(tmpFile)
    let (output, exitCode) = execCmdEx(cmd)
    removeFile(tmpFile)
    if exitCode != 0:
      return @[TestResult(name: "Pre-suite Error", id: id, passed: false,
               error: "Python pre-suite script failed (exit code " & $exitCode &
               "):\n" & output)]

  let envsBlock = meta.findBlock("envs")
  var envKeys: seq[string] = @[]
  if envsBlock.isSome:
    for pair in envsBlock.get().pairs:
      putEnv(pair.key, pair.value.getStr())
      envKeys.add(pair.key)

  for caseVal in cases:
    let caseFile = caseVal.getStr()
    let fullPath = dir / caseFile
    let benchmarkId = id & " - " & caseFile
    var res = TestResult(name: testName & " (" & caseFile & ")", id: id, passed: false)
    if not fileExists(fullPath):
      res.error = "case file does not exist: " & fullPath
      result.add(res)
      continue

    var expectedCode = ""
    if not isValidExpected:
      expectedCode = expectedCodeVal.get().getStr()

    let expectedYumyumyFile = fullPath.changeFileExt("expected.yumyumy")

    try:
      if report.enabled:
        let benchmarkError = collectFixtureBenchmark(
          benchmarkId,
          fullPath,
          report)
        if benchmarkError.isSome:
          res.error = benchmarkError.get()
          result.add(res)
          continue

      if not isValidExpected:
        discard loadYumly(fullPath)
        res.passed = false
        res.error = "Kyaa~! Expected failure, but it passed! (o_O)"
        result.add(res)
        continue

      let config = loadYumly(fullPath)
      res.passed = true

      if fileExists(expectedYumyumyFile):
        let actual = config.toYumyumy()
        res.hasAssertion = true
        let expected = readFile(expectedYumyumyFile).strip()
        if actual.strip() != expected:
          res.passed = false
          res.error = "assertion failed\nexpected:\n" & expected & "\ngot:\n" & actual

    except YumlyError as error:
      if isValidExpected:
        res.error = error.msg
      elif error.code != expectedCode:
        res.error = "wrong diagnostic code\nexpected: " & expectedCode &
          "\ngot: " & error.code & "\n" & error.msg
      else:
        res.passed = true
    except YumlyIOError as error:
      if isValidExpected:
        res.error = error.msg
      elif error.code != expectedCode:
        res.error = "wrong diagnostic code\nexpected: " & expectedCode &
          "\ngot: " & error.code & "\n" & error.msg
      else:
        res.passed = true
    except CatchableError as error:
      res.passed = false
      res.error = "unstructured exception (" & $error.name & "): " & error.msg

    result.add(res)

  for key in envKeys:
    delEnv(key)

proc parseBenchmarkWorkerOutput(output: string): Option[tuple[duration,
    memoryDelta: float]] =
  for line in output.splitLines():
    if not line.startsWith(BenchmarkWorkerPrefix):
      continue

    let parts = line[BenchmarkWorkerPrefix.len .. ^1].split('\t')
    if parts.len != 2:
      return none(tuple[duration, memoryDelta: float])

    try:
      return some((duration: parseFloat(parts[0]), memoryDelta: parseFloat(
          parts[1])))
    except ValueError:
      return none(tuple[duration, memoryDelta: float])

proc collectFixtureBenchmark(
  benchmarkId,
  fullPath: string,
  report: var BenchmarkReport
): Option[string] =
  let command = quoteShell(getAppFilename()) &
    " --benchmark-fixture-worker " & quoteShell(fullPath)
  let (output, exitCode) = execCmdEx(command)
  if exitCode != 0:
    return some("benchmark worker failed (exit code " & $exitCode & "):\n" & output)

  let measurement = parseBenchmarkWorkerOutput(output)
  if measurement.isNone:
    return some("benchmark worker did not report memory/time data:\n" & output)

  let data = measurement.get()
  report.add(
    bcFixture,
    benchmarkId,
    fullPath,
    "pipeline",
    data.duration,
    data.memoryDelta)

proc runFixtureBenchmarkWorker*(fullPath: string) =
  let baselineOccupiedMemory = occupiedMemoryMb()
  let baselinePeakMemory = peakManagedMemoryMb()
  let startT = cpuTime()
  var duration = 0.0
  var memoryDelta = 0.0
  try:
    let measuredConfig = loadYumly(fullPath)
    duration = cpuTime() - startT
    memoryDelta = benchmarkMemoryDeltaMb(
      baselineOccupiedMemory,
      baselinePeakMemory)
    discard measuredConfig
  except CatchableError:
    duration = cpuTime() - startT
    memoryDelta = benchmarkMemoryDeltaMb(
      baselineOccupiedMemory,
      baselinePeakMemory)

  echo BenchmarkWorkerPrefix &
    formatFloat(duration, ffDecimal, 9) & "\t" &
    formatFloat(memoryDelta, ffDecimal, 6)

proc runFixtures*(report: var BenchmarkReport, kinds: openArray[string]): bool =
  let fixturesDir = "tests" / "fixtures"
  var total, passedCount = 0
  var failures: seq[TestResult] = @[]

  styledEcho fgMagenta, styleBright, "\n=== Yumly Test Runner (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ===\n"

  for kind in kinds:
    let kindPath = fixturesDir / kind
    if not dirExists(kindPath):
      inc total
      failures.add(TestResult(
        name: "Discovery Error", id: kind, passed: false,
        error: "fixture category does not exist: " & kindPath))
      continue

    for folder in walkDir(kindPath):
      if folder.kind != pcDir: continue

      let dirName = lastPathPart(folder.path)
      for result in runTest(folder.path, dirName, report):
        inc total
        let assertionMsg = if result.hasAssertion: " [with assertion]" else: ""
        if result.passed:
          inc passedCount
          styledEcho fgGreen, "  [YAY!] ", fgWhite, result.id, " - ",
              result.name, fgCyan, assertionMsg
        else:
          styledEcho fgRed, "  [KYAA] ", fgWhite, result.id, " - ", result.name,
              fgCyan, assertionMsg
          failures.add(result)

  if total == 0:
    failures.add(TestResult(
      name: "Discovery Error", id: "fixtures", passed: false,
      error: "no fixture cases discovered"))

  styledEcho fgBlue, styleBright, "\n✨ Summary: ",
             if passedCount == total: fgGreen else: fgRed, $passedCount, "/",
                 $total, " passed! :3"

  if failures.len > 0:
    styledEcho fgRed, styleBright, "\n--- Failures (>_<) ---"
    for f in failures:
      styledEcho fgYellow, "\n> ", f.id, ": ", f.name
      echo f.error
    return false

  true
