import ../src/Yumly/api/nim_api
import ../src/Yumly/types/ast
import tables

proc runWriteTest() =
  let t = {"key1": newStringValue("hello"), "key2": newIntValue(42)}.toTable
  let mapped = toYumly(t, inferType = true)
  echo "--- TABLE TO YUMLY WITH INFER TYPE ---"
  echo mapped

  var cfg = newYumly()
  cfg.addPair("output", newStringValue("this is written to a file"))
  writeYumly(cfg, "test_out.yumly", inferType = true)
  echo "--- Wrote config to test_out.yumly ---"

runWriteTest()
