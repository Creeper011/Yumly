##
#  This module defines the tokenizer for the Yumly configuration language.
#  It converts a raw source string into a sequence of tokens that can be
#  easily parsed by the parser.
##

import std/strutils
import types/token
import error_messages

template col(startPos: int): int = startPos - lineStart + 1

template emit(k: TokenKind, startPos: int) =
  tokens.add(Token(kind: k, line: line, col: col(startPos)))

template emitVal(k: TokenKind, val: string, startPos: int) =
  tokens.add(Token(kind: k, line: line, col: col(startPos), value: val))

template emitValFull(k: TokenKind, l: int, column: int, val: string) =
  tokens.add(Token(kind: k, line: l, col: column, value: val))

proc tokenize*(source: string): seq[Token] =
  # Tokenize the source, we will iterate through each character and build tokens based on the rules of the Yumly language.
  var tokens: seq[Token]
  tokens = newSeqOfCap[Token](source.len div 4) 
  var i         = 0
  var line      = 1
  var lineStart = 0

  while i < source.len:
    # skip whitespace
    if source[i] in {' ', '\t', '\r'}:
      i += 1
      continue
    
    # count lines and advances
    if source[i] == '\n':
      line += 1
      lineStart = i + 1
      i += 1
      continue
    
    # handle comments with an lookahead for ";> ... <;"
    if i + 1 < source.len and source[i..i+1] == ";>":
      let closePos = source.find("<;", start = i + 2)
      if closePos >= 0:
        var j = i + 2
        while j < closePos:
          if source[j] == '\n':
            line += 1
            lineStart = j + 1
          j += 1
        i = closePos + 2
        continue
      else:
        commentNotClosedError(line, col(i))

    # handle literals (int, float)
    # emit an tkLiteral token
    if source[i] in {'0'..'9'} or (source[i] in {'+', '-'} and i + 1 < source.len and source[i + 1] in {'0'..'9'}):
      # consume first digit or sign
      let start = i
      i += 1

      # consume the other digits
      while i < source.len and source[i] in {'0'..'9'}:
        i += 1

      # consume float part
      if i < source.len and source[i] == '.':
        i += 1
        while i < source.len and source[i] in {'0'..'9'}:
          i += 1

      # consume exponent part
      if i < source.len and source[i] in {'e', 'E'}:
        i += 1
        if i < source.len and source[i] in {'+', '-'}:
          i += 1
        if i >= source.len or source[i] notin {'0'..'9'}:
          invalidExponentError(line, col(start))
        while i < source.len and source[i] in {'0'..'9'}:
          i += 1

      emitVal(tkLiteral, source[start ..< i], start)
      continue

    case source[i]
    of '(': emit(tkLParen, i);      i += 1
    of ')': emit(tkRParen, i);      i += 1
    of '{': emit(tkLBrace, i);      i += 1
    of '}': emit(tkRBrace, i);      i += 1
    of '[': emit(tkLBracket, i);    i += 1
    of ']': emit(tkRBracket, i);    i += 1
    of '=': emit(tkEquals, i);      i += 1
    of ';': emit(tkDeclaration, i); i += 1
    of ',': emit(tkComma, i);       i += 1
    of '$': emit(tkDollar, i);      i += 1
    # if string
    of '"', '\'':
      let quoteChar = source[i]
      let startLine = line
      let startCol  = col(i)
      var stringContent = ""
      
      # multiline string logic
      if quoteChar == '"' and i + 2 < source.len and source[i+1] == '"' and source[i+2] == '"':
        i += 3 # skip opening """
        
        # skip leading formatting on the first line with buffering
        var buffer = ""
        while i < source.len:
          if i + 1 < source.len and source[i] == '\\':
            buffer.add(source[i .. i+1])
            i += 2
          elif source[i] == '\n':
            # hit newline: skip all whitespace and \n escapes in the buffer
            # but keep other escapes (like \t) as they are likely content
            var j = 0
            while j < buffer.len:
              if buffer[j] == '\\' and j + 1 < buffer.len:
                if buffer[j+1] != 'n':
                  stringContent.add(buffer[j .. j+1])
                j += 2
              else: # discard whitespace
                j += 1
            
            # skip the newline itself
            i += 1
            line += 1
            lineStart = i
            break
          elif source[i] in {' ', '\t', '\r'}:
            buffer.add(source[i])
            i += 1
          else:
            # hit actual content: keep the full buffer
            stringContent.add(buffer)
            break

        # main loop of the multiline string
        while i < source.len:
          # handle escaped triple quote
          if i + 3 < source.len and source[i..i+3] == "\\\"\"\"":
            stringContent.add("\\\"")
            i += 4
            continue
          
          # handle real closing delimiter
          if i + 2 < source.len and source[i..i+2] == "\"\"\"":
            i += 3
            break
          
          # handle regular escapes
          if source[i] == '\\' and i + 1 < source.len:
            stringContent.add(source[i])
            stringContent.add(source[i+1])
            if source[i+1] == '\n': 
              line += 1
              lineStart = i + 2
            i += 2
            continue

          # handle regular character & line tracking
          if source[i] == '\n':
            line += 1
            lineStart = i + 1
          
          stringContent.add(source[i])
          i += 1
        
        # strip trailing newline before the closing delimiter
        if stringContent.len > 0 and stringContent[^1] == '\n':
          stringContent.setLen(stringContent.len - 1)
          
        emitValFull(tkString, startLine, startCol, stringContent)
        
      # single line logic
      else:
        i += 1 # skip opening quote
        while i < source.len and source[i] != quoteChar:
          if source[i] == '\\' and i + 1 < source.len:
            # pass escape sequence through raw for the parser
            stringContent.add(source[i .. i+1])
            i += 2
          elif source[i] == '\n':
            unclosedStringError(line, startCol)
          else:
            stringContent.add(source[i])
            i += 1
        
        if i >= source.len:
          unclosedStringAtEofError()
        
        emitValFull(tkString, startLine, startCol, stringContent)
        i += 1 # skip closing quote

    else:
      # handle identifiers and keywords
      if source[i] in IdentStartChars:
        let start = i
        while i < source.len and source[i] in IdentChars + {'/', '.', '-', '/'}:
          i += 1
        let word = source[start..i-1]
        case word:
          of "include":
            emit(tkInclude, start)
          of "true", "false":
            emitVal(tkLiteral, word, start)
          else:
            emitVal(tkIdent, word, start)
      else:
        unexpectedCharError($source[i], line, col(i))

  emit(tkEOF, source.len)
  return tokens
