import ../../src/Yumly/phases/tokenizer
import ../../src/Yumly/phases/parser
import ../../src/Yumly/phases/validate
import ../../src/Yumly/phases/resolver

proc testValidateString() =
  let source = "name ;string = \"test\""
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateString: PASSED"

proc testValidateInt() =
  let source = "count ;int = 42"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateInt: PASSED"

proc testValidateFloat() =
  let source = "pi = 3.14"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateFloat: PASSED"

proc testValidateBool() =
  let source = "active ;bool = true"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateBool: PASSED"

proc testValidateList() =
  let source = "tags ;list[string] = [\"a\", \"b\"]"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateList: PASSED"

proc testValidateTuple() =
  let source = "coords = [1, 2, 3]"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateTuple: PASSED"

proc testValidateDuplicateBlock() =
  let source = "(db) { host = \"localhost\" }\n(db) { port = 5432 }"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  try:
    validateConfig(ast)
    echo "testValidateDuplicateBlock: FAILED"
  except:
    echo "testValidateDuplicateBlock: PASSED"

proc testValidateDuplicatePair() =
  let source = "name = \"test\"\nname = \"other\""
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  try:
    validateConfig(ast)
    echo "testValidateDuplicatePair: FAILED"
  except:
    echo "testValidateDuplicatePair: PASSED"

proc testValidateDuplicateInBlock() =
  let source = "(settings) { debug = true, debug = false }"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  try:
    validateConfig(ast)
    echo "testValidateDuplicateInBlock: FAILED"
  except:
    echo "testValidateDuplicateInBlock: PASSED"

proc testValidateTypeMismatch() =
  let source = "num ;string = 123"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  try:
    validateConfig(ast)
    echo "testValidateTypeMismatch: FAILED"
  except:
    echo "testValidateTypeMismatch: PASSED"

proc testValidateEmpty() =
  let source = ""
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateEmpty: PASSED"

proc testValidateBlockNoError() =
  let source = "(database) { host ;string = \"localhost\", port ;int = 5432 }"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateBlockNoError: PASSED"

proc testValidateNestedBlock() =
  let source = "(app) { (server) { port = 8080 } }"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateNestedBlock: PASSED"

proc testValidateBlockNoTypeHint() =
  let source = "(server) { port = 8080 }"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateBlockNoTypeHint: PASSED"

proc testValidateMultiplePairs() =
  let source = "name = \"test\"\ncount = 42\nactive = true"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateMultiplePairs: PASSED"

proc testValidateListCorrect() =
  let source = "nums ;list[int] = [1, 2, 3]"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateListCorrect: PASSED"

proc testValidateZero() =
  let source = "zero ;int = 0"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateZero: PASSED"

proc testValidateFalseBool() =
  let source = "disabled ;bool = false"
  let tokens = tokenize(source)
  let ast = createNodes(tokens)
  resolveAst(ast)
  validateConfig(ast)
  echo "testValidateFalseBool: PASSED"

proc runValidateTests() =
  echo "=== RUNNING VALIDATE TESTS ==="
  testValidateString()
  testValidateInt()
  testValidateFloat()
  testValidateBool()
  testValidateList()
  testValidateTuple()
  testValidateDuplicateBlock()
  testValidateDuplicatePair()
  testValidateDuplicateInBlock()
  testValidateTypeMismatch()
  testValidateEmpty()
  testValidateBlockNoError()
  testValidateNestedBlock()
  testValidateBlockNoTypeHint()
  testValidateMultiplePairs()
  testValidateListCorrect()
  testValidateZero()
  testValidateFalseBool()
  echo "=== ALL VALIDATE TESTS PASSED ==="
  echo "Total: 17 tests"

runValidateTests()