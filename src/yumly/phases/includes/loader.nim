##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils, sets, streams
import ../../utils/file
import ../../types/nodes
import ../../types/errors
import ../tokenizer/tokenizer, ../parser/parser
import ../../error_messages
import path_resolver, env_loader

const allowedIncludeExts = [".env", ".yumly", ".yuy"]

type
  IncludeSource = ref object
    puller: NodePuller
    stream: Stream
    baseDir: string
    sourceFile: string
    includeLine: int
    includeCol: int

proc includeExt(resolvedPath: string): string =
  let fileExt = os.splitFile(resolvedPath).ext.toLowerAscii()
  if fileExt.len == 0 and os.splitFile(resolvedPath).name.toLowerAscii() == ".env":
    ".env"
  else:
    fileExt

proc markSourceFile(node: YumNode, sourceFile: string) =
  if node == nil or sourceFile.len == 0:
    return

  # If the included parser did not tag the node, inherit the active source file.
  if node.sourceFile == "":
    node.sourceFile = sourceFile

proc attachSourceFile(error: ref YumlyError, sourceFile: string) =
  if error.sourceFile.len == 0:
    error.sourceFile = sourceFile

proc attachSourceFile(error: ref YumlyIOError, sourceFile: string) =
  if error.sourceFile.len == 0:
    error.sourceFile = sourceFile

proc actualBaseDir(baseDir, sourceFile: string): string =
  if sourceFile.len > 0:
    try:
      return parentDir(os.expandFilename(sourceFile))
    except OSError:
      discard

  if baseDir.len == 0:
    return "."

  try:
    let canonicalBase = os.expandFilename(baseDir)
    if fileExists(canonicalBase):
      return parentDir(canonicalBase)
    return canonicalBase
  except OSError:
    return baseDir

proc loadIncludes*(upstream: NodePuller; baseDir: string = ".";
    sourceFile: string = ""): NodePuller =
  var visited = initHashSet[string]()
  var stack = @[IncludeSource(puller: upstream, stream: nil,
      baseDir: actualBaseDir(baseDir, sourceFile), sourceFile: sourceFile,
      includeLine: 0, includeCol: 0)]

  if sourceFile.len > 0:
    try:
      visited.incl(os.expandFilename(sourceFile))
    except OSError:
      visited.incl(sourceFile)

  return proc(): YumNode {.closure.} =
    while stack.len > 0:
      let source = stack[^1]
      var node: YumNode

      try:
        node = source.puller()
      except YumlyError as error:
        if source.stream == nil:
          raise

        source.stream.close()
        error.attachSourceFile(source.sourceFile)
        raise error
      except YumlyIOError as error:
        if source.stream == nil:
          raise

        source.stream.close()
        error.attachSourceFile(source.sourceFile)
        raise error
      except CatchableError as error:
        # If the error came from an included stream, report it as a load failure.
        if source.stream == nil:
          raise

        source.stream.close()
        failedToLoadFile(source.sourceFile, source.includeLine,
            source.includeCol, error.msg)

      if node.kind == nkEOF:
        # If an included stream ended, close it and resume the parent stream.
        if source.stream != nil:
          source.stream.close()
        if source.sourceFile.len > 0 and stack.len > 1:
          visited.excl(source.sourceFile)
        discard stack.pop()

        if stack.len == 0:
          return node
        continue

      markSourceFile(node, source.sourceFile)

      # If this node is not include, pass it downstream unchanged.
      if node.kind != nkInclude:
        return node

      let resolvedPath = getCanonicalPath(node.includePath, source.baseDir,
          node.line, node.col)
      checkSandbox(resolvedPath, node.line, node.col)

      let ext = includeExt(resolvedPath)
      # If the include extension is unknown, fail before opening the file.
      if ext notin allowedIncludeExts:
        includeUnsupportedExtError(resolvedPath, ext, node.line, node.col)

      # If the resolved path is already active, the include chain is circular.
      if resolvedPath in visited:
        circularIncludeError(resolvedPath, node.line, node.col)

      case ext:
      of ".env":
        visited.incl(resolvedPath)
        loadEnvFile(resolvedPath, node.line, node.col)
        visited.excl(resolvedPath)
        return node

      of ".yumly", ".yuy":
        try:
          let stream = newYumlyStream(resolvedPath)
          let puller = parseNodes(tokenize(stream))
          visited.incl(resolvedPath)
          stack.add(IncludeSource(puller: puller, stream: stream,
              baseDir: parentDir(resolvedPath), sourceFile: resolvedPath,
              includeLine: node.line, includeCol: node.col))
          return node
        except CatchableError as error:
          failedToLoadFile(resolvedPath, node.line, node.col, error.msg)

      else:
        discard

    YumNode(kind: nkEOF)
