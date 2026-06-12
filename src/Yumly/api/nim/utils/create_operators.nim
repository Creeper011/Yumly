##
# Creating operator for Nim API
##

import std/[tables, macros, sequtils]
import ../../../types/ast
import ../../../core/builders

# % operator for creating Values
func `y%`*(s: string): Value = newStringValue(s)
func `y%`*(i: int): Value = newIntValue(i)
func `y%`*(f: float): Value = newFloatValue(f)
func `y%`*(b: bool): Value = newBoolValue(b)
func `y%`*(elems: seq[Value]): Value = newListValue(elems)
func `y%`*(t: tuple): Value =
  var elems: seq[Value] = @[]
  for k, v in t.fieldPairs:
    elems.add(`y%`(v))
  newListValue(elems)

func `y%`*(keyVals: openArray[tuple[key: string, val: Value]]): YumlyConf =
  result = newYumly()
  for kv in keyVals:
    result.addPair(kv.key, kv.val)

# %* macro for creating Values from expressions
macro `y*`*(x: untyped): untyped =
  proc `y*Recurse`(node: NimNode): NimNode =
    result = node
    case node.kind
    of nnkIntLit:
      result = newCall(bindSym"newIntValue", node)
    of nnkFloatLit:
      result = newCall(bindSym"newFloatValue", node)
    of nnkStrLit, nnkTripleStrLit:
      result = newCall(bindSym"newStringValue", node)
    of nnkIdent:
      if node.strVal == "true" or node.strVal == "false":
        result = newCall(bindSym"newBoolValue", node)
    of nnkBracket:
      let elems = node.mapIt(`y*Recurse`(it))
      result = newCall(bindSym"newListValue", newTree(nnkBracket, elems))
    of nnkPar, nnkTupleConstr:
      let elems = node.mapIt(`y*Recurse`(it))
      result = newCall(bindSym"newListValue", newTree(nnkBracket, elems))
    of nnkTableConstr:
      result = newCall(bindSym"newYumly")
      let pairs = node.mapIt(newTree(nnkExprColonExpr,
        newStrLitNode(it[0].strVal),
        `y*Recurse`(it[1])))
      result.add(newTree(nnkBracket, pairs))
    else:
      discard
  result = `y*Recurse`(x)
