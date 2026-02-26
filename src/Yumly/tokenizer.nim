##
#  This module defines the tokenizer for the Yumly configuration language.
#  It converts a raw source string into a sequence of tokens that can be
#  easily parsed by the parser.
##

import std/strutils
import types/token

template col(): int = i - lineStart + 1

template emit(k: TokenKind) =
  tokens.add(Token(kind: k, line: line, col: col()))

template emitVal(k: TokenKind, v: string) =
  tokens.add(Token(kind: k, line: line, col: col(), value: v))

proc tokenize*(source: string): seq[Token] =
  # Tokenize the source, we will iterate through each character and build tokens based on the rules of the Yumly language.
  var tokens: seq[Token]
  var i         = 0
  var line      = 1
  var lineStart = 0

  while i < source.len:

    if source[i] in {' ', '\t', '\r'}:
      i += 1
      continue

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

    # handle numbers (int or float)
    # check if the number contains more than 2 characters and if it's negative
    if source[i] in {'0'..'9'} or (source[i] == '-' and i + 1 < source.len and source[i + 1] in {'0'..'9'}):
      let start = i
      if source[i] == '-':
        i += 1
      while i < source.len and source[i] in {'0'..'9'}:
        i += 1
      if i < source.len and source[i] == '.' and i + 1 < source.len and source[i + 1] in {'0'..'9'}:
        i += 1
        while i < source.len and source[i] in {'0'..'9'}:
          i += 1
      # resolves scientific notations
      if i < source.len and (source[i] == 'e' or source[i] == 'E'):
        i += 1
        if i < source.len and (source[i] == '+' or source[i] == '-'):
          i += 1
        if i >= source.len or source[i] notin {'0'..'9'}:
          raise newException(ValueError, "Heyy invalid exponent on line " & $line)
        while i < source.len and source[i] in {'0'..'9'}:
          i += 1
      emitVal(tkNumber, source[start..i-1])
      continue

    case source[i]
    of '(': emit(tkLParen);      i += 1
    of ')': emit(tkRParen);      i += 1
    of '{': emit(tkLBrace);      i += 1
    of '}': emit(tkRBrace);      i += 1
    of '[': emit(tkLBracket);    i += 1
    of ']': emit(tkRBracket);    i += 1
    of '=': emit(tkEquals);      i += 1
    of ';': emit(tkDeclaration); i += 1
    of ',': emit(tkComma);       i += 1
    of '$': emit(tkDollar);      i += 1

    of '"', '\'':
      let quote = source[i]
      i += 1
      let start = i
      while i < source.len and source[i] != quote:
        if source[i] == '\n':
          raise newException(ValueError, "Heyy the string doesn't close on line " & $line)
        i += 1
      emitVal(tkString, source[start..i-1])
      i += 1

    else:
      if source[i] in IdentStartChars + {'.'}:
        let start = i
        while i < source.len and source[i] in IdentChars + {'.', '-', '/'}:
          i += 1
        let word = source[start..i-1]
        if word == "include":
          emit(tkInclude)
        else:
          emitVal(tkIdent, word)
      else:
        raise newException(ValueError,
          "Wow, an unexpected character '" & $source[i] & "' on line " & $line)

  emit(tkEOF)
  return tokens