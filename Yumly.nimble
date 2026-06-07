# Package

version       = "0.9.0"
author        = "Yumene"
description   = "A cute, declarative config language with fail-fast behavior and optional type safety."
license       = "MIT"

# Source tree lives in ./src; public entrypoint is src/Yumly.nim which re-exports
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.8", "nimpy >= 0.2.0", "dotenv >= 0.3.0"
