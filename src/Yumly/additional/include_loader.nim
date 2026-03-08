##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils, sets
import dotenv
import ../types/nodes
import ../tokenizer, ../parser
import ../error_messages

const allowedIncludeExts = [".env", ".yumly", ".yuy"]

proc checkCircularImport(path: string, child: YumNode, visited: var HashSet[string]) =
  if path in visited:
    raise newException(IOError,
      "Circular include detected! '" & path & "' is already being loaded\n" &
      "  line: " & $child.line & ", column: " & $child.col
    )

proc loadIncludes(rootNode: YumNode; baseDir: string; visited: var HashSet[string]) =
  for child in rootNode.children:
    if child.kind == nkInclude:
      let rawIncludePath = child.includePath
      let includePath = if isAbsolute(rawIncludePath): rawIncludePath
                        else: baseDir / rawIncludePath
      
      if not os.fileExists(includePath):
        raise newException(IOError,
          "Heeeh?! i can't find '" & rawIncludePath & "' anywhere... (T_T)\n" &
          "  searched at: " & os.absolutePath(includePath) & "\n" &
          "  line: " & $child.line & ", column: " & $child.col & "\n" &
          "  hint: check if the path is correct and the file actually exists"
        )

      # checks the file extension
      let sf = os.splitFile(includePath)
      var ext = sf.ext.toLowerAscii()
      if ext.len == 0 and sf.name.toLowerAscii() == ".env":
        ext = ".env"
        
      if ext notin allowedIncludeExts:
        raise newException(ValueError,
          "Mmm, this file type isn't supported in include { } ;-; \n" &
          "  file: '" & includePath & "'\n" &
          "  got type: '" & ext & "'\n" &
          "  line: " & $child.line & ", column: " & $child.col & "\n" &
          "  hint: only " & allowedIncludeExts.join(", ") & " files are supported for now"
        )

      case ext:
        of ".env":
          let importPath = os.absolutePath(includePath)
          checkCircularImport(importPath, child, visited)
          visited.incl(importPath)
          try:
            let sfEnv  = os.splitFile(includePath)
            let envDir = if sfEnv.dir.len == 0: "." else: sfEnv.dir
            let envFile = sfEnv.name & sfEnv.ext
            load(envDir, envFile)
          except CatchableError as error:
            failedToLoadFile(includePath, child.line, child.col, error.msg)

        of ".yumly", ".yuy":
          let importPath = os.absolutePath(includePath)
          checkCircularImport(importPath, child, visited)
          var includedAST: YumNode
          try:
            let content = readFile(includePath)
            let tokens = tokenize(content)
            includedAST = generateAST(tokens)
          except CatchableError as error:
            failedToLoadFile(includePath, child.line, child.col, error.msg)

          visited.incl(importPath)
          loadIncludes(includedAST, parentDir(includePath), visited)
          
          for includedChild in includedAST.children:
            rootNode.children.add(includedChild)

proc loadIncludes*(rootNode: YumNode; baseDir: string = ".") =
  var visited = initHashSet[string]()
  loadIncludes(rootNode, baseDir, visited)
