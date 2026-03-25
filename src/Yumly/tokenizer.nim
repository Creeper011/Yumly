##
#  This module defines the tokenizer for the Yumly configuration language.
#  It converts a raw source string into a sequence of tokens that can be
#  easily parsed by the parser.
##

import std/strutils
import types/token

template col(startPos: int): int = startPos - lineStart + 1

template emit(k: TokenKind, startPos: int) =
  tokens.add(Token(kind: k, line: line, col: col(startPos)))

template emitVal(k: TokenKind, v: string, startPos: int) =
  tokens.add(Token(kind: k, line: line, col: col(startPos), value: v))

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
        raise newException(ValueError, "Heyy, the comment doesn't close! Expected '<;' at line " & $line)

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
          raise newException(ValueError,
            "Heyy invalid exponent on line " & $line)
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
      let quote = source[i]
      # the start of the string with the quote
      let stringStart = i
      i += 1
      # the start of the string without the quote
      let start = i
      while i < source.len and source[i] != quote:
        if source[i] == '\\':
          i += 2 # we skip the backslash and the character after it, evaluator (via value_defs) will resolve it
          continue

        if source[i] == '\n':
          raise newException(ValueError, "Heyy the string doesn't close on line " & $line)
        i += 1
      
      if i >= source.len:
        raise newException(ValueError, "Heyy the string doesn't close at the end of the file on line " & $line)
      
      emitVal(tkString, source[start..i-1], stringStart)
      i += 1

    else:
      # handle identifiers and keywords
      if source[i] in IdentStartChars + {'/', '.'}:
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
        raise newException(ValueError,
          "Wow, an unexpected character '" & $source[i] & "' on line " & $line)

  emit(tkEOF, source.len)
  return tokens
