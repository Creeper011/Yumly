import std/[os, strutils, terminal, options, streams, times, osproc]
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/api/nim/api
import ../../src/Yumly/types/[token, nodes, ast]
import ../../src/Yumly/phases/tokenizer/tokenizer
import ../../src/Yumly/phases/parser/parser
import ../../src/Yumly/phases/includes/loader
import ../../src/Yumly/phases/resolver/resolver
import ../../src/Yumly/phases/validator/validate
import ../../src/Yumly/phases/evaluator/evaluator
import ../utils/ylwa_writer

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
    hasAssertion: bool
    error: string

  BenchmarkEntry = object
    file: string
    testId: string
    phase: string
    time: float
    memoryDelta: float

var benchmarkEntries: seq[BenchmarkEntry] = @[]

proc toPipelineStage(p: Phase): PipelineStage =
  case p
  of pTokenizer: psTokenizer
  of pParser: psParser
  of pLoadInclude: psIncludes
  of pResolver: psResolver
  of pValidator: psValidator
  of pEvaluator: psEvaluator

proc serializeTokens(puller: proc(): Token {.closure.}): string =
  var lines: seq[string] = @[]
  while true:
    let t = puller()
    var line = $t.kind
    if t.kind in {tkString, tkIdent, tkLiteral}:
      line.add " \"" & t.value & "\""
    lines.add line
    if t.kind == tkEOF: break
  return lines.join("\n")

proc runTest(dir: string, id: string, benchmarkEnabled: bool, benchmarkWriter: var YlwaWriter): seq[TestResult] =
  let metadataPath = dir / "metadata.yumly"
  if not fileExists(metadataPath): return @[]

  let meta = try: loadYumly(metadataPath)
             except CatchableError as e:
               return @[TestResult(name: "Metadata Error", id: id, passed: false, 
                        error: "Kyaa! Failed to load metadata: " & e.msg)]

  let nameVal = meta.findPair("name")
  let validVal = meta.findPair("valid")
  let phaseVal = meta.findPair("phase")
  let casesVal = meta.findPair("cases")

  if nameVal.isNone or validVal.isNone or casesVal.isNone:
    var missing: seq[string]
    if nameVal.isNone: missing.add("'name'")
    if validVal.isNone: missing.add("'valid'")
    if casesVal.isNone: missing.add("'cases'")
    return @[TestResult(name: "Metadata Error", id: id, passed: false, 
             error: "Ehhh... missing mandatory fields in metadata.yumly: " & missing.join(", "))]

  let testName = nameVal.get().getStr()
  let isValidExpected = validVal.get().getBool()
  let phaseStr = if phaseVal.isSome: phaseVal.get().getStr() else: "E"
  let cases = casesVal.get().getList()

  # Execute pre-suite Python script in a sandboxed subprocess
  let preSuiteVal = meta.findPair("preSuiteEval")
  if preSuiteVal.isSome:
    let code = preSuiteVal.get().getStr()
    let pythonBin = findExe("python3")
    if pythonBin == "":
      return @[TestResult(name: "Pre-suite Error", id: id, passed: false,
               error: "Python3 not found in PATH")]
    let script = "import os, sys\nos.chdir(\"" & dir.replace("\\", "\\\\").replace("\"", "\\\"") & "\")\nsys.path.insert(0, os.getcwd())\n" & code
    let tmpFile = getTempDir() / "yumly_presuite_" & id & ".py"
    writeFile(tmpFile, script)
    let cmd = quoteShell(pythonBin) & " " & quoteShell(tmpFile)
    let (output, exitCode) = execCmdEx(cmd)
    removeFile(tmpFile)
    if exitCode != 0:
      return @[TestResult(name: "Pre-suite Error", id: id, passed: false,
               error: "Python pre-suite script failed (exit code " & $exitCode & "):\n" & output)]

  let envsBlock = meta.findBlock("envs")
  var envKeys: seq[string] = @[]
  if envsBlock.isSome:
    for pair in envsBlock.get().pairs:
      putEnv(pair.key, pair.value.getStr())
      envKeys.add(pair.key)

  let phase = try: parseEnum[Phase](phaseStr) 
              except ValueError: 
                return @[TestResult(name: "Metadata Error", id: id, passed: false, 
                         error: "Heeeh?! Invalid phase '" & phaseStr & "' in metadata.yumly (>_<)")]

  let targetStage = phase.toPipelineStage()

  for caseVal in cases:
    let caseFile = caseVal.getStr()
    let fullPath = dir / caseFile
    var res = TestResult(name: testName & " (" & caseFile & ")", id: id, passed: false)

    try:
      if benchmarkEnabled:
        let content = readFile(fullPath)
        
        template measure(phaseName: string, body: untyped) =
          let startT = cpuTime()
          let startM = getOccupiedMem()
          body
          let endT = cpuTime()
          let endM = getOccupiedMem()
          let deltaT = endT - startT
          let deltaM = ((endM - startM).float / 1024.0 / 1024.0)
          benchmarkEntries.add(BenchmarkEntry(file: fullPath, testId: id, phase: phaseName, time: deltaT, memoryDelta: deltaM))

        var tokens: seq[Token] = @[]
        var ast: YumNode
        var resolvedAst: YumNode

        measure("tokenizer"):
          let s = newStringStream(content)
          let puller = tokenize(s)
          while true:
            let t = puller()
            tokens.add(t)
            if t.kind == tkEOF: break
        
        if phase in {pParser, pLoadInclude, pResolver, pValidator, pEvaluator}:
          measure("parser"):
            var i = 0
            let puller = proc(): Token =
              if i < tokens.len: result = tokens[i]; inc i
              else: result = Token(kind: tkEOF)
            var p = newParser(puller)
            ast = p.parse()

        if phase in {pLoadInclude, pResolver, pValidator, pEvaluator}:
          if ast.hasIncludes.get(false):
            measure("load_includes"):
              loadIncludes(ast, dir)
            
        if phase in {pResolver, pValidator, pEvaluator}:
          measure("resolver"):
            if ast.hasTypeHints.get(false):
              resolveAst(ast)
            resolvedAst = ast
            
        if phase in {pValidator, pEvaluator}:
          measure("validator"):
            validateConfig(resolvedAst)
            
        if phase == pEvaluator:
          measure("evaluator"):
            discard evaluateConfig(resolvedAst)

      # Normal test execution/assertion
      if phase == pTokenizer:
        let stream = newFileStream(fullPath, fmRead)
        if stream == nil: raise newException(IOError, "Could not open file: " & fullPath)
        let puller = tokenize(stream)
        let actual = serializeTokens(puller)
        stream.close()
        
        let expectedFile = fullPath.changeFileExt("expected.tokens")
        if fileExists(expectedFile):
          res.hasAssertion = true
          let expected = readFile(expectedFile).strip()
          if actual.strip() == expected:
            res.passed = isValidExpected
          else:
            res.passed = false
            res.error = "assertion failed\nexpected:\n" & expected & "\ngot:\n" & actual
        else:
          res.passed = isValidExpected
      
      elif phase == pEvaluator:
        let config = loadYumly(fullPath)
        let actual = config.toYumyumy()
        
        let expectedFile = fullPath.changeFileExt("expected.yumyumy")
        if fileExists(expectedFile):
          res.hasAssertion = true
          let expected = readFile(expectedFile).strip()
          if actual.strip() == expected:
            res.passed = isValidExpected
          else:
            res.passed = false
            res.error = "assertion failed\nexpected:\n" & expected & "\ngot:\n" & actual
        else:
          res.passed = isValidExpected
      
      else:
        discard loadYumly(fullPath, targetStage)
        res.passed = isValidExpected
      
      if res.passed and not isValidExpected:
        res.passed = false
        res.error = "Kyaa~! Expected failure, but it passed! (o_O)"
        
    except CatchableError as e:
      res.passed = not isValidExpected
      if not res.passed:
        res.error = e.msg

    result.add(res)

  for key in envKeys:
    delEnv(key)

proc formatTime(t: float): string =
  if t < 0.001:
    result = formatFloat(t * 1_000_000, ffDecimal, 1) & "μs"
  elif t < 1.0:
    result = formatFloat(t * 1_000, ffDecimal, 1) & "ms"
  else:
    result = formatFloat(t, ffDecimal, 2) & "s"

proc main() =
  var benchmarkEnabled = false
  var benchmarkWriter = newYlwaWriter()
  let args = commandLineParams()
  for arg in args:
    if arg == "--benchmark" or arg == "-b":
      benchmarkEnabled = true

  let fixturesDir = "tests" / "fixtures"
  var total, passedCount = 0
  var failures: seq[TestResult] = @[]

  if benchmarkEnabled:
    benchmarkWriter.addComment("Yumly Benchmark Results")
    benchmarkWriter.addComment("Generated by Yumly Test Runner\nDate: " & now().format("yyyy-MM-dd HH:mm:ss"))

  styledEcho fgMagenta, styleBright, "\n=== Yumly Test Runner (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ===\n"

  for kind in ["valid", "invalid", "stress"]:
    let kindPath = fixturesDir / kind
    if not dirExists(kindPath): continue

    for folder in walkDir(kindPath):
      if folder.kind != pcDir: continue
      
      let dirName = lastPathPart(folder.path)
      for result in runTest(folder.path, dirName, benchmarkEnabled, benchmarkWriter):
        inc total
        let assertionMsg = if result.hasAssertion: " [with assertion]" else: ""
        if result.passed:
          inc passedCount
          styledEcho fgGreen, "  [YAY!] ", fgWhite, result.id, " - ", result.name, fgCyan, assertionMsg
        else:
          styledEcho fgRed, "  [KYAA] ", fgWhite, result.id, " - ", result.name, fgCyan, assertionMsg
          failures.add(result)

  styledEcho fgBlue, styleBright, "\n✨ Summary: ", 
             if passedCount == total: fgGreen else: fgRed, $passedCount, "/", $total, " passed! :3"

  if benchmarkEnabled:
    if benchmarkEntries.len > 0:
      var totalTime = 0.0
      var tokenizeCount = 0
      var tokenizeTotal = 0.0
      var peakMem = 0.0
      var slowestEntry = benchmarkEntries[0]

      for entry in benchmarkEntries:
        totalTime += entry.time
        if entry.phase == "tokenize":
          tokenizeCount += 1
          tokenizeTotal += entry.time
        if entry.memoryDelta > peakMem:
          peakMem = entry.memoryDelta
        if entry.time > slowestEntry.time:
          slowestEntry = entry

      let avgTokenize = if tokenizeCount > 0: tokenizeTotal / tokenizeCount.float else: 0.0

      benchmarkWriter.beginBlock("Summary")
      benchmarkWriter.addField("Total Files", $benchmarkEntries.len)
      benchmarkWriter.addField("Total Time", formatFloat(totalTime, ffDecimal, 2) & "s")
      benchmarkWriter.addField("Avg Tokenize", formatTime(avgTokenize))
      benchmarkWriter.addField("Peak Memory Delta", formatFloat(peakMem, ffDecimal, 2) & "MB")
      benchmarkWriter.addField("Slowest Phase", slowestEntry.phase & " (" & slowestEntry.testId & ")")
      benchmarkWriter.endBlock()

      for entry in benchmarkEntries:
        benchmarkWriter.beginBlock("Benchmark")
        benchmarkWriter.addField("File", entry.file)
        benchmarkWriter.addField("Phase", entry.phase)
        benchmarkWriter.addField("Time", $entry.time & "s")
        benchmarkWriter.addField("Memory Delta", $entry.memoryDelta & "MB")
        benchmarkWriter.endBlock()

    writeFile("benchmark.ylwa", benchmarkWriter.toString())
    styledEcho fgCyan, "\n📊 Benchmark results saved to benchmark.ylwa"

  if failures.len > 0:
    styledEcho fgRed, styleBright, "\n--- Failures (>_<) ---"
    for f in failures:
      styledEcho fgYellow, "\n> ", f.id, ": ", f.name
      echo f.error
    quit(1)

main()

