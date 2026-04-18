import std/options
import ../../src/Yumly/core/builders
import ../../src/Yumly/types/ast
import ../../src/Yumly/types/type_hints

proc testNewStringValue() =
  var val = newStringValue("hello")
  assert val.kind == vkString
  assert val.strVal == "hello"
  echo "testNewStringValue: PASSED"

proc testNewIntValue() =
  var val = newIntValue(42)
  assert val.kind == vkInt
  assert val.intVal == 42
  echo "testNewIntValue: PASSED"

proc testNewFloatValue() =
  var val = newFloatValue(3.14)
  assert val.kind == vkFloat
  assert val.floatVal == 3.14
  echo "testNewFloatValue: PASSED"

proc testNewBoolValueTrue() =
  var val = newBoolValue(true)
  assert val.kind == vkBool
  assert val.boolVal == true
  echo "testNewBoolValueTrue: PASSED"

proc testNewBoolValueFalse() =
  var val = newBoolValue(false)
  assert val.boolVal == false
  echo "testNewBoolValueFalse: PASSED"

proc testNewEnvValue() =
  var val = newEnvValue("DB_PASS", "secret")
  assert val.kind == vkEnv
  assert val.envName == "DB_PASS"
  assert val.envVal == "secret"
  echo "testNewEnvValue: PASSED"

proc testNewEnvValueDefault() =
  var val = newEnvValue("MY_VAR")
  assert val.envName == "MY_VAR"
  assert val.envVal == "MY_VAR"
  echo "testNewEnvValueDefault: PASSED"

proc testNewListValue() =
  var elems = @[newStringValue("a"), newStringValue("b")]
  var val = newListValue(elems)
  assert val.kind == vkList
  assert val.elements.len == 2
  echo "testNewListValue: PASSED"

proc testNewListValueEmpty() =
  var elems: seq[Value] = @[]
  var val = newListValue(elems)
  assert val.elements.len == 0
  echo "testNewListValueEmpty: PASSED"

proc testNewTupleValue() =
  var elems = @[newIntValue(1), newIntValue(2)]
  var val = newTupleValue(elems)
  assert val.kind == vkTuple
  echo "testNewTupleValue: PASSED"

proc testNewYumly() =
  var cfg = newYumly()
  assert cfg.pairs.len == 0
  assert cfg.blocks.len == 0
  assert cfg.includes.len == 0
  echo "testNewYumly: PASSED"

proc testNewBlock() =
  var blk = newBlock("database")
  assert blk.name == "database"
  assert blk.pairs.len == 0
  assert blk.subBlocks.len == 0
  echo "testNewBlock: PASSED"

proc testAddPairToYumly() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"), "string")
  assert cfg.pairs.len == 1
  assert cfg.pairs[0].key == "name"
  echo "testAddPairToYumly: PASSED"

proc testAddPairToYumlyNoHint() =
  var cfg = newYumly()
  cfg.addPair("count", newIntValue(42))
  assert cfg.pairs.len == 1
  assert cfg.pairs[0].value.intVal == 42
  echo "testAddPairToYumlyNoHint: PASSED"

proc testAddPairToBlock() =
  var blk = newBlock("server")
  blk.addPair("port", newIntValue(8080), "int")
  assert blk.pairs.len == 1
  assert blk.pairs[0].key == "port"
  echo "testAddPairToBlock: PASSED"

proc testAddBlockToYumly() =
  var cfg = newYumly()
  var dbBlock = newBlock("database")
  cfg.addBlock(dbBlock)
  assert cfg.blocks.len == 1
  assert cfg.blocks[0].name == "database"
  echo "testAddBlockToYumly: PASSED"

proc testAddSubBlock() =
  var parent = newBlock("app")
  var server = newBlock("server")
  parent.addSubBlock(server)
  assert parent.subBlocks.len == 1
  assert parent.subBlocks[0].name == "server"
  echo "testAddSubBlock: PASSED"

proc testMultiplePairs() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  cfg.addPair("count", newIntValue(42))
  cfg.addPair("active", newBoolValue(true))
  assert cfg.pairs.len == 3
  echo "testMultiplePairs: PASSED"

proc testNestedBlocks() =
  var cfg = newYumly()
  var app = newBlock("app")
  var server = newBlock("server")
  server.addPair("port", newIntValue(8080))
  app.addSubBlock(server)
  cfg.addBlock(app)
  var loadedApp = cfg.blocks[0]
  assert loadedApp.subBlocks.len == 1
  echo "testNestedBlocks: PASSED"

proc testAddPairWithTypeHint() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"), "string")
  assert cfg.pairs[0].typeHint.isSome()
  echo "testAddPairWithTypeHint: PASSED"

proc testAddPairWithoutTypeHint() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  assert cfg.pairs[0].typeHint.isNone()
  echo "testAddPairWithoutTypeHint: PASSED"

proc testNewBlockWithLineCol() =
  var blk = newBlock("test")
  assert blk.line == 0
  assert blk.col == 0
  echo "testNewBlockWithLineCol: PASSED"

proc testMixedListElements() =
  var elems = @[newStringValue("a"), newIntValue(1), newFloatValue(1.5)]
  var val = newListValue(elems)
  assert val.elements.len == 3
  echo "testMixedListElements: PASSED"

proc testCreateComplexConfig() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("MyApp"))
  cfg.addPair("version", newStringValue("1.0.0"))
  cfg.addPair("debug", newBoolValue(false))

  var db = newBlock("database")
  db.addPair("host", newStringValue("localhost"))
  db.addPair("port", newIntValue(5432))

  var pool = newBlock("pool")
  pool.addPair("max", newIntValue(100))
  db.addSubBlock(pool)

  cfg.addBlock(db)

  assert cfg.pairs.len == 3
  assert cfg.blocks.len == 1
  assert cfg.blocks[0].pairs.len == 2
  echo "testCreateComplexConfig: PASSED"

proc runBuildersTests() =
  echo "=== RUNNING BUILDERS TESTS ==="
  testNewStringValue()
  testNewIntValue()
  testNewFloatValue()
  testNewBoolValueTrue()
  testNewBoolValueFalse()
  testNewEnvValue()
  testNewEnvValueDefault()
  testNewListValue()
  testNewListValueEmpty()
  testNewTupleValue()
  testNewYumly()
  testNewBlock()
  testAddPairToYumly()
  testAddPairToYumlyNoHint()
  testAddPairToBlock()
  testAddBlockToYumly()
  testAddSubBlock()
  testMultiplePairs()
  testNestedBlocks()
  testAddPairWithTypeHint()
  testAddPairWithoutTypeHint()
  testNewBlockWithLineCol()
  testMixedListElements()
  testCreateComplexConfig()
  echo "=== ALL BUILDERS TESTS PASSED ===\nTotal: 24 tests"

runBuildersTests()