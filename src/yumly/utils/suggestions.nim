##
# Fuzzy matching utilities and candidates used by diagnostic messages.
##

import std/[editdistance, options, strutils]
import ../types/[errors, token]

const TypeHintCandidates = ["string", "int", "float", "bool", "env", "list"]
const KeywordCandidates = ["include"]

func defaultMaxDistance(value: string): int =
  case value.len
  of 0 .. 3: 1
  of 4 .. 8: 2
  else: 3

func suggestClosest*(value: string, candidates: openArray[string], maxDistance = -1): Option[string] =
  if value.len == 0:
    return none(string)

  let normalizedValue = value.toLowerAscii()
  let distanceLimit =
    if maxDistance >= 0: maxDistance
    else: defaultMaxDistance(normalizedValue)

  var bestDistance = high(int)
  var bestCandidate = ""

  for candidate in candidates:
    let distance = editDistanceAscii(normalizedValue, candidate.toLowerAscii())
    if distance < bestDistance:
      bestDistance = distance
      bestCandidate = candidate

  if bestCandidate.len > 0 and bestDistance > 0 and bestDistance <= distanceLimit:
    some(bestCandidate)
  else:
    none(string)

func suggestTypeHint*(hint: string): Option[string] =
  suggestClosest(hint, TypeHintCandidates)

func knownTypeHint(hint: string): Option[string] =
  let normalizedHint = hint.toLowerAscii()
  for candidate in TypeHintCandidates:
    if normalizedHint == candidate:
      return some(candidate)

  suggestTypeHint(hint)

func suggestExpected*(expected: Expected, token: Token, previousToken: Option[Token]): Option[string] =
  let atEof = token.kind == tkEOF

  case expected
  of expValue:
    some("values can be strings, numbers, booleans, env references, lists, or blocks")
  of expIdentifier:
    if previousToken.isSome and previousToken.get.kind == tkDeclaration:
      return some("type hints need a name after ';': use ;string, ;int, ;float, ;bool, ;env, or ;list")
    some("identifiers must start with a letter or underscore")
  of expString:
    some("wrap the value in single or double quotes")
  of expInteger:
    some("use a whole number without quotes")
  of expFloat:
    some("use a decimal number without quotes")
  of expBoolean:
    some("use true or false without quotes")
  of expEnvVar:
    some("environment variables use the syntax $[\"NAME\"]")
  of expBlockName:
    some("declare blocks with the syntax (name) { ... }")
  of expEquals:
    if token.kind == tkLBrace and previousToken.isSome:
      let previous = previousToken.get
      if previous.kind == tkIdent:
        let keyword = suggestClosest(previous.value, KeywordCandidates)
        if keyword.isSome:
          return some("did you mean '" & keyword.get & "'?")
    if token.kind == tkIdent and previousToken.isSome:
      let previous = previousToken.get
      let typeHint = knownTypeHint(token.value)
      if previous.kind == tkIdent and typeHint.isSome:
        return some("type hints start with ';': write '" & previous.value &
            " ;" & typeHint.get & " = ...'")
    some("place '=' between the key and its value")
  of expLBrace:
    some("open the block with '{'")
  of expRBrace:
    if atEof:
      some("close the block with '}' before the end of the file")
    else:
      some("close the block with '}'")
  of expLBracket:
    some("open the list with '['")
  of expRBracket:
    if atEof:
      some("close the list with ']' before the end of the file")
    else:
      some("close the list with ']'")
  of expComma:
    some("separate list items with ','")
  of expBlockComma:
    some("separate pairs and nested blocks with ','")
  of expQuestion:
    some("env defaults use two question marks: $[\"NAME\" ?? \"fallback\"]")
  of expEOF:
    some("remove the remaining tokens after the configuration")

func suggestExpected*(expected: Expected, token: Token): Option[string] =
  suggestExpected(expected, token, none(Token))
