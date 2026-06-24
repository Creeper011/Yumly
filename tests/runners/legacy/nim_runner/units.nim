import std/[algorithm, os, osproc, strutils, terminal, times]

import benchmark

type
  UnitResult = object
    id: string
    file: string
    passed: bool
    output: string

const TimePrefix = "YUM_BENCHMARK\t"

proc unitId(sourcePath: string): string =
  let parent = lastPathPart(parentDir(sourcePath))
  parent & "/" & sourcePath.splitFile.name

proc shellCommand(command: string, args: openArray[string]): string =
  result = quoteShell(command)
  for arg in args:
    result.add(" ")
    result.add(quoteShell(arg))

proc parseTimedOutput(output: string): tuple[output: string, duration,
    peakRss: float] =
  var lines: seq[string]
  result.duration = 0.0
  result.peakRss = 0.0

  for line in output.splitLines():
    if line.startsWith(TimePrefix):
      let parts = line[TimePrefix.len .. ^1].split('\t')
      if parts.len == 2:
        try:
          result.duration = parseFloat(parts[0])
          result.peakRss = parseFloat(parts[1]) / 1024.0
        except ValueError:
          discard
    else:
      lines.add(line)

  result.output = lines.join("\n")
  if output.endsWith("\n") and result.output.len > 0:
    result.output.add("\n")

proc runMeasuredCommand(
  command: string,
  args: openArray[string]
): tuple[output: string, exitCode: int, duration, peakRss: float] =
  let timeExe = findExe("time")
  if timeExe.len == 0 or not timeExe.isAbsolute():
    let start = epochTime()
    let (output, exitCode) = execCmdEx(shellCommand(command, args))
    return (
      output: output,
      exitCode: exitCode,
      duration: epochTime() - start,
      peakRss: 0.0)

  var timeArgs = @["-f", TimePrefix & "%e\t%M", command]
  for arg in args:
    timeArgs.add(arg)

  let (timedOutput, exitCode) = execCmdEx(shellCommand(timeExe, timeArgs))
  let parsed = parseTimedOutput(timedOutput)
  (
    output: parsed.output,
    exitCode: exitCode,
    duration: parsed.duration,
    peakRss: parsed.peakRss)

proc runUnitFile(sourcePath: string, report: var BenchmarkReport): UnitResult =
  let id = sourcePath.unitId()
  let outputDir = "build" / "tests" / "unit" / lastPathPart(parentDir(sourcePath))
  createDir(outputDir)

  let outputPath = outputDir / sourcePath.splitFile.name
  let nimcachePath = outputDir / "nimcache"
  let nim = getEnv("NIM", "nim")
  let compileArgs = @[
    "c",
    "--hints:off",
    "--nimcache:" & nimcachePath,
    "--out:" & outputPath,
    sourcePath]
  let compileResult = runMeasuredCommand(nim, compileArgs)
  let compileOutput = compileResult.output
  let compileExitCode = compileResult.exitCode
  report.add(bcUnit, id, sourcePath, "compile",
    compileResult.duration,
    compileResult.peakRss)

  var output = compileOutput
  var exitCode = compileExitCode
  if compileExitCode == 0:
    let executeResult = runMeasuredCommand(outputPath, [])
    let executeOutput = executeResult.output
    let executeExitCode = executeResult.exitCode
    report.add(bcUnit, id, sourcePath, "execute",
      executeResult.duration,
      executeResult.peakRss)
    output.add(executeOutput)
    exitCode = executeExitCode

  UnitResult(
    id: id,
    file: sourcePath,
    passed: exitCode == 0,
    output: output
  )

proc discoverUnits(unitsDir: string): tuple[files, errors: seq[string]] =
  if not dirExists(unitsDir):
    result.errors.add("unit directory does not exist: " & unitsDir)
    return

  for path in walkDirRec(unitsDir):
    if path.splitFile.ext != ".nim":
      continue
    let name = path.splitFile.name
    if not name.startsWith("test_"):
      result.errors.add(
        "Nim unit test must be named test_*.nim: " & path)
    else:
      result.files.add(path)

  result.files.sort()
  if result.files.len == 0:
    result.errors.add("no Nim unit tests discovered under " & unitsDir)

proc runUnits*(report: var BenchmarkReport): bool =
  let discovery = discoverUnits("tests" / "unit")
  var failures: seq[UnitResult]

  styledEcho fgMagenta, styleBright, "\n=== Yumly Nim Unit Tests ===\n"

  for error in discovery.errors:
    failures.add(UnitResult(
      id: "discovery",
      file: "tests/unit",
      passed: false,
      output: error
    ))

  var passedCount = 0
  for sourcePath in discovery.files:
    let unitResult = runUnitFile(sourcePath, report)
    if unitResult.passed:
      inc passedCount
      styledEcho fgGreen, "  [PASS] ", fgWhite, unitResult.id
    else:
      failures.add(unitResult)
      styledEcho fgRed, "  [FAIL] ", fgWhite, unitResult.id

  let total = discovery.files.len + discovery.errors.len
  styledEcho fgBlue, styleBright, "\nNim units: ",
    if failures.len == 0: fgGreen else: fgRed,
    $passedCount, "/", $total, " passed"

  for failure in failures:
    styledEcho fgYellow, "\n> ", failure.id, " (", failure.file, ")"
    echo failure.output

  failures.len == 0
