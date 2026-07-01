import std/terminal

proc info*(msg: string) =
  setForegroundColor(stderr, fgYellow)
  stderr.writeLine(msg)
  resetAttributes(stderr)

proc success*(msg: string) =
  setForegroundColor(stderr, fgGreen)
  stderr.writeLine(msg)
  resetAttributes(stderr)

proc loaded*(cuteMessage = "") =
  setForegroundColor(stderr, fgGreen)
  stderr.write("✓ Loaded!")
  if cuteMessage.len > 0:
    setForegroundColor(stderr, fgMagenta)
    stderr.write("  ♡  " & cuteMessage)
  stderr.writeLine("")
  resetAttributes(stderr)

proc checked*() =
  setForegroundColor(stderr, fgGreen)
  stderr.write("✓ Valid!")
  when defined(yumlycliCute):
    setForegroundColor(stderr, fgMagenta)
    stderr.write("  ♡  everything looks cute :3")
  stderr.writeLine("")
  resetAttributes(stderr)

proc error*(msg: string) =
  setForegroundColor(stderr, fgRed)
  stderr.writeLine(msg)
  resetAttributes(stderr)
