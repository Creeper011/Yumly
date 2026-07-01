## Tokenizer diagnostic raises.

import ../../../types/[errors, source]
import ../../common

func commentNotClosedError*(line, col, endLine, endCol: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecTokenizerUnclosedComment,
      "Heyy, the comment doesn't close! Expected '<;'", line, col),
    ecTokenizerUnclosedComment, @[sourceSpan(nil, line, col, endLine, endCol)])

func invalidExponentError*(line, col, endLine, endCol: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecTokenizerInvalidExponent, "Heyy, invalid exponent", line,
      col),
    ecTokenizerInvalidExponent, @[sourceSpan(nil, line, col, endLine, endCol)])

func unclosedStringError*(line, col, endLine, endCol: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecTokenizerUnclosedString, "Heyy, the string doesn't close",
      line, col),
    ecTokenizerUnclosedString, @[sourceSpan(nil, line, col, endLine, endCol)])

func unclosedStringAtEofError*(line, col, endLine, endCol: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecTokenizerUnclosedString,
      "Heyy the string doesn't close at the end of the file", line, col),
    ecTokenizerUnclosedString, @[sourceSpan(nil, line, col, endLine, endCol)])

func unexpectedCharError*(char: string, line, col, endLine, endCol: SourcePos) =
  raise newYumlyError(
    yumlyMessage(ecTokenizerUnexpectedCharacter,
      "Wow, an unexpected character '" & char & "'", line, col),
    ecTokenizerUnexpectedCharacter, @[sourceSpan(nil, line, col, endLine, endCol)])
