# Defines the main relevant constants for the Yumly.
# 
# if you're searching for code errors constants, 
# see: src/yumly/errors/codes.nim

const FileDefaultMaxBytes = 52_428_800
const MaxRecursionDepth* = 20000 # maximum recursion depth
const InitialContextCapacity* {.intdefine.} = 6 # aplicable to parser, tokenizer context