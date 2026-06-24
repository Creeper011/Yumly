import std/terminal

template info*(msg: string) =
  setForegroundColor(fgYellow)
  echo msg
  resetAttributes()

template success*(msg: string) =
  setForegroundColor(fgGreen)
  echo msg
  resetAttributes()

template error*(msg: string) =
  setForegroundColor(fgRed)
  echo msg
  resetAttributes()
