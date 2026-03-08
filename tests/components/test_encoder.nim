import ../../src/Yumly/api/nim_api
import ../../src/Yumly/serializers/encoder
import ../../src/Yumly/libyumly
import os

proc runEncoderTest() =
  putEnv("DB_PASS", "secret_password")
  var cfg = newYumly()

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

  echo "Validating dumped content..."
  if not validateContent(dumped):
    echo "FAILED: Dumped content is invalid Yumly code!"
    quit(1)

  echo "Loading dumped content back..."
  let loaded = loadYumlyContent(dumped)

  assert loaded["project_name"].getStr() == "Test Project"
  assert loaded["version"].getStr() == "1.0.0"
  assert loaded["is_active"].getBool() == true
  assert loaded["tags"].getElems()[0].getStr() == "api"
  assert loaded["tags"].getElems()[1].getStr() == "v1"

  let loadedDb = loaded.getBlock("database")
  assert loadedDb["host"].getStr() == "localhost"
  assert loadedDb["port"].getInt() == 5432

  let loadedPool = loadedDb.getBlock("pool")
  assert loadedPool["max_connections"].getInt() == 100
  assert loadedPool["min_connections"].getInt() == 10

  let loadedServer = loaded.getBlock("server")
  assert loadedServer["listen"].getStr() == "0.0.0.0"
  assert loadedServer["options"][0].getStr() == "opt1"
  assert loadedServer["options"][1].getBool() == false

  echo "SUCCESS: Round-trip validation passed!"

runEncoderTest()
