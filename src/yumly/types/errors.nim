#
# Defines structured errors used while processing Yumly config.
#

import source

type
  ErrorCode* = enum
    ecNone
    ecParserExpected
    ecParserUnexpectedRoot
    ecParserIncludeOrder
    ecParserSchemaOrder
    ecParserSchemaFile
    ecParserSchemaFieldType
    ecParserObjectContext
    ecParserIncludeComma
    ecParserEnvDisabled
    ecParserRecursionLimit
    ecResolverUnknownTypeHint
    ecResolverEnvDisabled
    ecValidatorDuplicatePair
    ecValidatorDuplicateBlock
    ecValidatorDuplicateSchema
    ecValidatorListElementType
    ecValidatorMissingEnv
    ecValidatorMultipleErrors
    ecValidatorTypeMismatch
    ecValidatorUnknownSchema
    ecValidatorSchemaMissingField
    ecValidatorSchemaUnknownField
    ecValidatorSchemaMissingBlock
    ecValidatorSchemaBlockValueType
    ecValidatorRecursionLimit
    ecValidatorInvalidItemContext
    ecIncludeLoadFailed
    ecIncludeCircularImport
    ecIncludeNotFound
    ecIncludeDotenvDisabled
    ecIncludeUnsupportedExtension
    ecIncludeSandboxViolation
    ecFileInvalidExtension
    ecFileNotFound
    ecFileTooLarge
    ecFileOpenFailed
    ecTokenizerUnclosedComment
    ecTokenizerInvalidExponent
    ecTokenizerUnclosedString
    ecTokenizerUnexpectedCharacter
    ecEvaluatorInvalidEscape
    ecEvaluatorEnvCoerceFailed
    ecEvaluatorInvalidLiteralToken
    ecEvaluatorInvalidNodeKind
    ecValueInvalidInteger
    ecValueInvalidFloat
    ecValueInvalidBoolean

  Expected* = enum
    expValue = "a value"
    expIdentifier = "an identifier"
    expString = "a string"
    expInteger = "an integer"
    expFloat = "a float"
    expBoolean = "a boolean"
    expEnvVar = "an environment variable"
    expBlockName = "a block name"
    expEquals = "'='"
    expLBrace = "'{'"
    expRBrace = "'}'"
    expLBracket = "'['"
    expRBracket = "']'"
    expComma = "','"
    expBlockComma = "a comma"
    expQuestion = "'?'"
    expEOF = "end of file"

  YumlyError* = object of ValueError
    code*: ErrorCode
    source*: seq[SourceSpan] # Primary span first; related spans follow.

  YumlyDefect* = object of Defect
    code*: ErrorCode
    source*: seq[SourceSpan] # Primary span first; related spans follow.

  YumlyIOError* = object of IOError
    code*: ErrorCode
    source*: seq[SourceSpan] # Primary span first; related spans follow.

proc newYumlyError*(message: string, code: ErrorCode, source: sink seq[SourceSpan] = @[]): ref YumlyError =
  result = newException(YumlyError, message)
  result.code = code
  result.source = source

proc newYumlyIOError*(message: string, code: ErrorCode, source: sink seq[SourceSpan] = @[]): ref YumlyIOError =
  result = newException(YumlyIOError, message)
  result.code = code
  result.source = source

proc newYumlyDefect*(message: string, code: ErrorCode, source: sink seq[SourceSpan] = @[]): ref YumlyDefect =
  result = newException(YumlyDefect, message)
  result.code = code
  result.source = source
