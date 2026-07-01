##
# Search utilities for Nim API
##

import std/options
import ../../../types/ast
import ../../../errors/exceptions/apierrors

func findPair*(config: YumlyConf, key: string): Option[Value] =
  for item in config.items:
    if item.kind == ikPair and item.pair.key == key:
      return some(item.pair.value)
  return none(Value)

func findPair*(blk: Block, key: string): Option[Value] =
  for item in blk.items:
    if item.kind == ikPair and item.pair.key == key:
      return some(item.pair.value)
  return none(Value)

func findBlock*(config: YumlyConf, name: string): Option[Block] =
  for item in config.items:
    if item.kind == ikBlock and item.blk.name == name:
      return some(item.blk)
  return none(Block)

func findBlock*(blk: Block, name: string): Option[Block] =
  for item in blk.items:
    if item.kind == ikBlock and item.blk.name == name:
      return some(item.blk)
  return none(Block)

func hasKey*(config: YumlyConf, key: string): bool =
  for item in config.items:
    if item.kind == ikPair and item.pair.key == key: return true
  return false

func hasKey*(blk: Block, key: string): bool =
  for item in blk.items:
    if item.kind == ikPair and item.pair.key == key: return true
  return false

func hasBlock*(config: YumlyConf, name: string): bool =
  for item in config.items:
    if item.kind == ikBlock and item.blk.name == name: return true
  return false

func hasBlock*(blk: Block, name: string): bool =
  for item in blk.items:
    if item.kind == ikBlock and item.blk.name == name: return true
  return false

func getBlock*(config: YumlyConf, name: string): Block =
  for item in config.items:
    if item.kind == ikBlock and item.blk.name == name: return item.blk
  blockNotFoundError(name)

func getBlock*(blk: Block, name: string): Block =
  for item in blk.items:
    if item.kind == ikBlock and item.blk.name == name: return item.blk
  subBlockNotFoundError(name)
