

import os
import src/Yumly/libyumly

proc parseOutput() =
    let args = commandLineParams()
    if args.len > 0:
        try:
            echo loadYumly(args[0])
        except CatchableError as e:
            echo e.msg
    else:
        echo "please provide a .yumly file path as an argument"
  
parseOutput()