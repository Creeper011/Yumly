# ⋆˚.♪ Yumly Fixture Test System ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

yooooo!! welcome to the testing arena!! 🥀 ⸜(｡˃ ᵕ ˂ )⸝♡

The testing system focuses on fixtures, which in turn are file-based, thus allowing tests that are not tied to any specific language. It's a way to decouple tests and also centralize them through identifiers.

There are Runners, which consist of searching the fixture architecture for tests and running them. Runners will try to execute every test in the suite (failing fast on the first error encountered), providing a cute summary of the results at the very end.

---

## ✿ Architecture

Every test lives inside its own little folder. Here's how it looks:

```
tests/
  fixtures/
    valid/                         ← tests that must parse successfully
      yE0015-basic-types/
        metadata.yumly
        test.yumly
        test.expected.yumyumy      ← optional: asserts evaluator output
    invalid/                       ← tests that must fail
      xV0001-duplicated-pair/
        metadata.yumly
        case1.yumly
        case2.yumly
    stress/                        ← stress/performance tests
      sV0001-deep-nesting/
        metadata.yumly
        test.yumly
  runners/
    nim_runner.nim                 ← the one that makes it all happen!
  utils/
    create_new_test.nim            ← your best friend for new tests
```

### ✿ How to name tests

You might be wondering, what are these strange folder names (like `xV002`)? They are identifiers!

For my cute test system, every folder follows this pattern:

```
{identifier}{phase}{number}-{name}
```

| Field        | Description                                          |
|--------------|------------------------------------------------------|
| `identifier` | `y` = valid, `x` = invalid, `s` = stress             |
| `phase`      | Pipeline stage to run up to (optional)               |
| `number`     | Global 4-digit counter, e.g. `0001`                  |
| `name`       | Lowercase with hyphens (kebab-case), e.g. `multiline-string` |

> **Note:** The number is **global per identifier** — it keeps incrementing 
> across all tests regardless of which phase they target!

## ✿ Test Metadata ‧₊˚

Every test folder MUST have a `metadata.yumly` file. This tells the runner exactly what to do. **Runners do never infer from the folder name!!**

```yumly
;> Test file metadata template for unit tests <;

name ;string = "Test Name"
valid ;bool = false, number ;int = 0000
phase ;string = "T" ;> if is a full case, this pair doesn't exist <;

;> For multiples levels of test<;
cases ;list[string] = ["case1.yumly", "case2.yumly"]

;> Set environment variables for the test case (optional) <;
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

## ✿ Making Assertions ‧₊˚

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

### ⟡ Tokenizer assertions (`.expected.tokens`)

The runner compares the serialized token stream.

```
tkIdent "name"
tkDeclaration
tkIdent "string"
tkEquals
tkString "Yumly"
tkEOF
```

The runner serializes the token stream produced by the tokenizer and compares it as a string against this file.

### ⟡ Evaluator assertions (`.expected.yumyumy`)

The runner serializes the result with `toYumyumy`.

`test.yumly`:
```yumly
name ;string = "Yumly"
(database) { host = "localhost" }
```

`test.expected.yumyumy`:
```
[
  name (string) -> Yumly
  [database] (
    host (string) -> localhost
  )
]
```

Env vars are shown as their **resolved values** in yumyumy ♡, so assertions 
implicitly verify env resolution too!! ✧

> ⟡ If you don't know what is Yumyumy ♡, check [docs/yumyumy.md](../yumyumy.md)

---

## ✿ Testing for failures ‧₊˚

Invalid tests don't use expected files. An invalid test, for example, passes if it **fails** at or before the targeted phase.

The failure message is not asserted — error messages are intentionally not 
part of the contract, as they may change over time (hopefully getting cuter!). ✿

---

## ✿ Creating a new test ‧₊˚

Don't do it manually!! Use this utility:

```bash
nim c -r tests/utils/create_new_test.nim
```

It will guide you through:
1. Naming your test
2. Choosing valid/invalid and the target phase
3. Automatically assigning the next global number scanning all fixtures
4. Creating all the folders and files for you!! ✧

---

## ✿ Running the tests ‧₊˚

To run everything and see the magic:

```bash
nim c -r tests/runners/nim_runner.nim
```

You'll get a cute summary like this:
```
=== Yumly Test Runner (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ ===

  [YAY!] y0001 - Multiline String (test.yumly)
  [YAY!] x0002 - Duplicated Pair (case1.yumly)
  [KYAA] y0005 - Basic Types (test.yumly)
         assertion failed
         expected: port (int) -> 9090
         got:      port (int) -> 8080

✨ Summary: 3/4 passed! :3
```

Additionally, the runners can generate benchmark results! Just add `--benchmark` to the end of the command. This will generate a cute `.ylwa` file (wa wa wa) for you to analyze performance, which you can check out in [docs/ylwa.md](../docs/ylwa.md).

---

## ✿ Best Practices ‧₊˚

- ⟡ **One concern per folder.** Keep it focused!!
- ⟡ **Self-explanatory cases.** A reviewer should understand the test just by 
  reading the `.yumly` file.
- ⟡ **Minimal invalid cases.** Only include what triggers the failure.
- ⟡ **Verify before you assert.** Make sure your `.expected` files are actually 
  correct before committing them!
- ⟡ **Don't assert what you don't care about.** If you only care that parsing 
  succeeds, skip the expected file.

---

#### yeah, you're a testing pro now!! (๑˃ᴗ˂)ﻭ