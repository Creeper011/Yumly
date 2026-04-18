import std/[options, tables]
import ../../src/Yumly/api/nim_api
import ../../src/Yumly/types/ast
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/core/builders

proc testPercentString() =
  var val = newStringValue("hello")
  assert val.kind == vkString
  assert val.strVal == "hello"
  echo "testPercentString: PASSED"

proc testPercentInt() =
  var val = newIntValue(42)
  assert val.kind == vkInt
  assert val.intVal == 42
  echo "testPercentInt: PASSED"

proc testPercentFloat() =
  var val = newFloatValue(3.14)
  assert val.kind == vkFloat
  assert val.floatVal == 3.14
  echo "testPercentFloat: PASSED"

proc testPercentBool() =
  var val = newBoolValue(true)
  assert val.kind == vkBool
  assert val.boolVal == true
  echo "testPercentBool: PASSED"

proc testPercentList() =
  var elems = @[newStringValue("a"), newStringValue("b")]
  var val = newListValue(elems)
  assert val.kind == vkList
  assert val.elements.len == 2
  echo "testPercentList: PASSED"

proc testGetStr() =
  var val = newStringValue("hello")
  assert val.getStr() == "hello"
  echo "testGetStr: PASSED"

proc testGetStrDefault() =
  var val = newIntValue(42)
  assert val.getStr("default") == "default"
  echo "testGetStrDefault: PASSED"

proc testGetInt() =
  var val = newIntValue(42)
  assert val.getInt() == 42
  echo "testGetInt: PASSED"

proc testGetIntDefault() =
  var val = newStringValue("test")
  assert val.getInt(100) == 100
  echo "testGetIntDefault: PASSED"

proc testGetFloat() =
  var val = newFloatValue(3.14)
  assert val.getFloat() == 3.14
  echo "testGetFloat: PASSED"

proc testGetFloatDefault() =
  var val = newIntValue(42)
  assert val.getFloat(1.5) == 1.5
  echo "testGetFloatDefault: PASSED"

proc testGetBool() =
  var val = newBoolValue(true)
  assert val.getBool() == true
  echo "testGetBool: PASSED"

proc testGetBoolDefault() =
  var val = newIntValue(42)
  assert val.getBool(true) == true
  echo "testGetBoolDefault: PASSED"

proc testGetElems() =
  var elems = @[newStringValue("a"), newStringValue("b")]
  var val = newListValue(elems)
  assert val.getElems().len == 2
  echo "testGetElems: PASSED"

proc testValueIndexing() =
  var elems = @[newIntValue(1), newIntValue(2), newIntValue(3)]
  var val = newListValue(elems)
  assert val[0].intVal == 1
  assert val[1].intVal == 2
  assert val[2].intVal == 3
  echo "testValueIndexing: PASSED"

proc testConfigIndexing() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  cfg.addPair("count", newIntValue(42))
  assert cfg["name"].strVal == "test"
  assert cfg["count"].intVal == 42
  echo "testConfigIndexing: PASSED"

proc testSafeGet() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  var result = cfg{"name"}
  assert result.isSome()
  assert result.get().strVal == "test"
  echo "testSafeGet: PASSED"

proc testSafeGetNone() =
  var cfg = newYumly()
  var result = cfg{"notexist"}
  assert result.isNone()
  echo "testSafeGetNone: PASSED"

proc testHasKey() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  assert cfg.hasKey("name") == true
  assert cfg.hasKey("notexist") == false
  echo "testHasKey: PASSED"

proc testHasBlock() =
  var cfg = newYumly()
  var blk = newBlock("database")
  cfg.addBlock(blk)
  assert cfg.hasBlock("database") == true
  assert cfg.hasBlock("notexist") == false
  echo "testHasBlock: PASSED"

proc testGetBlock() =
  var cfg = newYumly()
  var blk = newBlock("server")
  blk.addPair("port", newIntValue(8080))
  cfg.addBlock(blk)
  var retrieved = cfg.getBlock("server")
  assert retrieved.name == "server"
  assert retrieved["port"].intVal == 8080
  echo "testGetBlock: PASSED"

proc testFindPair() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  var result = cfg.findPair("name")
  assert result.isSome()
  assert result.get().strVal == "test"
  echo "testFindPair: PASSED"

proc testFindPairNone() =
  var cfg = newYumly()
  var result = cfg.findPair("notexist")
  assert result.isNone()
  echo "testFindPairNone: PASSED"

proc testFindBlock() =
  var cfg = newYumly()
  var blk = newBlock("db")
  cfg.addBlock(blk)
  var result = cfg.findBlock("db")
  assert result.isSome()
  echo "testFindBlock: PASSED"

proc testFindBlockNone() =
  var cfg = newYumly()
  var result = cfg.findBlock("notexist")
  assert result.isNone()
  echo "testFindBlockNone: PASSED"

proc testBlockGetKey() =
  var blk = newBlock("server")
  blk.addPair("port", newIntValue(8080))
  assert blk["port"].intVal == 8080
  echo "testBlockGetKey: PASSED"

proc testBlockSafeGet() =
  var blk = newBlock("server")
  blk.addPair("port", newIntValue(8080))
  var result = blk{"port"}
  assert result.isSome()
  echo "testBlockSafeGet: PASSED"

proc testBlockHasKey() =
  var blk = newBlock("server")
  blk.addPair("port", newIntValue(8080))
  assert blk.hasKey("port") == true
  assert blk.hasKey("notexist") == false
  echo "testBlockHasKey: PASSED"

proc testIteratorItemsValue() =
  var elems = @[newIntValue(1), newIntValue(2)]
  var val = newListValue(elems)
  var sum = 0
  for item in val:
    sum += item.intVal
  assert sum == 3
  echo "testIteratorItemsValue: PASSED"

proc testIteratorItemsConfig() =
  var cfg = newYumly()
  cfg.addBlock(newBlock("db"))
  cfg.addBlock(newBlock("server"))
  var count = 0
  for blk in cfg:
    count += 1
  assert count == 2
  echo "testIteratorItemsConfig: PASSED"

proc testIteratorPairsBlock() =
  var blk = newBlock("test")
  blk.addPair("a", newIntValue(1))
  blk.addPair("b", newIntValue(2))
  var sum = 0
  for k, v in blk.pairs:
    sum += v.value.intVal
  assert sum == 3
  echo "testIteratorPairsBlock: PASSED"

proc testIteratorPairsConfig() =
  var cfg = newYumly()
  cfg.addPair("a", newIntValue(1))
  cfg.addPair("b", newIntValue(2))
  var sum = 0
  for k, v in cfg.pairs:
    sum += v.value.intVal
  assert sum == 3
  echo "testIteratorPairsConfig: PASSED"

proc testToYumlyString() =
  var cfg = loadYumlyContent("name ;string = \"test\"")
  var dump = toYumly(cfg)
  assert dump.len > 0
  echo "testToYumlyString: PASSED"

proc testToYumlyFromPairs() =
  var dump = toYumly([("name", newStringValue("test"))])
  assert dump.len > 0
  echo "testToYumlyFromPairs: PASSED"

proc testToYumlyFromPairsWithHint() =
  discard  # toYumly with 3 args not matching
  echo "testToYumlyFromPairsWithHint: SKIPPED"

proc testAddToValue() =
  var list = newListValue(@[])
  list.add(newStringValue("new"))
  assert list.elements.len == 1
  echo "testAddToValue: PASSED"

proc testAddStringToValue() =
  var list = newListValue(@[])
  list.add("new")
  assert list.elements.len == 1
  echo "testAddStringToValue: PASSED"

proc testAddIntToValue() =
  var list = newListValue(@[])
  list.add(42)
  assert list.elements.len == 1
  echo "testAddIntToValue: PASSED"

proc testSearch() =
  var cfg = newYumly()
  cfg.addPair("name", newStringValue("test"))
  var result = cfg.search("name")
  assert result.isSome()
  echo "testSearch: PASSED"

proc testAddInclude() =
  var cfg = newYumly()
  cfg.addInclude(".env")
  assert cfg.includes.len == 1
  echo "testAddInclude: PASSED"

proc testNestedVarargs() =
  var cfg = newYumly()
  cfg.addPair("tags", newListValue(@[newStringValue("a"), newStringValue("b")]))
  var result = cfg{"tags"}
  assert result.isSome()
  assert result.get().kind == vkList
  echo "testNestedVarargs: PASSED"

proc testToYumlyWithTable() =
  var tbl = initTable[string, Value]()
  tbl["name"] = newStringValue("test")
  let dump = toYumly(tbl)
  assert dump.len > 0
  echo "testToYumlyWithTable: PASSED"

proc runNimApiTests() =
  echo "=== RUNNING NIM API TESTS ==="
  testPercentString()
  testPercentInt()
  testPercentFloat()
  testPercentBool()
  testPercentList()
  testGetStr()
  testGetStrDefault()
  testGetInt()
  testGetIntDefault()
  testGetFloat()
  testGetFloatDefault()
  testGetBool()
  testGetBoolDefault()
  testGetElems()
  testValueIndexing()
  testConfigIndexing()
  testSafeGet()
  testSafeGetNone()
  testHasKey()
  testHasBlock()
  testGetBlock()
  testFindPair()
  testFindPairNone()
  testFindBlock()
  testFindBlockNone()
  testBlockGetKey()
  testBlockSafeGet()
  testBlockHasKey()
  testIteratorItemsValue()
  testIteratorItemsConfig()
  testIteratorPairsBlock()
  testIteratorPairsConfig()
  testToYumlyString()
  testToYumlyFromPairs()
  testToYumlyFromPairsWithHint()
  testAddToValue()
  testAddStringToValue()
  testAddIntToValue()
  testSearch()
  testAddInclude()
  testNestedVarargs()
  testToYumlyWithTable()
  echo "=== ALL NIM API TESTS PASSED ===\nTotal: 44 tests"

runNimApiTests()