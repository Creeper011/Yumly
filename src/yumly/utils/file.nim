import os, strutils, streams
import ../errors/exceptions/parser/ioerrors
import ../types/[document, source]

const defaultMaxBytes = 52_428_800

proc checkFileExtension*(path: string) =
  if not (path.endsWith(".yumly") or path.endsWith(".yuy") or path.endsWith(".yu")):
    invalidFileExtensionError(path)

func documentKindFor*(sourceFile: SourceFile): DocumentKind =
  if sourceFile != nil and
      splitFile(sourceFile.path).ext.toLowerAscii() == ".yu":
    dkSchema
  else:
    dkConfig

proc openFileContent*(filePath: string): string =
  if not fileExists(filePath):
    fileNotFoundError(filePath)
  readFile(filePath)

proc newYumlyStream*(path: string): Stream =
  checkFileExtension(path)
  if not fileExists(path):
    fileNotFoundError(path)

  let fileSize = getFileSize(path)
  if fileSize > defaultMaxBytes:
    fileTooLargeError(path, fileSize, defaultMaxBytes)

  result = newFileStream(path, fmRead)
  if result == nil:
    # This shouldn't happen if fileExists is true, but good to be safe
    couldNotOpenFileError(path)
