import unittest
import std/[strutils, os]
import Yumly

test "parse example.yumly without errors":
  # Locate example.yumly relative to this test file, so it works regardless of cwd.
  let testDir = splitFile(currentSourcePath()).dir
  let examplePath = normalizedPath(joinPath(parentDir(testDir), "example.yumly"))
  let parsed = loadYumly(examplePath)
  # basic sanity checks on the serialized AST output
  check parsed.contains("app")
  check parsed.contains("discord")

  echo "parsed config:" & parsed

test "loadYumly default path fails for missing file":
  expect ValueError:
    discard loadYumly("missing.yumly")
