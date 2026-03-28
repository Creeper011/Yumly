import ../../src/Yumly/api/nim_api
import ../../src/Yumly/serializers/encoder
import ../../src/Yumly/core/builders
import ../../src/Yumly/core/pipeline
import ../../src/Yumly/libyumly
import os

proc runEncoderTest() =
  putEnv("DB_PASS", "secret_password")
  var cfg = newYumly()
  # NOTE: in validation, this will check the env file.. but it will fail if the env file is not present
  #cfg.addInclude(".env")

  cfg.addPair("project_name", newStringValue("Test Project"), "string")
  cfg.addPair("description", newStringValue("\tAn \"test\" project\nwith multiples features"), "string")
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

  var magicNumbers = newBlock("magicNumbers")
  magicNumbers.addPair("pi_precision", newFloatValue(3.14159265))
  magicNumbers.addPair("uptime_goal", newFloatValue(1.5e+3))
  magicNumbers.addPair("postive_number", newIntValue(+1))
  magicNumbers.addPair("negative_number", newIntValue(-1))
  magicNumbers.addPair("zero", newIntValue(0))
  magicNumbers.addPair("negative_float", newFloatValue(-1.0))
  magicNumbers.addPair("postive_float", newFloatValue(+1.0))
  magicNumbers.addPair("zero_float", newFloatValue(0.0))

  cfg.addBlock(dbBlock)
  cfg.addBlock(magicNumbers)

  var serverBlock = newBlock("server")
  serverBlock.addPair("listen", newStringValue("0.0.0.0"))
  serverBlock.addPair("options", newTupleValue(@[newStringValue("opt1"),
      newBoolValue(false)]))
  cfg.addBlock(serverBlock)

  let dumped = encoder.dumpYumly(cfg)
  echo "--- YUMLY ENCODER OUTPUT ---"
  echo dumped
  echo "----------------------------"

  echo "Validating dumped content..."
  if not validateContent(dumped):
    echo "FAILED: Dumped content is invalid Yumly code!"
    quit(1)

  echo "Loading dumped content back..."
  let loaded = pipeline.loadYumlyContent(dumped)

  assert loaded["project_name"].getStr() == "Test Project"
  assert loaded["description"].getStr() == "\tAn \"test\" project\nwith multiples features"
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

  let loadedMagicNumbers = loaded.getBlock("magicNumbers")
  assert loadedMagicNumbers["pi_precision"].getFloat() == 3.14159265
  assert loadedMagicNumbers["uptime_goal"].getFloat() == 1.5e+3
  assert loadedMagicNumbers["postive_number"].getInt() == 1
  assert loadedMagicNumbers["negative_number"].getInt() == -1
  assert loadedMagicNumbers["zero"].getInt() == 0
  assert loadedMagicNumbers["negative_float"].getFloat() == -1.0
  assert loadedMagicNumbers["postive_float"].getFloat() == 1.0
  assert loadedMagicNumbers["zero_float"].getFloat() == 0.0

  echo "SUCCESS: Round-trip validation passed!"

runEncoderTest()
