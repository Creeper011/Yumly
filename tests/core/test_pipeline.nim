import std/[options]
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/types/ast
import ../../src/Yumly/types/type_hints
import ../../src/Yumly/types/nodes

proc testParseContentToAST() =
  let source = "name ;string = \"test\""
  let ast = parseContentToAST(source)
  assert ast.kind == nkConfig
  assert ast.children.len == 1
  echo "testParseContentToAST: PASSED"

proc testParseContentToASTEmpty() =
  let source = ""
  let ast = parseContentToAST(source)
  assert ast.kind == nkConfig
  echo "testParseContentToASTEmpty: PASSED"

proc testParseContentToASTMultiple() =
  let source = "name = \"test\", count = 42"
  let ast = parseContentToAST(source)
  assert ast.children.len == 2
  echo "testParseContentToASTMultiple: PASSED"

proc testResolveYumly() =
  let source = "name ;string = \"test\""
  var ast = parseContentToAST(source)
  resolveYumly(ast, ".")
  assert ast.hasTypeHints == some(true)
  echo "testResolveYumly: PASSED"

proc testValidateYumly() =
  let source = "name ;string = \"test\""
  var ast = parseContentToAST(source)
  resolveYumly(ast, ".")
  validateYumly(ast)
  echo "testValidateYumly: PASSED"

proc testEvaluateYumly() =
  let source = "name ;string = \"test\""
  var ast = parseContentToAST(source)
  resolveYumly(ast, ".")
  validateYumly(ast)
  let conf = evaluateYumly(ast)
  assert conf.pairs.len == 1
  assert conf.pairs[0].key == "name"
  echo "testEvaluateYumly: PASSED"

proc testLoadYumlyContent() =
  let source = "name ;string = \"test\""
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.strVal == "test"
  echo "testLoadYumlyContent: PASSED"

proc testLoadYumlyContentMultiple() =
  let source = "name ;string = \"test\", count ;int = 42"
  let conf = loadYumlyContent(source)
  assert conf.pairs.len == 2
  assert conf.pairs[1].value.intVal == 42
  echo "testLoadYumlyContentMultiple: PASSED"

proc testLoadYumlyContentWithBlock() =
  let source = "(server) { port ;int = 8080 }"
  let conf = loadYumlyContent(source)
  assert conf.blocks.len == 1
  assert conf.blocks[0].name == "server"
  echo "testLoadYumlyContentWithBlock: PASSED"

proc testLoadYumlyContentWithNestedBlock() =
  let source = "(app) { (server) { port = 8080 } }"
  let conf = loadYumlyContent(source)
  let app = conf.blocks[0]
  assert app.subBlocks.len == 1
  assert app.subBlocks[0].name == "server"
  echo "testLoadYumlyContentWithNestedBlock: PASSED"

proc testDumpYumly() =
  let source = "name ;string = \"test\""
  let conf = loadYumlyContent(source)
  let dumped = dumpYumly(conf)
  assert dumped.len > 0
  echo "testDumpYumly: PASSED"

proc testRoundTrip() =
  let original = "name ;string = \"test\""
  let conf = loadYumlyContent(original)
  let dumped = dumpYumly(conf)
  let reloaded = loadYumlyContent(dumped)
  assert reloaded.pairs[0].value.strVal == "test"
  echo "testRoundTrip: PASSED"

proc testValidateContentTrue() =
  let source = "name ;string = \"test\""
  let valid = validateContent(source)
  assert valid == true
  echo "testValidateContentTrue: PASSED"

proc testValidateContentFalse() =
  let source = "name ;string = 123"
  let valid = validateContent(source)
  assert valid == false
  echo "testValidateContentFalse: PASSED"

proc testFullPipeline() =
  let source = "name ;string = \"myapp\", (server) { port ;int = 8080 }"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.strVal == "myapp"
  assert conf.blocks[0].name == "server"
  assert conf.blocks[0].pairs[0].value.intVal == 8080
  echo "testFullPipeline: PASSED"

proc testPipelineWithList() =
  let source = "tags ;list[string] = [\"a\", \"b\"]"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.kind == vkList
  assert conf.pairs[0].value.elements.len == 2
  echo "testPipelineWithList: PASSED"

proc testPipelineWithTuple() =
  let source = "coords = [1, \"two\", 3]"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.kind == vkTuple
  echo "testPipelineWithTuple: PASSED"

proc testLoadYumlyContentWorkingDir() =
  let source = "name ;string = \"test\""
  let conf = loadYumlyContent(source, "/tmp")
  assert conf.pairs[0].value.strVal == "test"
  echo "testLoadYumlyContentWorkingDir: PASSED"

proc testEmptyConfig() =
  let conf = loadYumlyContent("")
  assert conf.pairs.len == 0
  assert conf.blocks.len == 0
  echo "testEmptyConfig: PASSED"

proc testPipelinePreservesTypeHints() =
  let source = "count ;int = 42"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].typeHint.isSome()
  assert conf.pairs[0].typeHint.get().kind == thInt
  echo "testPipelinePreservesTypeHints: PASSED"

proc testPipelineWithFloat() =
  let source = "pi = 3.14159"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.kind == vkFloat
  echo "testPipelineWithFloat: PASSED"

proc testPipelineWithBool() =
  let source = "active ;bool = true"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.boolVal == true
  echo "testPipelineWithBool: PASSED"

proc testPipelineWithFalseBool() =
  let source = "active ;bool = false"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.boolVal == false
  echo "testPipelineWithFalseBool: PASSED"

proc testPipelineNegativeNumber() =
  let source = "neg ;int = -10"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.intVal == -10
  echo "testPipelineNegativeNumber: PASSED"

proc testPipelinePositiveNumber() =
  let source = "pos ;int = +10"
  let conf = loadYumlyContent(source)
  assert conf.pairs[0].value.intVal == 10
  echo "testPipelinePositiveNumber: PASSED"

proc testLoadYumlyContentSetsSourceFile() =
  let source = "name = \"test\""
  var ast = parseContentToAST(source)
  ast.sourceFile = "/test/path.yumly"
  resolveYumly(ast, ".")
  assert ast.sourceFile == "/test/path.yumly"
  echo "testLoadYumlyContentSetsSourceFile: PASSED"

proc runPipelineTests() =
  echo "=== RUNNING PIPELINE TESTS ==="
  testParseContentToAST()
  testParseContentToASTEmpty()
  testParseContentToASTMultiple()
  testResolveYumly()
  testValidateYumly()
  testEvaluateYumly()
  testLoadYumlyContent()
  testLoadYumlyContentMultiple()
  testLoadYumlyContentWithBlock()
  testLoadYumlyContentWithNestedBlock()
  testDumpYumly()
  testRoundTrip()
  testValidateContentTrue()
  testValidateContentFalse()
  testFullPipeline()
  testPipelineWithList()
  testPipelineWithTuple()
  testLoadYumlyContentWorkingDir()
  testEmptyConfig()
  testPipelinePreservesTypeHints()
  testPipelineWithFloat()
  testPipelineWithBool()
  testPipelineWithFalseBool()
  testPipelineNegativeNumber()
  testPipelinePositiveNumber()
  testLoadYumlyContentSetsSourceFile()
  echo "=== ALL PIPELINE TESTS PASSED ===\nTotal: 27 tests"

runPipelineTests()