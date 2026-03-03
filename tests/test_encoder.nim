import ../src/Yumly/api/nim_api
import ../src/Yumly/types/ast

proc runEncoderTest() =
  var cfg = newYumly()
  cfg.addInclude(".env")
  cfg.addInclude("secrets.yuy")

  cfg.addPair("project_name", newStringValue("Test Project"), "string")
  cfg.addPair("version", newStringValue("1.0.0"))
  cfg.addPair("is_active", newBoolValue(true), "bool")
  cfg.addPair("tags", newListValue(@[newStringValue("api"), newStringValue("v1")]))

  var dbBlock = newBlock("database")
  dbBlock.addPair("host", newStringValue("localhost"), "string")
  dbBlock.addPair("port", newIntValue(5432), "int")
  dbBlock.addPair("password", newEnvValue("DB_PASS"), "env")

  var poolBlock = newBlock("pool")
  poolBlock.addPair("max_connections", newIntValue(100))
  poolBlock.addPair("min_connections", newIntValue(10))
  dbBlock.addSubBlock(poolBlock)

  cfg.addBlock(dbBlock)

  var serverBlock = newBlock("server")
  serverBlock.addPair("listen", newStringValue("0.0.0.0"))
  serverBlock.addPair("options", newTupleValue(@[newStringValue("opt1"),
      newBoolValue(false)]))
  cfg.addBlock(serverBlock)

  let dumped = dumpYumly(cfg)
  echo "--- YUMLY ENCODER OUTPUT ---"
  echo dumped
  echo "----------------------------"

runEncoderTest()
