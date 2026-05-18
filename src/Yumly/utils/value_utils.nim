import ../types/ast

func inferTypeHint*(val: Value): string =
  case val.kind
  of vkString: return "string"
  of vkInt: return "int"
  of vkFloat: return "float"
  of vkBool: return "bool"
  of vkList:
    if val.elements.len > 0:
      return "list[" & inferTypeHint(val.elements[0]) & "]"
    return "list[string]"
  of vkTuple: return "tuple"
  of vkEnv: return "env"
