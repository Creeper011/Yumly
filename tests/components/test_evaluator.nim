import ../../src/Yumly/phases/tokenizer
import ../../src/Yumly/phases/parser
import ../../src/Yumly/phases/evaluator
import ../../src/Yumly/types/ast
import os

const stringLitSource = "greeting ;string = \"hello world\""
const intLitSource = "count ;int = 42"
const floatLitSource = "pi = 3.14159"
const boolTrueSource = "active ;bool = true"
const boolFalseSource = "active ;bool = false"
const envVarSource = "db_host ;string = $[\"DB_HOST\"]"
const envVarNotSetSource = "val ;string = $[\"UNDEFINED_VAR\"]"
const simpleListSource = "items ;list[string] = [\"a\", \"b\", \"c\"]"
const listOfIntsSource = "numbers ;list[int] = [1, 2, 3]"
const emptyListSource = "empty = []"
const simpleBlockSource = """(database) {
  host ;string = "localhost",
  port ;int = 5432
}"""
const nestedBlockSource = """(database) {
  (pool) {
    max ;int = 100,
    min ;int = 10
  }
}"""
const multiplePairsSource = """name ;string = "test",
version ;int = 1,
active ;bool = true"""
const negNumberSource = "neg ;int = -42"
const posNumberSource = "pos ;int = +42"
const negFloatSource = "neg = -1.5"
const sciNotSource = "big = 1.5e+10"
const includeSource = "include { \".env\" }"
const blockNestedSource = """(app) {
  (server) { port ;int = 8080 },
  (database) { enabled ;bool = true }
}"""
const mixedListSource = "mixed = [1, \"two\", 3.0]"
const stringEscapesSource = "text ;string = \"hello\\nworld\\ttab\""
const pairLineColSource = "key = \"value\""

proc setupEnv() =
  putEnv("DB_HOST", "production.db.local")
  putEnv("UNDEFINED_VAR", "")
  putEnv("ENV_ELEM_1", "val1")
  putEnv("ENV_ELEM_2", "val2")

proc testEvaluateStringLiteral() =
  setupEnv()
  let tokens = tokenize(stringLitSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkString
  assert conf.pairs[0].value.strVal == "hello world"
  echo "testEvaluateStringLiteral: PASSED"

proc testEvaluateIntLiteral() =
  let tokens = tokenize(intLitSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkInt
  assert conf.pairs[0].value.intVal == 42
  echo "testEvaluateIntLiteral: PASSED"

proc testEvaluateFloatLiteral() =
  let tokens = tokenize(floatLitSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkFloat
  assert conf.pairs[0].value.floatVal == 3.14159
  echo "testEvaluateFloatLiteral: PASSED"

proc testEvaluateBoolTrue() =
  let tokens = tokenize(boolTrueSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkBool
  assert conf.pairs[0].value.boolVal == true
  echo "testEvaluateBoolTrue: PASSED"

proc testEvaluateBoolFalse() =
  let tokens = tokenize(boolFalseSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkBool
  assert conf.pairs[0].value.boolVal == false
  echo "testEvaluateBoolFalse: PASSED"

proc testEvaluateEnvVar() =
  setupEnv()
  let tokens = tokenize(envVarSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkEnv
  assert conf.pairs[0].value.envName == "DB_HOST"
  assert conf.pairs[0].value.envVal == "production.db.local"
  echo "testEvaluateEnvVar: PASSED"

proc testEvaluateEnvVarNotSet() =
  let tokens = tokenize(envVarNotSetSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkEnv
  assert conf.pairs[0].value.envName == "UNDEFINED_VAR"
  assert conf.pairs[0].value.envVal == ""
  echo "testEvaluateEnvVarNotSet: PASSED"

proc testEvaluateSimpleList() =
  let tokens = tokenize(simpleListSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkList
  assert conf.pairs[0].value.elements.len == 3
  assert conf.pairs[0].value.elements[0].strVal == "a"
  assert conf.pairs[0].value.elements[1].strVal == "b"
  assert conf.pairs[0].value.elements[2].strVal == "c"
  echo "testEvaluateSimpleList: PASSED"

proc testEvaluateListOfInts() =
  let tokens = tokenize(listOfIntsSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkList
  assert conf.pairs[0].value.elements[0].intVal == 1
  assert conf.pairs[0].value.elements[1].intVal == 2
  assert conf.pairs[0].value.elements[2].intVal == 3
  echo "testEvaluateListOfInts: PASSED"

proc testEvaluateTuple() =
  let source = "coords = [1, \"two\", 3]"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkTuple
  assert conf.pairs[0].value.elements.len == 3
  echo "testEvaluateTuple: PASSED"

proc testEvaluateEmptyList() =
  let tokens = tokenize(emptyListSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkList
  assert conf.pairs[0].value.elements.len == 0
  echo "testEvaluateEmptyList: PASSED"

proc testEvaluateBlock() =
  let tokens = tokenize(simpleBlockSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.blocks.len == 1
  assert conf.blocks[0].name == "database"
  assert conf.blocks[0].pairs.len == 2
  assert conf.blocks[0].pairs[0].key == "host"
  assert conf.blocks[0].pairs[0].value.strVal == "localhost"
  assert conf.blocks[0].pairs[1].key == "port"
  assert conf.blocks[0].pairs[1].value.intVal == 5432
  echo "testEvaluateBlock: PASSED"

proc testEvaluateNestedBlock() =
  let tokens = tokenize(nestedBlockSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  let dbBlock = conf.blocks[0]
  assert dbBlock.name == "database"
  assert dbBlock.subBlocks.len == 1
  assert dbBlock.subBlocks[0].name == "pool"
  assert dbBlock.subBlocks[0].pairs[0].key == "max"
  echo "testEvaluateNestedBlock: PASSED"

proc testEvaluateMultiplePairs() =
  let tokens = tokenize(multiplePairsSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs.len == 3
  assert conf.pairs[0].key == "name"
  assert conf.pairs[1].key == "version"
  assert conf.pairs[2].key == "active"
  echo "testEvaluateMultiplePairs: PASSED"

proc testEvaluateNegativeNumber() =
  let tokens = tokenize(negNumberSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkInt
  assert conf.pairs[0].value.intVal == -42
  echo "testEvaluateNegativeNumber: PASSED"

proc testEvaluatePositiveNumber() =
  let tokens = tokenize(posNumberSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkInt
  assert conf.pairs[0].value.intVal == 42
  echo "testEvaluatePositiveNumber: PASSED"

proc testEvaluateNegativeFloat() =
  let tokens = tokenize(negFloatSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkFloat
  assert conf.pairs[0].value.floatVal == -1.5
  echo "testEvaluateNegativeFloat: PASSED"

proc testEvaluateScientificNotation() =
  let tokens = tokenize(sciNotSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkFloat
  assert conf.pairs[0].value.floatVal == 1.5e+10
  echo "testEvaluateScientificNotation: PASSED"

proc testEvaluateInclude() =
  let tokens = tokenize(includeSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.includes.len == 1
  assert conf.includes[0].includePath == ".env"
  echo "testEvaluateInclude: PASSED"

proc testEvaluateBlockWithNestedBlocks() =
  let tokens = tokenize(blockNestedSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  let app = conf.blocks[0]
  assert app.name == "app"
  assert app.subBlocks.len == 2
  assert app.subBlocks[0].name == "server"
  assert app.subBlocks[1].name == "database"
  echo "testEvaluateBlockWithNestedBlocks: PASSED"

proc testEvaluateMixedListTypes() =
  let tokens = tokenize(mixedListSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.kind == vkTuple
  assert conf.pairs[0].value.elements.len == 3
  echo "testEvaluateMixedListTypes: PASSED"

proc testEvaluateStringWithEscapes() =
  let tokens = tokenize(stringEscapesSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].value.strVal == "hello\nworld\ttab"
  echo "testEvaluateStringWithEscapes: PASSED"

proc testEvaluatePairLineAndCol() =
  let tokens = tokenize(pairLineColSource)
  let ast = createNodes(tokens)
  let conf = evaluateConfig(ast)
  assert conf.pairs[0].line > 0
  assert conf.pairs[0].col > 0
  echo "testEvaluatePairLineAndCol: PASSED"

proc runEvaluatorTests() =
  echo "=== RUNNING EVALUATOR TESTS ==="
  testEvaluateStringLiteral()
  testEvaluateIntLiteral()
  testEvaluateFloatLiteral()
  testEvaluateBoolTrue()
  testEvaluateBoolFalse()
  testEvaluateEnvVar()
  testEvaluateEnvVarNotSet()
  testEvaluateSimpleList()
  testEvaluateListOfInts()
  testEvaluateTuple()
  testEvaluateEmptyList()
  testEvaluateBlock()
  testEvaluateNestedBlock()
  testEvaluateMultiplePairs()
  testEvaluateNegativeNumber()
  testEvaluatePositiveNumber()
  testEvaluateNegativeFloat()
  testEvaluateScientificNotation()
  testEvaluateInclude()
  testEvaluateBlockWithNestedBlocks()
  testEvaluateMixedListTypes()
  testEvaluateStringWithEscapes()
  testEvaluatePairLineAndCol()
  echo "=== ALL EVALUATOR TESTS PASSED ==="
  echo "Total: 23 tests"

runEvaluatorTests()