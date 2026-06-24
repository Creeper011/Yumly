import std/os

import benchmark
import fixtures
import units

when isMainModule:
  let args = commandLineParams()

  if args.len >= 2 and args[0] == "--benchmark-fixture-worker":
    runFixtureBenchmarkWorker(args[1])
    quit(0)

  var report = BenchmarkReport(
    enabled: "--benchmark" in args or "-b" in args)

  let unitsOnly = "--units-only" in args
  let fixturesOnly = "--fixtures-only" in args
  let stressOnly = "--stress-only" in args

  var unitsPassed = true
  var fixturesPassed = true
  if not fixturesOnly and not stressOnly:
    unitsPassed = runUnits(report)
  if not unitsOnly:
    let kinds =
      if stressOnly: @["stress"]
      elif report.enabled: @["valid", "invalid", "stress"]
      else: @["valid", "invalid"]
    fixturesPassed = runFixtures(report, kinds)

  report.write("benchmark.ylwa")
  if report.enabled:
    echo "\nBenchmark results saved to benchmark.ylwa"

  if not unitsPassed or not fixturesPassed:
    quit(1)
