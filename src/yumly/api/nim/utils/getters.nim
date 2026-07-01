##
# Getters for Nim API
##

import ../../../types/ast
import ../../../errors/exceptions/apierrors

func getStr*(val: Value): string =
  if val.kind != vkString:
    expectedTypeError("string", $val.kind)
  return val.strVal

func getStr*(val: Value, default: string): string =
  if val.kind != vkString: return default
  return val.strVal

func getInt*(val: Value): int =
  if val.kind != vkInt:
    expectedTypeError("int", $val.kind)
  return val.intVal

func getInt*(val: Value, default: int): int =
  if val.kind != vkInt: return default
  return val.intVal

func getFloat*(val: Value): float =
  if val.kind != vkFloat:
    expectedTypeError("float", $val.kind)
  return val.floatVal

func getFloat*(val: Value, default: float): float =
  if val.kind != vkFloat: return default
  return val.floatVal

func getBool*(val: Value): bool =
  if val.kind != vkBool:
    expectedTypeError("bool", $val.kind)
  return val.boolVal

func getBool*(val: Value, default: bool): bool =
  if val.kind != vkBool: return default
  return val.boolVal

func getList*(val: Value): seq[Item] =
  if val.kind != vkList:
    expectedTypeError("list", $val.kind)
  return val.elements

func getList*(val: Value, default: seq[Item]): seq[Item] =
  if val.kind != vkList: return default
  return val.elements
