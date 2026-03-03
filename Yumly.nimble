# Package

version       = "0.1.0"
author        = "Creeper011"
description   = "A declarative config language inspired by YAML/JSON with type safety"
license       = "MIT"

# Source tree lives in ./src; public entrypoint is src/Yumly.nim which re-exports
# the parser API from yumly_core.
srcDir        = "src"
installExt    = @["nim"]
bin           = @["Yumly"]


# Dependencies

requires "nim >= 2.0.8", "nimpy >= 0.2.0", "dotenv >= 0.3.0"
