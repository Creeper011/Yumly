import std/[os, strutils, terminal, options, streams, times]
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/api/nim_api
import ../../src/Yumly/serializers/parser_yumyumy
import ../../src/Yumly/types/[token, nodes, ast]
import ../../src/Yumly/phases/[tokenizer, parser, load_include, resolver, validate, evaluator]
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
    error: string

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
          benchmarkWriter.beginBlock("Benchmark")
          benchmarkWriter.addField("File", fullPath)
          benchmarkWriter.addField("Phase", phaseName)
          benchmarkWriter.addField("Time", $(endT - startT) & "s")
          benchmarkWriter.addField("Memory Delta", $(((endM - startM).float / 1024.0 / 1024.0)) & "MB")
          benchmarkWriter.endBlock()

        var tokens: seq[Token] = @[]
        var ast: YumNode
        var resolvedAst: YumNode

        measure("tokenize"):
          let s = newStringStream(content)
          let puller = tokenize(s)
          while true:
            let t = puller()
            tokens.add(t)
            if t.kind == tkEOF: break
        
        if phase in {pParser, pLoadInclude, pResolver, pValidator, pEvaluator}:
          measure("parse"):
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
          measure("resolve"):
            if ast.hasTypeHints.get(false):
              resolveAst(ast)
            resolvedAst = ast
            
        if phase in {pValidator, pEvaluator}:
          measure("validate"):
            validateConfig(resolvedAst)
            
        if phase == pEvaluator:
          measure("evaluate"):
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
    benchmarkWriter.addHeader("Yumly Benchmark Results")
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
        if result.passed:
          inc passedCount
          styledEcho fgGreen, "  [YAY!] ", fgWhite, result.id, " - ", result.name
        else:
          styledEcho fgRed, "  [KYAA] ", fgWhite, result.id, " - ", result.name
          failures.add(result)

  styledEcho fgBlue, styleBright, "\n✨ Summary: ", 
             if passedCount == total: fgGreen else: fgRed, $passedCount, "/", $total, " passed! :3"

  if benchmarkEnabled:
    writeFile("benchmark.ylwa", benchmarkWriter.toString())
    styledEcho fgCyan, "\n📊 Benchmark results saved to benchmark.ylwa"

  if failures.len > 0:
    styledEcho fgRed, styleBright, "\n--- Failures (>_<) ---"
    for f in failures:
      styledEcho fgYellow, "\n> ", f.id, ": ", f.name
      echo f.error
    quit(1)

main()

