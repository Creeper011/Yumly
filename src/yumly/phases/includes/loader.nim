##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils, sets, streams
import ../../errors/exceptions/parser/ioerrors
import ../../types/errors
import ../../types/document
import ../../types/source
import ../../utils/file
import ../../types/nodes
import ../tokenizer/tokenizer, ../parser/parser
import path_resolver
when defined(yumlyDotenv):
  when not defined(yumlyEnv):
    {.error: "-d:yumlyDotenv requires -d:yumlyEnv".}
  import env_loader

const allowedIncludeExts = [".env", ".yumly", ".yuy", ".yu"]

type
  IncludeSource = ref object
    puller: NodePuller
    stream: Stream
    baseDir: string
    sourceFile: SourceFile
    includeSource: SourceSpan

proc includeExt(resolvedPath: string): string =
  let fileExt = os.splitFile(resolvedPath).ext.toLowerAscii()
  if fileExt.len == 0 and os.splitFile(resolvedPath).name.toLowerAscii() == ".env":
    ".env"
  else:
    fileExt

proc markSourceFile(node: YumNode, sourceFile: SourceFile) =
  if node == nil or sourceFile == nil:
    return

  # If the included parser did not tag the node, inherit the active source file.
  if node.sourceFile == nil:
    node.sourceFile = sourceFile
  if node.token.source.source == nil:
    node.token.source.source = sourceFile

proc attachSourceFile(error: ref YumlyError, sourceFile: SourceFile) =
  if sourceFile == nil:
    return
  if error.source.len == 0:
    error.source.add(sourceSpan(sourceFile, SourcePos(0), SourcePos(0)))
  else:
    for span in error.source.mitems:
      if span.source == nil:
        span.source = sourceFile

proc attachSourceFile(error: ref YumlyIOError, sourceFile: SourceFile) =
  if sourceFile == nil:
    return
  if error.source.len == 0:
    error.source.add(sourceSpan(sourceFile, SourcePos(0), SourcePos(0)))
  else:
    for span in error.source.mitems:
      if span.source == nil:
        span.source = sourceFile

proc actualBaseDir(baseDir: string, sourceFile: SourceFile): string =
  if sourceFile != nil:
    try:
      return parentDir(os.expandFilename(sourceFile.path))
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
    sourceFile: SourceFile = nil): NodePuller =
  var visited = initHashSet[string]()
  var stack = @[IncludeSource(puller: upstream, stream: nil,
      baseDir: actualBaseDir(baseDir, sourceFile), sourceFile: sourceFile,
      includeSource: sourceSpan(sourceFile, SourcePos(0), SourcePos(0)))]

  if sourceFile != nil:
    try:
      visited.incl(os.expandFilename(sourceFile.path))
    except OSError:
      visited.incl(sourceFile.path)

  return proc(): YumNode {.closure.} =
    while stack.len > 0:
      let source = stack[^1]
      var node: YumNode

      try:
        node = source.puller()
      except YumlyError as error:
        if source.stream != nil:
          source.stream.close()
        error.attachSourceFile(source.sourceFile)
        raise error
      except YumlyIOError as error:
        if source.stream != nil:
          source.stream.close()
        error.attachSourceFile(source.sourceFile)
        raise error
      except CatchableError as error:
        # If the error came from an included stream, report it as a load failure.
        if source.stream == nil:
          raise

        source.stream.close()
        failedToLoadFile(source.sourceFile.path, source.includeSource,
            error.msg)

      if node.kind == nkEOF:
        # If an included stream ended, close it and resume the parent stream.
        if source.stream != nil:
          source.stream.close()
        if source.sourceFile != nil and stack.len > 1:
          visited.excl(source.sourceFile.path)
        discard stack.pop()

        if stack.len == 0:
          return node
        continue

      markSourceFile(node, source.sourceFile)

      # If this node is not include, pass it downstream unchanged.
      if node.kind != nkInclude:
        return node

      let includeSource = node.token.source

      var newSources: seq[IncludeSource] = @[]
      for includePath in node.includesPath:
        when not (defined(yumlyEnv) and defined(yumlyDotenv)):
          if includeExt(includePath) == ".env":
            dotenvIncludeDisabledError(includePath, includeSource)

        let resolvedPath = getCanonicalPath(includePath, source.baseDir,
            includeSource)
        checkSandbox(resolvedPath, includeSource)

        let ext = includeExt(resolvedPath)
        # If the include extension is unknown, fail before opening the file.
        if ext notin allowedIncludeExts:
          includeUnsupportedExtError(resolvedPath, ext, includeSource)

        # If the resolved path is already active, the include chain is circular.
        if resolvedPath in visited:
          circularIncludeError(resolvedPath, includeSource)

        case ext:
        of ".env":
          when defined(yumlyEnv) and defined(yumlyDotenv):
            visited.incl(resolvedPath)
            loadEnvFile(resolvedPath, includeSource)
            visited.excl(resolvedPath)
          else:
            dotenvIncludeDisabledError(resolvedPath, includeSource)

        of ".yumly", ".yuy", ".yu":
          try:
            let stream = newYumlyStream(resolvedPath)
            let includedSource = SourceFile(path: resolvedPath)
            let puller = parseNodes(tokenize(stream,
                sourceFile = includedSource),
                if ext == ".yu": dkSchema else: dkConfig)
            visited.incl(resolvedPath)
            newSources.add(IncludeSource(puller: puller, stream: stream,
                baseDir: parentDir(resolvedPath),
                sourceFile: includedSource,
                includeSource: includeSource))
          except CatchableError as error:
            failedToLoadFile(resolvedPath, includeSource, error.msg)

        else:
          discard

      if newSources.len > 0:
        for i in countdown(newSources.high, 0):
          stack.add(newSources[i])

      return node

    YumNode(kind: nkEOF)
