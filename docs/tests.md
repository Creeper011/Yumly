# ⋆˚.♪ Yumly Test System ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

yooooo!! welcome to the testing arena!! 🥀 ⸜(｡˃ ᵕ ˂ )⸝♡

I, as Yumly, the test system has two complementary sides:
- Unit tests for isolated behavior
- Fixtures for the complete parsing pipeline.

---

## ✿ Architecture ‧₊˚

Every test lives inside its own little folder:

```text
tests/
  unit/
    U0001[value_defs]-classify-literal/
      test_classify_literal.nim
    U0010[bridge]-map-values/
      test_map_values.py
  fixtures/
    valid/
      yE0015-basic-types/
        metadata.yumly
        case1.yumly
        case1.expected.yumyumy
    invalid/
      xP0005-missing-tokens/
        metadata.yumly
        case1.yumly
    stress/
      sV0001-deep-nesting/
        metadata.yumly
        test.yumly
  runners/
    nim_runner/
    python_runner/
  utils/
    create_new_test.nim
```

The runners are intentionally separated from the test data. Fixtures describe
the language behavior once, then Nim and Python verify the same cases.

---

## ✿ Unit Tests ‧₊˚

They exercise one module or behavior directly, and don't need `metadata.yumly`.

But, for that, discovery rules are simple:

- ⟡ Nim unit files must be named `test_*.nim`.
- ⟡ Python unit files must be named `test_*.py`.
- ⟡ Filesystem and complete-pipeline behavior belong in fixtures.
- ⟡ Nim unit binaries are generated under `build/tests/unit`.

Run all unit tests:

```bash
make test-unit
```

Or choose a runner:

```bash
make test-unit-nim
make test-unit-python
```

Python units are collected directly by pytest, so each test function appears
as an individual result. The Nim runner recursively discovers and compiles
every `test_*.nim` source.

---

## ✿ Fixture Identifiers ‧₊˚

Fixture folders use this pattern:

```text
{kind}{phase}{number}-{name}
```

| Field        | Description                                          |
|--------------|------------------------------------------------------|
| `kind` | `y` = valid, `x` = invalid, `s` = stress             |
| `phase`      | Pipeline stage to run up to (optional)               |
| `number`     | Global 4-digit counter, e.g. `0001`                  |
| `name`       | Lowercase with hyphens (kebab-case), e.g. `multiline-string` |

> **Note:** The number is **global per kind** — it keeps incrementing
> across all tests regardless of which phase they target!

## ✿ Test Metadata ‧₊˚

Every test folder MUST have a `metadata.yumly` file. This tells the runner exactly what to do. **Runners do never infer from the folder name!!**

```yumly
;> Test file metadata template for fixtures tests <;

name ;string = "Test Name"
valid ;bool = false, number ;int = 0000
phase ;string = "T"

;> Required for invalid fixtures <;
expectedCode ;string = "tokenizer.unclosed-string"

;> for multiples levels of test<;
cases ;list[string] = ["case1.yumly", "case2.yumly"]

;> set environment variables for the test case <;
(envs) {
    VAR1 ;string = "Value",
    VAR2 ;string = "Value",
    VAR3 ;string = "Value",
    VAR4 ;string = "Value"
}

;> Executes Python code inside an isolated sandbox before the test suite runs <;
preSuiteEval ;string = """
# your python code here
"""
```

Template: [tests/utils/template/metadata.yumly](../tests/utils/template/metadata.yumly)

### ✿ Pipeline Phases ‧₊˚

| Value | Stage        | Description |
|-------|--------------|-------------|
| `T`   | Tokenizer    | Raw token stream |
| `P`   | Parser       | AST construction |
| `R`   | Resolver     | Type & Env resolution |
| `LI`  | Load Includes | Including external files |
| `V`   | Validator    | Structural checks |
| `E`   | Evaluator    | Final value generation |

---

## ✿ Making Assertions (for fixtures) ‧₊˚

Assertions are **optional** but highly recommended!! Without an expected file, the runner only checks if the test passes or fails. 

Expected files verify that the result produced by the parser is indeed the expected result. It is important to note that the error message is ignored, and if the program fails during execution, the assertion will not be made and the test will be marked as failed.


| Phase | Expected file            | Format       |
|-------|--------------------------|--------------|
| `T`   | `case1.expected.tokens`  | token stream |
| `E`   | `case1.expected.yumyumy` | yumyumy ♡    |
| other | —                        | pass/fail only |

If a test has multiple cases, each case can have its own assertion:

```
yE0015-basic-types/
  metadata.yumly
  case1.yumly
  case1.expected.yumyumy   ← asserts output
  case2.yumly              ← pass/fail only
```

### ⟡ Tokenizer assertions

The runner serializes the token stream and compares it with
`case1.expected.tokens`:

```text
tkIdent "name"
tkEquals
tkString "Yumly"
tkEOF
```

### ⟡ Evaluator assertions

For `case1.yumly`:

```yumly
name ;string = "Yumly"
(database) { host = "localhost" }
```

The matching `case1.expected.yumyumy` may contain:

```text
[
  name (string) -> Yumly
  [database] (
    host (string) -> localhost
  )
]
```

Env vars appear as resolved values, so evaluator assertions verify resolution
too!! ✧

> ⟡ If you don't know what is Yumyumy ♡, check [docs/yumyumy.md](yumyumy.md)

---

## ✿ Running The Suite ‧₊˚

Run unit and functional fixture tests:

```bash
make test-all
```

Run only functional fixtures:

```bash
make test-fixtures
make test-fixtures-nim
make test-fixtures-python
```

`test-all` intentionally excludes stress fixtures and benchmarks. The normal
loop should stay quick enough to run constantly.

---

## ✿ Stress And Benchmarks ‧₊˚

Stress fixtures exercise large inputs, deep nesting, and include depth:

```bash
make test-stress
```

Benchmarks measure every valid, invalid, and stress fixture with release builds:

```bash
make test-bench
```

Results are written to:

- ⟡ `benchmark.ylwa` for Nim.
- ⟡ `benchmark_python.ylwa` for Python.

The benchmark reports are nested Ylwa documents. Measurements are grouped by
runner, fixture kind (`valid`, `invalid`, `stress`), fixture case, and operation,
so stress results can be inspected without digging through the full fixture list.
Nim fixture memory uses `getOccupiedMem()` inside an isolated worker process,
so previous test cases do not inflate later measurements.
Learn more about the wa wa wa format in [docs/ylwa.md](ylwa.md).

---

## ✿ Creating A New Test ‧₊˚

Don't create all those folders manually!! Use the super-test-generator-2000:

```bash
nim c -r tests/utils/create_new_test.nim
```

It can create:

1. Discoverable Nim or Python unit tests.
2. Valid, invalid, or stress fixtures.
3. Metadata with the selected phase and expected diagnostic code.
4. One or more case files with the next available identifier.

---

## ✿ Best Practices ‧₊˚

- ⟡ **One behavior per folder.** Different diagnostic codes mean different fixtures.
- ⟡ **Prefer unit tests for isolated logic.** They are faster and easier to debug.
- ⟡ **Use fixtures for pipeline behavior.** Especially files, includes, env vars, and diagnostics.
- ⟡ **Keep invalid cases minimal.** Include only what triggers the expected failure.
- ⟡ **Never accept an arbitrary exception.** Assert the phase and diagnostic code.
- ⟡ **Don't assert what you don't care about.** Successful completion may be enough.
- ⟡ **Keep stress explicit.** Big cases should not slow down normal development.

## ✿ Make Reference ‧₊˚

Okay, too many commands to memorize... so here's the cheat sheet!! ദ്ദി •⩊• )

### ⟡ Test commands

| Command | What it does |
|---------|--------------|
| `make test` | Alias for `make test-all` |
| `make test-all` | Runs unit tests and functional fixtures in both languages |
| `make test-unit` | Runs all Nim and Python unit tests |
| `make test-unit-nim` | Runs only Nim unit tests |
| `make test-unit-python` | Runs only Python unit tests |
| `make test-fixtures` | Runs valid and invalid fixtures in both languages |
| `make test-fixtures-nim` | Runs valid and invalid fixtures with the Nim runner |
| `make test-fixtures-python` | Runs valid and invalid fixtures with pytest |
| `make test-stress` | Runs stress fixtures in both languages |
| `make test-stress-nim` | Runs stress fixtures with the Nim runner |
| `make test-stress-python` | Runs stress fixtures with pytest |
| `make test-bench` | Benchmarks all valid, invalid, and stress fixtures |

---

#### yeah, you're a testing pro now!! (๑˃ᴗ˂)ﻭ
