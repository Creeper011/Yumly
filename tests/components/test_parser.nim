import std/options
import ../../src/Yumly/phases/tokenizer
import ../../src/Yumly/phases/parser
import ../../src/Yumly/types/nodes
import ../../src/Yumly/types/token
import ../../src/Yumly/types/type_hints

const
  q = "\"\"\""

const simplePairSource = "key ;string = \"value\""
const intValueSource = "count ;int = 42"
const floatValueSource = "pi = 3.14159"
const boolValueSource = "enabled ;bool = true"
const envVarSource = "db_password ;string = $[\"DB_PASSWORD\"]"
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
const listSource = "tags ;list[string] = [\"a\", \"b\", \"c\"]"
const tupleSource = "coords = [1, 2, 3]"
const includeSource = "include { \".env\" }"
const multiplePairsSource = """name ;string = "test",
version ;int = 1,
active ;bool = false"""
const complexConfigSource = """include { ".env" }
project ;string = "test",
(server) {
  host ;string = "localhost",
  port ;int = 8080
}"""
const emptyArraySource = "empty = []"
const blockNoTypeHintSource = """(settings) {
  debug = true
}"""
const posNegNumbersSource = """pos ;int = +10,
neg ;int = -5,
posFloat = +1.5,
negFloat = -2.5"""
const scientificSource = "big = 1.5e+10, small = 2.5e-5"
const multilineStringSource = "desc ;string = " & q & "This is a\nmultiline string\nwith multiple lines" & q
const hasEnvVarsSource = "key ;string = $[\"MY_VAR\"]"
const noTrailingCommaSource = """(db) {
  host = "localhost"
}"""

proc testParseSimplePair() =
  let tokens = tokenize(simplePairSource)
  let ast = createNodes(tokens)
  assert ast.kind == nkConfig
  assert ast.children.len == 1
  assert ast.children[0].kind == nkPair
  assert ast.children[0].key == "key"
  echo "testParseSimplePair: PASSED"

proc testParseIntValue() =
  let tokens = tokenize(intValueSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.kind == nkLiteral
  assert ast.children[0].valNode.rawValue == "42"
  echo "testParseIntValue: PASSED"

proc testParseFloatValue() =
  let tokens = tokenize(floatValueSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.kind == nkLiteral
  assert ast.children[0].valNode.rawValue == "3.14159"
  echo "testParseFloatValue: PASSED"

proc testParseBoolValue() =
  let tokens = tokenize(boolValueSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.rawValue == "true"
  echo "testParseBoolValue: PASSED"

proc testParseEnvVar() =
  let tokens = tokenize(envVarSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.kind == nkLiteral
  assert ast.children[0].valNode.rawValue == "DB_PASSWORD"
  echo "testParseEnvVar: PASSED"

proc testParseSimpleBlock() =
  let tokens = tokenize(simpleBlockSource)
  let ast = createNodes(tokens)
  assert ast.children.len == 1
  assert ast.children[0].kind == nkBlock
  assert ast.children[0].name == "database"
  assert ast.children[0].children.len == 2
  assert ast.children[0].children[0].key == "host"
  assert ast.children[0].children[1].key == "port"
  echo "testParseSimpleBlock: PASSED"

proc testParseNestedBlock() =
  let tokens = tokenize(nestedBlockSource)
  let ast = createNodes(tokens)
  let dbBlock = ast.children[0]
  assert dbBlock.name == "database"
  assert dbBlock.children[0].kind == nkBlock
  assert dbBlock.children[0].name == "pool"
  assert dbBlock.children[0].children[0].key == "max"
  echo "testParseNestedBlock: PASSED"

proc testParseList() =
  let tokens = tokenize(listSource)
  let ast = createNodes(tokens)
  let pair = ast.children[0]
  assert pair.typeHint.isSome()
  assert pair.typeHint.get().kind == thList
  assert pair.typeHint.get().raw == "list"
  assert pair.valNode.kind == nkArray
  assert pair.valNode.children.len == 3
  echo "testParseList: PASSED"

proc testParseTuple() =
  let tokens = tokenize(tupleSource)
  let ast = createNodes(tokens)
  let pair = ast.children[0]
  assert pair.valNode.kind == nkArray
  assert pair.valNode.children.len == 3
  echo "testParseTuple: PASSED"

proc testParseInclude() =
  let tokens = tokenize(includeSource)
  let ast = createNodes(tokens)
  assert ast.hasIncludes == some(true)
  assert ast.children.len == 1
  assert ast.children[0].kind == nkInclude
  assert ast.children[0].includePath == ".env"
  echo "testParseInclude: PASSED"

proc testParseMultiplePairs() =
  let tokens = tokenize(multiplePairsSource)
  let ast = createNodes(tokens)
  assert ast.children.len == 3
  assert ast.children[0].key == "name"
  assert ast.children[1].key == "version"
  assert ast.children[2].key == "active"
  echo "testParseMultiplePairs: PASSED"

proc testParseComplexConfig() =
  let tokens = tokenize(complexConfigSource)
  let ast = createNodes(tokens)
  assert ast.hasIncludes == some(true)
  assert ast.children[0].kind == nkInclude
  assert ast.children[1].kind == nkPair
  assert ast.children[1].key == "project"
  assert ast.children[2].kind == nkBlock
  assert ast.children[2].name == "server"
  echo "testParseComplexConfig: PASSED"

proc testParseEmptyArray() =
  let tokens = tokenize(emptyArraySource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.kind == nkArray
  assert ast.children[0].valNode.children.len == 0
  echo "testParseEmptyArray: PASSED"

proc testParseBlockWithoutTypeHint() =
  let tokens = tokenize(blockNoTypeHintSource)
  let ast = createNodes(tokens)
  let blk = ast.children[0]
  assert blk.name == "settings"
  assert blk.children[0].key == "debug"
  assert blk.children[0].typeHint.isNone()
  echo "testParseBlockWithoutTypeHint: PASSED"

proc testParsePositiveNegativeNumbers() =
  let tokens = tokenize(posNegNumbersSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.rawValue == "+10"
  assert ast.children[1].valNode.rawValue == "-5"
  assert ast.children[2].valNode.rawValue == "+1.5"
  assert ast.children[3].valNode.rawValue == "-2.5"
  echo "testParsePositiveNegativeNumbers: PASSED"

proc testParseScientificNotation() =
  let tokens = tokenize(scientificSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.rawValue == "1.5e+10"
  assert ast.children[1].valNode.rawValue == "2.5e-5"
  echo "testParseScientificNotation: PASSED"

proc testParseMultilineString() =
  let tokens = tokenize(multilineStringSource)
  let ast = createNodes(tokens)
  assert ast.children[0].valNode.kind == nkLiteral
  echo "testParseMultilineString: PASSED"

proc testHasTypeHintsFlag() =
  let tokens = tokenize(simplePairSource)
  let ast = createNodes(tokens)
  assert ast.hasTypeHints == some(true)
  echo "testHasTypeHintsFlag: PASSED"

proc testHasEnvVarsFlag() =
  let tokens = tokenize(hasEnvVarsSource)
  let ast = createNodes(tokens)
  assert ast.hasEnvVars == some(true)
  echo "testHasEnvVarsFlag: PASSED"

proc testParseNoTrailingComma() =
  let tokens = tokenize(noTrailingCommaSource)
  let ast = createNodes(tokens)
  assert ast.children[0].children.len == 1
  echo "testParseNoTrailingComma: PASSED"

proc runParserTests() =
  echo "=== RUNNING PARSER TESTS ==="
  testParseSimplePair()
  testParseIntValue()
  testParseFloatValue()
  testParseBoolValue()
  testParseEnvVar()
  testParseSimpleBlock()
  testParseNestedBlock()
  testParseList()
  testParseTuple()
  testParseInclude()
  testParseMultiplePairs()
  testParseComplexConfig()
  testParseEmptyArray()
  testParseBlockWithoutTypeHint()
  testParsePositiveNegativeNumbers()
  testParseScientificNotation()
  testParseMultilineString()
  testHasTypeHintsFlag()
  testHasEnvVarsFlag()
  testParseNoTrailingComma()
  echo "=== ALL PARSER TESTS PASSED ==="
  echo "Total: 20 tests"

runParserTests()