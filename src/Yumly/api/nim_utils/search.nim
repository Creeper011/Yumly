##
# Search utilities for Nim API
##

import std/options
import ../../types/ast
import ../../error_messages

func findPair*(config: YumlyConf, key: string): Option[Value] =
  for pair in config.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

func findPair*(blk: Block, key: string): Option[Value] =
  for pair in blk.pairs:
    if pair.key == key: return some(pair.value)
  return none(Value)

func findBlock*(config: YumlyConf, name: string): Option[Block] =
  for blk in config.blocks:
    if blk.name == name: return some(blk)
  return none(Block)

func findBlock*(blk: Block, name: string): Option[Block] =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return some(subBlock)
  return none(Block)

func hasKey*(config: YumlyConf, key: string): bool =
  for pair in config.pairs:
    if pair.key == key: return true
  return false

func hasKey*(blk: Block, key: string): bool =
  for pair in blk.pairs:
    if pair.key == key: return true
  return false

func hasBlock*(config: YumlyConf, name: string): bool =
  for blk in config.blocks:
    if blk.name == name: return true
  return false

func hasBlock*(blk: Block, name: string): bool =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return true
  return false

func getBlock*(config: YumlyConf, name: string): Block =
  for blk in config.blocks:
    if blk.name == name: return blk
  blockNotFoundError(name)

func getBlock*(blk: Block, name: string): Block =
  for subBlock in blk.subBlocks:
    if subBlock.name == name: return subBlock
  subBlockNotFoundError(name)
