##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils, sets, options, streams
import ../../utils/file
import ../../types/nodes
import ../tokenizer/tokenizer, ../parser/parser
import ../../error_messages
import ../../utils/recursion
import path_resolver, env_loader

const allowedIncludeExts = [".env", ".yumly", ".yuy"]

proc processIncludes(rootNode: YumNode; baseDir: string; visited: var HashSet[string],
    depth: var int): seq[YumNode] =
  ## Recursively processes includes and returns a new list of children with includes resolved in-place.
  if not rootNode.hasIncludes.get(false):
    return rootNode.children

  result = @[]
  withRecursionGuard(depth, rootNode.line, rootNode.col):
    for child in rootNode.children:
      if child.kind == nkInclude:
        let resolvedPath = getCanonicalPath(child.includePath, baseDir, child.line, child.col)
        checkSandbox(resolvedPath, child.line, child.col)

        let fileExt = os.splitFile(resolvedPath).ext.toLowerAscii()
        let ext = if fileExt.len == 0 and os.splitFile(resolvedPath).name.toLowerAscii() == ".env":
          ".env"
        else:
          fileExt

        if ext notin allowedIncludeExts:
          includeUnsupportedExtError(resolvedPath, ext, child.line, child.col)

        if resolvedPath in visited:
          circularIncludeError(resolvedPath, child.line, child.col)

        case ext:
          of ".env":
            visited.incl(resolvedPath)
            loadEnvFile(resolvedPath, child.line, child.col)
            visited.excl(resolvedPath)

          of ".yumly", ".yuy":
            var includedAST: YumNode
            try:
              let stream = newYumlyStream(resolvedPath)
              let puller = tokenize(stream)
              var parser = newParser(puller)
              includedAST = parser.parse()
              stream.close()
              includedAST.sourceFile = resolvedPath
              for node in includedAST.children:
                node.sourceFile = resolvedPath
            except CatchableError as error:
              failedToLoadFile(resolvedPath, child.line, child.col, error.msg)

            visited.incl(resolvedPath)
            let resolvedChildren = processIncludes(includedAST, parentDir(resolvedPath), visited, depth)
            visited.excl(resolvedPath)

            # propagate flags from the included file up to the root node.
            if includedAST.hasTypeHints.get(false):
              rootNode.hasTypeHints = some(true)

            if includedAST.hasEnvVars.get(false):
              rootNode.hasEnvVars = some(true)

            for includedChild in resolvedChildren:
              result.add(includedChild)
      else:
        if child.sourceFile == "":
          discard
        result.add(child)

proc loadIncludes*(rootNode: YumNode; baseDir: string = ".") =
  ## Public entry point for include resolution.
  var visited = initHashSet[string]()
  var depth = 0

  var actualBaseDir = baseDir
  try:
    if rootNode.sourceFile != "":
      let canonicalRoot = os.expandFilename(rootNode.sourceFile)
      visited.incl(canonicalRoot)
      actualBaseDir = parentDir(canonicalRoot)
    elif baseDir != "":
      let canonicalBase = os.expandFilename(baseDir)
      if fileExists(canonicalBase):
        visited.incl(canonicalBase)
        actualBaseDir = parentDir(canonicalBase)
      else:
        actualBaseDir = canonicalBase
  except OSError:
    discard

  if actualBaseDir == "": actualBaseDir = "."

  rootNode.children = processIncludes(rootNode, actualBaseDir, visited, depth)
