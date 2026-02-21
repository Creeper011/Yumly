

import os
import src/yumly_core

proc parseOutput() =
    let args = commandLineParams()
    if args.len > 0:
        echo parseConfig(args[0])
    else:
        echo "please provide a .yumly file path as an argument"
  
parseOutput()