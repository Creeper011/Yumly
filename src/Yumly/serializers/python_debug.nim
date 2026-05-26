import nimpy
import options
import ../types/[nodes, token]

proc tokenToPy*(t: Token, pyBuiltins: PyObject): PyObject =
  let dict = pyBuiltins.dict()
  dict["kind"] = pyBuiltins.str($t.kind)
  dict["line"] = pyBuiltins.int(t.line)
  dict["col"] = pyBuiltins.int(t.col)
  if t.kind in {tkString, tkIdent, tkLiteral}:
    dict["value"] = pyBuiltins.str(t.value)
  return dict

proc astToPy*(node: YumNode, pyBuiltins: PyObject): PyObject =
  if node == nil:
    return pyBuiltins.None

  let dict = pyBuiltins.dict()
  dict["kind"] = pyBuiltins.str($node.kind)
  dict["name"] = pyBuiltins.str(node.name)
  dict["line"] = pyBuiltins.int(node.line)
  dict["col"] = pyBuiltins.int(node.col)
  if node.sourceFile != "":
    dict["sourceFile"] = pyBuiltins.str(node.sourceFile)

  case node.kind:
  of nkLiteral:
    dict["rawValue"] = pyBuiltins.str(node.rawValue)
  of nkPair:
    dict["key"] = pyBuiltins.str(node.key)
    if node.typeHint.isSome:
      dict["typeHint"] = pyBuiltins.str(node.typeHint.get().raw)
    dict["valNode"] = astToPy(node.valNode, pyBuiltins)
  of nkInclude:
    dict["includePath"] = pyBuiltins.str(node.includePath)
  of nkConfig:
    if node.hasIncludes.isSome:
      dict["hasIncludes"] = pyBuiltins.bool(node.hasIncludes.get())
    if node.hasTypeHints.isSome:
      dict["hasTypeHints"] = pyBuiltins.bool(node.hasTypeHints.get())
    if node.hasEnvVars.isSome:
      dict["hasEnvVars"] = pyBuiltins.bool(node.hasEnvVars.get())
  else:
    discard

  if node.children.len > 0:
    let childrenPy = pyBuiltins.list()
    for child in node.children:
      discard childrenPy.append(astToPy(child, pyBuiltins))
    dict["children"] = childrenPy
  return dict
