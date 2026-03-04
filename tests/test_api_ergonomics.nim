import Yumly, std/os
# i probably gonna remove this later
# Create a dummy config file
let configPath = "test_config.yuy"
let content = """
appName = "TestApp",
version = 1,
debug = true
(settings) {
  timeout = 30.5,
  theme = "dark"
}
(users) {
  (alice) {
    name = "Alice",
    role = "admin"
  },
  (bob) {
    name = "Bob",
    role = "user"
  }
}
"""
writeFile(configPath, content)

try:
  let cfg = loadYumly(configPath)

  # Test indexing and getters
  echo "Testing indexing and getters..."
  assert cfg["appName"].getStr() == "TestApp"
  assert cfg["version"].getInt() == 1
  assert cfg["debug"].getBool() == true

  # Test nested access via block
  echo "Testing block access..."
  let settings = cfg.getBlock("settings")
  assert settings["timeout"].getFloat() == 30.5
  assert settings["theme"].getStr() == "dark"

  # Test iterator
  echo "Testing iterators..."
  var userNames: seq[string] = @[]
  for blk in cfg:
    if blk.name == "users":
      for user in blk:
        userNames.add(user["name"].getStr())

  assert userNames == @["Alice", "Bob"]

  # Test macro 'to'
  echo "Testing 'to' macro..."
  type
    User = object
      name: string
      role: string
    Config = object
      appName: string
      version: int
      debug: bool

  # Test individual object conversion
  let person = cfg.getBlock("users").subBlocks[0].to(User)
  assert person.name == "Alice"
  assert person.role == "admin"

  # Test full config conversion
  let appConfig = cfg.to(Config)
  assert appConfig.appName == "TestApp"
  assert appConfig.version == 1
  assert appConfig.debug == true

  echo "All API ergonomic tests passed!"

except Exception as e:
  echo "Test failed with error: ", e.msg
  quit(1)
finally:
  if fileExists(configPath):
    removeFile(configPath)
