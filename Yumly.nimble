# Package
version       = "0.7.0"
author        = "Creeper011"
description   = "A declarative config language inspired by YAML/JSON with type safety"
license       = "MIT"

# Source tree lives in ./src; public entrypoint is src/Yumly.nim which re-exports
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.8", "nimpy >= 0.2.0", "dotenv >= 0.3.0"
