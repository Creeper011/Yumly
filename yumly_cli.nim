

import os
import Yumly

proc parseOutput() =
    let args = commandLineParams()
    if args.len > 0:
        echo loadYumly(args[0])
    else:
        echo "please provide a .yumly file path as an argument"
  
parseOutput()