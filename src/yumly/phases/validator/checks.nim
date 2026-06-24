import options, sets, strutils
import ../../types/[ast, type_hints]
import ../../types/values_defs
import ../../utils/loc
import ../../error_messages

type
  ValidationIssue* = object
    code*: string
    message*: string
    line*: int
    col*: int
    sourceFile*: string

proc addIssue(errors: var seq[ValidationIssue], code, message: string,
    line: int = 0, col: int = 0, sourceFile: string = "") =
  errors.add(ValidationIssue(code: code, message: message, line: line, col: col,
      sourceFile: sourceFile))

func pathString(pathParts: openArray[string]): string =
  pathParts.join(".")

func duplicateWhere(pathParts: openArray[string]): string =
  if pathParts.len == 0: "root" else: "'" & pathString(pathParts) & "'"

func pairWhere(pathParts: openArray[string]): string =
  "'" & pathString(pathParts) & "'"

func toValueKind*(hintKind: TypeHintKind): ValueKind =
  case hintKind
  of thString: result = vkString
  of thInt: result = vkInt
  of thFloat: result = vkFloat
  of thBool: result = vkBool
  of thEnv: result = vkEnv
  of thList: result = vkList
  else: invalidTypeHintKindError()

proc checkDuplicates*(pairs: seq[Pair], blocks: seq[Block],
    pathParts: openArray[string], errors: var seq[ValidationIssue]) =
  if pairs.len + blocks.len < 2:
    return

  var seenSymbols = initHashSet[string]()

  for pair in pairs:
    if pair.key in seenSymbols:
      let where = duplicateWhere(pathParts)
      errors.addIssue("validator.duplicate-symbol", "Oh no! the symbol '" &
          pair.key & "' is duplicated in " & where & "! (°ロ°)" & loc(
          pair.line, pair.col) &
          "\n  hint: pair keys and block names share the same scope; choose one to prevail or rename it.",
          pair.line, pair.col, pair.sourceFile)
    else:
      seenSymbols.incl(pair.key)

  for blk in blocks:
    if blk.name in seenSymbols:
      let where = duplicateWhere(pathParts)
      errors.addIssue("validator.duplicate-symbol", "Oh no! the symbol '" &
          blk.name & "' is duplicated in " & where & "! (°ロ°)" & loc(
          blk.line, blk.col) &
          "\n  hint: pair keys and block names share the same scope; merge them or rename one.",
          blk.line, blk.col, blk.sourceFile)
    else:
      seenSymbols.incl(blk.name)

proc validateEnvExistence(value: Value, line, col: int, sourceFile: string,
    errors: var seq[ValidationIssue]) =
  case value.kind
  of vkEnv:
    if not value.envFound and value.envDefault.isNone:
      let issueSource = if value.sourceFile.len >
          0: value.sourceFile else: sourceFile
      errors.addIssue("validator.missing-env", "Kyaa~! the env variable '" &
          value.envName & "' does not exist! (；ω；)" & loc(line, col) &
          "\n  hint: make sure it's set in your terminal or loaded via include { \".env\" }",
          line, col, issueSource)
  of vkList:
    for child in value.elements:
      validateEnvExistence(child, line, col, sourceFile, errors)
  else:
    discard

func valueMatchesHint(value: Value, hintKind: TypeHintKind): bool =
  case hintKind
  of thUnknown: true
  of thString: value.kind == vkString
  of thInt: value.kind == vkInt
  of thFloat: value.kind == vkFloat
  of thBool: value.kind == vkBool
  of thEnv: value.kind == vkEnv
  of thList: value.kind == vkList

func envValueMatchesHint(value: Value, hintKind: TypeHintKind, line,
    col: int): bool =
  if value.kind != vkEnv:
    return false

  case hintKind
  of thString:
    true
  of thInt, thFloat, thBool:
    tryDecode(value.envVal, toValueKind(hintKind), line, col).isSome
  else:
    false

proc validateListElements(pair: Pair, hint: TypeHint, errors: var seq[
    ValidationIssue]) =
  if hint.kind != thList or hint.elementKind == thUnknown or pair.value.kind != vkList:
    return

  for i, child in pair.value.elements:
    if child.kind == vkEnv:
      continue
    if not valueMatchesHint(child, hint.elementKind):
      errors.addIssue("validator.list-element-type", "Mmm, element " & $i &
          " in list '" & pair.key & "' has the wrong type! >_<" & loc(pair.line,
          pair.col) & "\n  got " & VALUES_DEF[child.kind].typeHint &
          ", but expected " & VALUES_DEF[toValueKind(
          hint.elementKind)].typeHint, pair.line, pair.col, pair.sourceFile)

proc validatePair*(pair: Pair, pathParts: openArray[string], errors: var seq[
    ValidationIssue]) =
  let position = loc(pair.line, pair.col)
  validateEnvExistence(pair.value, pair.line, pair.col, pair.sourceFile, errors)

  if pair.typeHint.isNone:
    return

  let hint = pair.typeHint.get
  if hint.kind == thUnknown:
    return

  if hint.kind == thEnv:
    # ;env and ;env[...] must be backed by a $[...] expression.
    if pair.value.kind != vkEnv:
      errors.addIssue("validator.type-mismatch", "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " is annotated as ;" & hint.raw &
          " but does not use an env reference! >_<" & position &
          "\n  env values must use $[\"NAME\"]", pair.line, pair.col,
          pair.sourceFile)
      return

    # Bare ;env only requires the value to stay as vkEnv.
    if hint.elementKind == thUnknown:
      return

    # If the env is missing, missing-env already explains the actual problem.
    if not pair.value.envFound and pair.value.envDefault.isNone:
      return

    # env[T] validates the resolved env string without changing the value kind.
    if not envValueMatchesHint(pair.value, hint.elementKind, pair.line, pair.col):
      errors.addIssue("validator.type-mismatch", "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " has the wrong type! >_<" &
          position & "\n  env value cannot be used as ;env[" & VALUES_DEF[
          toValueKind(hint.elementKind)].typeHint & "]", pair.line, pair.col,
          pair.sourceFile)
    return

  if pair.value.kind == vkEnv and hint.kind notin {thEnv, thList}:
    errors.addIssue("validator.type-mismatch", "Ehhh... '" & pair.key &
        "' in " & pairWhere(pathParts) &
        " is an env reference but is annotated as ;" & hint.raw & "! >_<" &
        position &
        "\n  env values must be annotated with ;env (or remove the type hint)",
        pair.line, pair.col, pair.sourceFile)
    return

  case hint.kind
  of thList:
    if pair.value.kind != vkList:
      errors.addIssue("validator.type-mismatch", "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " has the wrong type! >_<" &
          position & "\n  value is " & VALUES_DEF[pair.value.kind].typeHint &
          ", but the type hint is ;" & VALUES_DEF[vkList].typeHint, pair.line,
          pair.col, pair.sourceFile)
    else:
      validateListElements(pair, hint, errors)
  else:
    if not valueMatchesHint(pair.value, hint.kind) and pair.value.kind != vkEnv:
      errors.addIssue("validator.type-mismatch", "Ehhh... '" & pair.key &
          "' in " & pairWhere(pathParts) & " has the wrong type! >_<" &
          position & "\n  value is " & VALUES_DEF[pair.value.kind].typeHint &
          ", but the type hint is ;" & VALUES_DEF[toValueKind(
          hint.kind)].typeHint, pair.line, pair.col, pair.sourceFile)
