# Package

version       = "0.10.0"
author        = "Yumene"
description   = "A cute, declarative config language with fail-fast behavior and optional type safety."
license       = "MIT"

# Source tree lives in ./src; public entrypoint is src/Yumly.nim which re-exports
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.8", "nimpy >= 0.2.0", "dotenv", "yaml"

import std/[os, strutils]

const
  buildDir = "build"
  binDir = buildDir / "bin"
  toolsDir = buildDir / "tools"
  nimLibDir = buildDir / "lib" / "nim"
  cLibDir = buildDir / "lib" / "c"
  pythonLibDir = buildDir / "lib" / "python" / "yumly"
  nimcacheDir = buildDir / "nimcache"
  packageDir = buildDir / "packages"

let
  executableSuffix = when defined(windows): ".exe" else: ""
  sharedLibrarySuffix = when defined(windows): ".dll" elif defined(macosx): ".dylib" else: ".so"
  pythonExtensionSuffix = when defined(windows): ".pyd" else: ".so"

proc extraNimFlags(): string =
  let flags = getEnv("YUMLY_NIM_FLAGS")
  if flags.len > 0:
    result = " " & flags

proc compile(source, output, cache: string; flags: openArray[string]) =
  mkDir(parentDir(output))
  mkDir(cache)

  var command = "nim c"
  for flag in flags:
    command.add " " & flag
  command.add " --nimcache:" & quoteShell(cache)
  command.add " --out:" & quoteShell(output)
  command.add extraNimFlags()
  command.add " " & quoteShell(source)
  exec command

task buildCli, "Build the Yumly CLI under build/bin":
  compile(
    "src/cli/yumly_cli.nim",
    binDir / ("yumly-cli" & executableSuffix),
    nimcacheDir / "cli",
    [
      "-d:release", "--opt:size", "--opt:speed", "--debuginfo:off",
      "--lineTrace:off", "-d:yumlycliCute", "-d:yumlyEnv",
      "-d:yumlyDotenv", "-d:yumlyJson", "-d:yumly32", "-d:yumlyTrivia",
      "-d:yumlyYaml", "-d:yumlySuggestions", "-d:yumlyCuteErrors"
    ]
  )

task buildNim, "Build the Yumly shared library under build/lib/nim":
  compile(
    "src/yumly/libyumly.nim",
    nimLibDir / ("libyumly" & sharedLibrarySuffix),
    nimcacheDir / "nim-library",
    ["-d:release", "--app:lib", "--opt:size", "--opt:speed", "--debuginfo:off", "--lineTrace:off"]
  )

task buildC, "Build the Yumly C library under build/lib/c":
  compile(
    "src/yumly/libyumly.nim",
    cLibDir / ("libyumly" & sharedLibrarySuffix),
    nimcacheDir / "c-library",
    ["-d:release", "--app:lib", "--opt:size", "--opt:speed", "--debuginfo:off", "--lineTrace:off"]
  )

task buildPython, "Build the Python extension under build/lib/python/yumly":
  var flags = @[
    "-d:release", "-d:python", "-d:yumlyEnv", "-d:yumlyDotenv",
    "-d:yumlyPythonYaml", "-d:yumlyPythonJson", "-d:yumlyCuteErrors",
    "-d:yumly32", "-d:yumlySuggestions", "--app:lib",
    "--lineTrace:off", "--debuginfo:off"
  ]
  when defined(windows):
    flags.add "--cc:vcc"

  compile(
    "src/yumly/libyumly.nim",
    pythonLibDir / ("libyumly" & pythonExtensionSuffix),
    nimcacheDir / "python",
    flags
  )

task buildTools, "Build repository tools under build/tools":
  compile(
    "utils/change_version.nim",
    toolsDir / ("change_version" & executableSuffix),
    nimcacheDir / "tools" / "change-version",
    ["-d:release", "--opt:size", "--debuginfo:off", "--lineTrace:off"]
  )
  compile(
    "utils/markers_finder.nim",
    toolsDir / ("markers_finder" & executableSuffix),
    nimcacheDir / "tools" / "markers-finder",
    ["-d:release", "--opt:size", "--debuginfo:off", "--lineTrace:off"]
  )

task checkSources, "Semantically check the public Nim library and CLI":
  mkDir(nimcacheDir / "check-library")
  mkDir(nimcacheDir / "check-cli")
  exec "nim check --nimcache:" & quoteShell(nimcacheDir / "check-library") & extraNimFlags() & " src/yumly.nim"
  exec "nim check -d:yumlyEnv -d:yumlyJson -d:yumlyTrivia --nimcache:" &
    quoteShell(nimcacheDir / "check-cli") & extraNimFlags() & " src/cli/yumly_cli.nim"

task packagePython, "Build the Python sdist and wheel under build/packages":
  mkDir(packageDir)
  let python = if fileExists(".venv/bin/python"): ".venv/bin/python" else: "python3"
  exec quoteShell(python) & " -m build --outdir " & quoteShell(packageDir)

task clean, "Remove generated files under build":
  if dirExists(buildDir):
    rmDir(buildDir)
