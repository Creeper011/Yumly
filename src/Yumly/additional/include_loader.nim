##
# This module is responsible for loading included resources in Yumly.
##

import os, strutils
import dotenv
import ../types/ast

const allowedIncludeExts = [".env"]

proc loadIncludes*(rootNode: YumNode) =
  for child in rootNode.children:
    if child.kind == nkInclude:
      let includePath = child.rawValue
      
      if not os.fileExists(includePath):
        raise newException(IOError,
          "Heeeh?! i can't find '" & includePath & "' anywhere... (T_T)\n" &
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

      if ext == ".env":
        try:
          let sfEnv   = os.splitFile(includePath)
          let envDir  = if sfEnv.dir.len == 0: "." else: sfEnv.dir
          let envFile = sfEnv.name & sfEnv.ext
          load(envDir, envFile)
        except CatchableError as e:
          raise newException(IOError,
            "Ih... something went wrong while loading the .env file! (>_<)\n" &
            "  file: '" & includePath & "'\n" &
            "  line: " & $child.line & ", column: " & $child.col & "\n" &
            "  detail: " & e.msg
          )
