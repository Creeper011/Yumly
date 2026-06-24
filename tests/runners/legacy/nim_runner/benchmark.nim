import std/[algorithm, sequtils, sets, strutils, tables, times]

import ../../../utils/ylwa_writer

type
  BenchmarkCategory* = enum
    bcUnit = "unit"
    bcFixture = "fixture"

  BenchmarkEntry* = object
    category*: BenchmarkCategory
    testId*: string
    file*: string
    operation*: string
    duration*: float
    memoryDelta*: float

  BenchmarkReport* = object
    enabled*: bool
    entries*: seq[BenchmarkEntry]

proc add*(report: var BenchmarkReport, category: BenchmarkCategory, testId,
    file, operation: string, duration, memoryDelta: float) =
  if report.enabled:
    report.entries.add(BenchmarkEntry(
      category: category,
      testId: testId,
      file: file,
      operation: operation,
      duration: duration,
      memoryDelta: max(memoryDelta, 0.0)
    ))

func formatTime*(duration: float): string =
  if duration < 0.001:
    formatFloat(duration * 1_000_000, ffDecimal, 1) & "us"
  elif duration < 1.0:
    formatFloat(duration * 1_000, ffDecimal, 1) & "ms"
  else:
    formatFloat(duration, ffDecimal, 2) & "s"

func formatMemory(memory: float): string =
  formatFloat(memory, ffDecimal, 3) & "MB"

proc entriesFor(report: BenchmarkReport, category: BenchmarkCategory): seq[
    BenchmarkEntry] =
  for entry in report.entries:
    if entry.category == category:
      result.add(entry)

proc uniqueTests(entries: openArray[BenchmarkEntry]): int =
  var ids = initHashSet[string]()
  for entry in entries:
    ids.incl(entry.testId)
  ids.len

func isStressTest(entry: BenchmarkEntry): bool =
  let normalizedPath = entry.file.replace("\\", "/")
  entry.category == bcFixture and
    ("/stress/" in normalizedPath or entry.testId.startsWith("s"))

func fixtureKind(entry: BenchmarkEntry): string =
  let normalizedPath = entry.file.replace("\\", "/")
  if entry.isStressTest():
    "stress"
  elif "/invalid/" in normalizedPath or entry.testId.startsWith("x"):
    "invalid"
  elif "/valid/" in normalizedPath or entry.testId.startsWith("y"):
    "valid"
  else:
    "unknown"

proc addSummaryFields(
  writer: var YlwaWriter,
  entries: openArray[BenchmarkEntry],
  splitStressMemory = false
) =
  if entries.len == 0:
    return

  var totalTime = 0.0
  var peakMemory = 0.0
  var peakRegularMemory = 0.0
  var peakStressMemory = 0.0
  var hasStressMemory = false
  var hasRegularMemory = false
  var slowest = entries[0]
  for entry in entries:
    totalTime += entry.duration
    peakMemory = max(peakMemory, entry.memoryDelta)
    if entry.isStressTest():
      hasStressMemory = true
      peakStressMemory = max(peakStressMemory, entry.memoryDelta)
    else:
      hasRegularMemory = true
      peakRegularMemory = max(peakRegularMemory, entry.memoryDelta)
    if entry.duration > slowest.duration:
      slowest = entry

  let displayedPeakMemory =
    if splitStressMemory and hasStressMemory and hasRegularMemory:
      peakRegularMemory
    else:
      peakMemory

  writer.addField("Tests", $uniqueTests(entries))
  writer.addField("Measurements", $entries.len)
  writer.addField("Total Time", formatTime(totalTime))
  writer.addField("Average Time", formatTime(totalTime / entries.len.float))
  writer.addField("Peak Memory Delta", formatMemory(displayedPeakMemory))
  if splitStressMemory and hasStressMemory:
    writer.addField("Peak Memory Delta On Stress Tests", formatMemory(peakStressMemory))
  writer.addField("Slowest", slowest.operation & " " & slowest.testId)

proc addOperationSummaries(
  writer: var YlwaWriter,
  entries: openArray[BenchmarkEntry],
  splitStressMemory = false
) =
  if entries.len == 0:
    return

  var groups = initTable[string, seq[BenchmarkEntry]]()
  for entry in entries:
    groups.mgetOrPut(entry.operation, @[]).add(entry)

  writer.beginBlock("Operation Summaries")
  var operations = toSeq(groups.keys)
  operations.sort()
  for operation in operations:
    let measurements = groups[operation]
    var totalTime = 0.0
    var peakMemory = 0.0
    var peakRegularMemory = 0.0
    var peakStressMemory = 0.0
    var hasStressMemory = false
    var hasRegularMemory = false
    for entry in measurements:
      totalTime += entry.duration
      peakMemory = max(peakMemory, entry.memoryDelta)
      if entry.isStressTest():
        hasStressMemory = true
        peakStressMemory = max(peakStressMemory, entry.memoryDelta)
      else:
        hasRegularMemory = true
        peakRegularMemory = max(peakRegularMemory, entry.memoryDelta)

    let displayedPeakMemory =
      if splitStressMemory and hasStressMemory and hasRegularMemory:
        peakRegularMemory
      else:
        peakMemory

    writer.beginBlock("Operation " & operation)
    writer.addField("Measurements", $measurements.len)
    writer.addField("Total Time", formatTime(totalTime))
    writer.addField("Average Time", formatTime(totalTime /
        measurements.len.float))
    writer.addField("Peak Memory Delta", formatMemory(displayedPeakMemory))
    if splitStressMemory and hasStressMemory:
      writer.addField("Peak Memory Delta On Stress Tests", formatMemory(peakStressMemory))
    writer.endBlock()
  writer.endBlock()

proc addBenchmarkedTests(writer: var YlwaWriter, entries: openArray[
    BenchmarkEntry], blockPrefix: string) =
  if entries.len == 0:
    return

  var groups = initTable[string, seq[BenchmarkEntry]]()
  for entry in entries:
    groups.mgetOrPut(entry.testId, @[]).add(entry)

  var tests = toSeq(groups.keys)
  tests.sort()
  for testId in tests:
    var measurements = groups[testId]
    measurements.sort(proc(a, b: BenchmarkEntry): int =
      cmp(a.operation, b.operation))

    var totalTime = 0.0
    var peakMemory = 0.0
    for entry in measurements:
      totalTime += entry.duration
      peakMemory = max(peakMemory, entry.memoryDelta)

    writer.beginBlock(blockPrefix & " " & testId)
    writer.addField("Test", testId)
    writer.addField("File", measurements[0].file)
    writer.addField("Total Time", formatTime(totalTime))
    writer.addField("Peak Memory Delta", formatMemory(peakMemory))

    for entry in measurements:
      writer.beginBlock("Operation " & entry.operation)
      writer.addField("Time", formatTime(entry.duration))
      writer.addField("Memory Delta", formatMemory(entry.memoryDelta))
      writer.endBlock()

    writer.endBlock()

proc addUnitBenchmarks(writer: var YlwaWriter, entries: openArray[
    BenchmarkEntry]) =
  if entries.len == 0:
    return

  writer.beginBlock("Unit Benchmarks")
  writer.beginBlock("Summary")
  writer.addSummaryFields(entries)
  writer.endBlock()
  writer.addOperationSummaries(entries)
  writer.beginBlock("Units")
  writer.addBenchmarkedTests(entries, "Unit")
  writer.endBlock()
  writer.endBlock()

proc addFixtureBenchmarks(writer: var YlwaWriter, entries: openArray[
    BenchmarkEntry]) =
  if entries.len == 0:
    return

  var groups = initTable[string, seq[BenchmarkEntry]]()
  for entry in entries:
    groups.mgetOrPut(entry.fixtureKind(), @[]).add(entry)

  writer.beginBlock("Fixture Benchmarks")
  for kind in ["valid", "invalid", "stress", "unknown"]:
    if not groups.hasKey(kind):
      continue

    let measurements = groups[kind]
    writer.beginBlock("Group " & kind)
    writer.addField("Kind", kind)
    writer.beginBlock("Summary")
    writer.addSummaryFields(measurements)
    writer.endBlock()
    writer.addOperationSummaries(measurements)
    writer.beginBlock("Fixtures")
    writer.addBenchmarkedTests(measurements, "Fixture")
    writer.endBlock()
    writer.endBlock()
  writer.endBlock()

proc write*(report: BenchmarkReport, path: string) =
  if not report.enabled:
    return

  var writer = newYlwaWriter()
  writer.addComment("Yumly Nim Benchmark Results")
  writer.addComment(
    "Generated by Yumly Nim Test Runner\nDate: " &
    now().format("yyyy-MM-dd HH:mm:ss"))

  let units = report.entriesFor(bcUnit)
  let fixtures = report.entriesFor(bcFixture)

  if report.entries.len > 0:
    writer.beginBlock("Summary")
    writer.addField("Unit Tests", $uniqueTests(units))
    writer.addField("Fixture Tests", $uniqueTests(fixtures))
    writer.addSummaryFields(report.entries, splitStressMemory = true)
    writer.endBlock()

  writer.addOperationSummaries(report.entries, splitStressMemory = true)
  writer.addUnitBenchmarks(units)
  writer.addFixtureBenchmarks(fixtures)

  writeFile(path, writer.toString())
