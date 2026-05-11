##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils, sets, options, streams
import dotenv
import ../yumly_file
import ../types/nodes
import ../phases/tokenizer, ../phases/parser
import ../error_messages

const allowedIncludeExts = [".env", ".yumly", ".yuy"]

proc getCanonicalPath(rawPath: string, baseDir: string, node: YumNode): string =
  ## Resolves symlinks and returns an absolute, normalized path.
  let absoluteBase = if isAbsolute(baseDir): baseDir else: absolutePath(baseDir)
  let combined = if isAbsolute(rawPath): rawPath
                 else: normalizedPath(absoluteBase / rawPath)

  try:
    result = os.expandFilename(combined)
  except OSError:
    includeFileNotFoundError(rawPath, combined, node.line, node.col)

import ../utils/recursion

proc processIncludes(rootNode: YumNode; baseDir: string; visited: var HashSet[string],
    depth: var int): seq[YumNode] =
  ## Recursively processes includes and returns a new list of children with includes resolved in-place.
  if not rootNode.hasIncludes.get(false):
    return rootNode.children

  result = @[]
  withRecursionGuard(depth, rootNode.line, rootNode.col):
    for child in rootNode.children:
      if child.kind == nkInclude:
        let resolvedPath = getCanonicalPath(child.includePath, baseDir, child)

        let sf = os.splitFile(resolvedPath)
        var ext = sf.ext.toLowerAscii()
        if ext.len == 0 and sf.name.toLowerAscii() == ".env":
          ext = ".env"

        if ext notin allowedIncludeExts:
          includeUnsupportedExtError(resolvedPath, ext, child.line, child.col)

        if resolvedPath in visited:
          circularIncludeError(resolvedPath, child.line, child.col)

        case ext:
          of ".env":
            visited.incl(resolvedPath)
            try:
              let sfEnv = os.splitFile(resolvedPath)
              let envDir = if sfEnv.dir.len == 0: "." else: sfEnv.dir
              let envFile = sfEnv.name & sfEnv.ext
              load(envDir, envFile)
            except CatchableError as error:
              failedToLoadFile(resolvedPath, child.line, child.col, error.msg)
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
              for n in includedAST.children:
                n.sourceFile = resolvedPath
            except CatchableError as error:
              failedToLoadFile(resolvedPath, child.line, child.col, error.msg)

            visited.incl(resolvedPath)
            let resolvedChildren = processIncludes(includedAST, parentDir(resolvedPath), visited, depth)
            visited.excl(resolvedPath)

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
