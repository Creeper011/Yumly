# Yumly Test System

The test system is file-based — you understand a test just by looking at the files, no tooling needed.

---

## Structure

```
tests/
  fixtures/
    valid/                         ← tests that must parse successfully
      y0001-multiline-string/
        metadata.yumly
        test.yumly
        test.expected.yumyumy      ← optional: asserts evaluator output
    invalid/                       ← tests that must fail
      x0002-duplicated-pair/
        metadata.yumly
        case1.yumly
        case2.yumly
  runners/
    nim_runner.nim
  utils/
    create_new_test.nim
```

### Folder naming

```
{identifier}{phase}{number}-{name}
```

| Field        | Description                                          |
|--------------|------------------------------------------------------|
| `identifier` | `y` = valid, `x` = invalid                           |
| `phase`      | Pipeline stage to run up to (optional)               |
| `number`     | Global 4-digit counter, e.g. `0001`                  |
| `name`       | Lowercase with underscores, e.g. `multiline_string`  |

The number is **global** — it increments across all tests regardless of valid/invalid or phase. IDs are stable and unique forever.

---

## metadata.yumly

```yumly
;> Test file metadata template for unit tests <;

name ;string = "Test Name"
valid ;bool = false, number ;int = 0000
phase ;string = "T" ;> if is a full case, this pair doesn't exist <;

;> for multiples levels of test<;
cases ;list[string] = ["case1.yumly", "case2.yumly"]

;> set environment variables for the test case (optional) <;
(envs) {
    VAR1 ;string = "Value",
    VAR2 ;string = "Value",
    VAR3 ;string = "Value",
    VAR4 ;string = "Value"
}
```

Template: [tests/utils/template/metadata.yumly](tests/utils/template/metadata.yumly)

**ALL METADATA is NOT inferred from the parent folder**

### Phase values

| Value | Stage        |
|-------|--------------|
| `T`   | Tokenizer    |
| `P`   | Parser       |
| `R`   | Resolver     |
| `LI`  | Load Include |
| `V`   | Validator    |
| `E`   | Evaluator    |

## Assertions

Assertions are always **optional**. Without an expected file, the runner only checks pass/fail. This avoids silent success — a test that parses without error but produces wrong output.

Each phase has its own assertion format:

| Phase | Expected file            | Format       |
|-------|--------------------------|--------------|
| `T`   | `case1.expected.tokens`  | token stream |
| `E`   | `case1.expected.yumyumy` | yumyumy ♡    |
| other | —                        | pass/fail only |

If a test has multiple cases, each case can have its own expected file independently:

```
y0005-basic-types/
  metadata.yumly
  case1.yumly
  case1.expected.yumyumy   ← asserts output
  case2.yumly              ← pass/fail only
```

### Tokenizer assertions — `.expected.tokens`

One token per line. Tokens with a value include it quoted; tokens without a value stand alone.

```
tkIdent "name"
tkDeclaration
tkIdent "string"
tkEquals
tkString "Yumly"
tkEOF
```

The runner serializes the token stream produced by the tokenizer and compares it as a string against this file.

### Evaluator assertions — `.expected.yumyumy`

The runner evaluates the input and serializes the result with `toYumyumy`, then compares as a string.

`test.yumly`:
```yumly
name ;string = "Yumly"
port ;int    = 8080

(database) {
    host = "localhost",
    port = 5432
}
```

`test.expected.yumyumy`:
```
[
  name (string) -> Yumly
  port (int) -> 8080
  [database] (
    host (string) -> localhost
    port (int) -> 5432
  )
]
```

Env vars are shown as their **resolved values** in yumyumy ♡, so assertions implicitly verify env resolution too.

### What a failing assertion looks like

```
  [KYAA] y0005 - Basic Types (test.yumly)
         assertion failed
         expected: port (int) -> 9090
         got:      port (int) -> 8080
```

---

## Invalid tests

No expected file. The test passes if parsing fails at or before the target phase.

```
x0002-duplicated-pair/
  case1.yumly     ← must fail
  case2.yumly     ← must fail
  metadata.yumly
```

The failure message is not asserted — error messages are intentionally not part of the contract, as they may change over time.

---

## Creating a test

```bash
nim c -r tests/utils/create_new_test.nim
```

It will:
1. Ask for name, valid/invalid, phase, and number of cases
2. Auto-assign the next global number scanning all fixtures
3. Create the folder, case files, and `metadata.yumly`
4. Optionally open each case file in `$EDITOR`

---

## Running tests

```bash
nim c -r tests/runners/nim_runner.nim
```

Output:
```
=== Yumly Test Runner (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ===

  [YAY!] y0001 - Multiline String (test.yumly)
  [YAY!] x0002 - Duplicated Pair (case1.yumly)
  [YAY!] x0002 - Duplicated Pair (case2.yumly)
  [KYAA] y0005 - Basic Types (test.yumly)
         assertion failed
         expected: port (int) -> 9090
         got:      port (int) -> 8080

✨ Summary: 3/4 passed! :3
```

---

## Conventions

- **One concern per folder.** Don't mix unrelated cases.
- **Case files should be self-explanatory.** A reviewer should understand what's being tested by reading the `.yumly` file alone.
- **Invalid cases should be minimal.** Include only what triggers the failure, not a full config.
- **Write the expected file after verifying the output is correct.** Never copy a wrong output as the expected.
- **Don't assert what you don't care about.** If you only care that parsing succeeds, skip the expected file.