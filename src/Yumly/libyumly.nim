import api/nim_api
export nim_api

when defined(python):
  import nimpy
  # nimpy doesn't generate PyInit_* unless at least one {.exportpy.} symbol exists.
  # this dummy export ensures the Python module is initialized correctly.
  func nimpy_anchor*(): int {.exportpy.} = 0
  include api/python_api
else:
  import api/c_api
  export c_api
