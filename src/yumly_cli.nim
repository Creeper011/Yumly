import os
import yumly_core

proc main() =
  let args = commandLineParams()
  if args.len == 0:
    echo "please provide a .yumly file path as an argument"
    quit(1)
  echo parseConfig(args[0])

when isMainModule:
  main()
