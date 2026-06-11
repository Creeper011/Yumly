import api/nim/api
export api

when defined(python):
  import nimpy
  # NOTE: nimpy doesn't generate PyInit_* unless at least one {.exportpy.} symbol exists.
  # NOTE: this dummy export ensures the Python module is initialized correctly.
  func nimpy_anchor*(): int {.exportpy.} = 0
  include api/python/python_api
else:
  import api/c/c_api
  export c_api

when defined(yumlyJson):
  import serializers/json/json_encoder
  export json_encoder

when defined(yumlyYaml):
  import serializers/yaml/yaml_encoder
  export yaml_encoder
