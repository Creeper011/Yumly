# ⋆˚.♪ Yumly Test System ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

yooooo!! welcome to my testing arena!! 🥀 ⸜(｡˃ ᵕ ˂ )⸝♡

My test suite is built from fixtures. Each fixture describes an input, the
compile profiles in which it runs, and the exact result or diagnostic expected
from each execution.

The runners collect the same fixtures, expand their compile-flag combinations,
build the required profiles, and execute every variant assigned to each
profile. Test behavior is written once in the fixture instead of being copied
into each runner.

---

## ✿ Architecture ‧₊˚

```text
tests/
  fixtures/
    yT0001-unclosed-string/
      metadata.yumly
      case1.yumly

    y0002-env-feature/
      metadata.yumly
      case1.yumly
      case1.expected.yumyumy

  runners/
    nim/
    python/
    c/

  schemas/
    case.yu

  template/
    y0001-test-template/
      metadata.yumly
```

Every fixture owns a folder under `tests/fixtures/`. Its `metadata.yumly` uses
the shared schemas in
[`tests/schemas/case.yu`](../tests/schemas/case.yu).

The runners contain execution and interface-specific code. They do not own
copies of the language cases.

---

## ✿ Fixture Identifiers ‧₊˚

Fixture folders use this pattern:

```text
y{phase?}{number}-{name}
```

| Field | Meaning |
|-------|---------|
| `y` | My fixture symbol. It does not mean valid or invalid. |
| `phase` | Optional short form of `until-stage`. |
| `number` | One global and immutable four-digit fixture number. |
| `name` | A lowercase kebab-case description of the behavior. |

Pipeline phases use these short forms:

| Short form | Stage |
|------------|-------|
| `T` | Tokenizer |
| `P` | Parser |
| `LI` | Load Includes |
| `R` | Resolver |
| `E` | Evaluator |
| `V` | Validator |

The phase may be present or omitted:

```text
yT0001-unclosed-string
y0002-env-feature
yLI0003-circular-include
```

Only `y` plus the number forms the permanent identity. The optional phase and
descriptive name may change without creating a new fixture identity.

The runner rejects duplicate numbers. When a folder contains a phase, it must
match `until-stage` in its metadata. The `number` field must also match the
folder number.

---

## ✿ Metadata ‧₊˚

Every fixture contains one `metadata.yumly`. It declares fixture-wide settings
and a typed list of cases.

The complete template lives at
[`tests/template/y0001-test-template/metadata.yumly`](../tests/template/y0001-test-template/metadata.yumly).

```yumly
include { "../../schemas/case.yu" }

name = "Environment feature"
number = "0002"
until-stage = "validator"
tags ;list[string] = ["boundary", "feature:env"]

compile-flags ;list[string] = [
  "yumlyEnv"
  "yumlyDotenv"
  "yumly32"
]

(envs) {
  TOKEN = "root value"
}

cases ;list[test-case] = [
  {
    name = "Environment expression"
    file = "case1.yumly"
    tags = ["integration"]

    (envs) {
      TOKEN = "case value"
    }

    variants ;list = [
      <valid-variant> {
        name = "Environment support enabled"
        expected-file = "case1.expected.yumyumy"
      }

      <invalid-variant> {
        name = "Environment support disabled"
        disable-flags = ["yumlyEnv", "yumlyDotenv"]
        expected-stage = "parser"
        expected-code = "parser.env-disabled"

        (expected-span) {
          file = "case1.yumly"
          line = 1
          col = 9
          end-line = 1
          end-col = 20
        }
      }
    ]
  }
]
```

### ⟡ Root fields

| Field | Meaning |
|-------|---------|
| `name` | Human-readable fixture name. |
| `number` | Four-digit identity matching the folder. |
| `until-stage` | Furthest pipeline stage executed by the fixture. |
| `tags` | Tags shared by its cases and variants. |
| `compile-flags` | Base compile profile. |
| `pre-eval-code` | Optional isolated setup code. |
| `(envs)` | Environment shared by every case. |
| `cases` | List of inputs and their variants. |

If `pre-eval-code` fails, fixture setup fails. Setup code does not replace an
expected result and must not depend on the execution order of cases.

---

## ✿ Cases ‧₊˚

A case identifies one input file and the settings shared by every execution of
that input:

```yumly
{
  name = "Environment expression"
  file = "case1.yumly"
  tags = ["feature:env"]

  (envs) {
    TOKEN = "case value"
  }

  variants = [
    ;> one or more variants <;
  ]
}
```

Every case declares `(envs)`, even when it is empty. Case values override equal
names from the fixture root and add names that exist only for that case.

Case names must be unique inside a fixture. The input path is relative to the
fixture folder and must refer to an existing file.

---

## ✿ Variants ‧₊˚

A variant describes one result for one compile profile. The same input may have
successful and invalid variants when compile-time features change its behavior.

Reports identify an execution by fixture, case, and variant:

```text
y0002 / Environment expression / Environment support disabled
```

### ⟡ Successful variants

`<valid-variant>` requires an expected file:

```yumly
<valid-variant> {
  name = "Environment support enabled"
  expected-file = "case1.expected.yumyumy"
}
```

Finishing without an error is not enough. The result from `until-stage` must
match the declared expected file.

### ⟡ Invalid variants

`<invalid-variant>` requires the stage, stable diagnostic code, and complete
primary span expected from the failure:

```yumly
<invalid-variant> {
  name = "Environment support disabled"
  expected-stage = "parser"
  expected-code = "parser.env-disabled"

  (expected-span) {
    file = "case1.yumly"
    line = 1
    col = 1
    end-line = 1
    end-col = 12
  }
}
```

A crash, timeout, unrelated exception, different diagnostic, or matching code
at the wrong span does not satisfy the expected result.

Variant names must be unique inside their case. Every case must contain at
least one variant.

---

## ✿ Pipeline Stages ‧₊˚

| Value | Stage | Result |
|-------|-------|--------|
| `tokenizer` | Tokenizer | Token stream |
| `parser` | Parser | Parser node stream |
| `includes` | Load Includes | Node stream with includes expanded |
| `resolver` | Resolver | Resolved node stream |
| `evaluator` | Evaluator | Evaluated configuration |
| `validator` | Validator | Validated configuration |

The pipeline order is:

```text
tokenizer → parser → includes → resolver → evaluator → validator
```

`until-stage` tells a successful variant which result to compare and sets the
furthest stage the fixture executes. An invalid variant may expect a failure at
any stage up to that point.

---

## ✿ Expected Files ‧₊˚

Expected files use a suffix appropriate for `until-stage`:

| Stage | Suffix | Compared result |
|-------|--------|-----------------|
| Tokenizer | `.expected.tokens` | Token stream |
| Parser | `.expected.nodes` | Parser node stream |
| Includes | `.expected.nodes` | Expanded node stream |
| Resolver | `.expected.nodes` | Resolved node stream |
| Evaluator | `.expected.yumyumy` | Evaluated configuration |
| Validator | `.expected.yumyumy` | Validated configuration |

The runner rejects missing expected files, suffixes incompatible with
`until-stage`, and expected files that no variant references. Expected files
are committed test data; the runner does not silently rewrite them after a
failure.

---

## ✿ Compile Profiles ‧₊˚

The runners create profiles from every compile-flag combination declared by
all fixtures.

`compile-flags` defines a fixture's base combination. A variant derives another
combination with `enable-flags` and `disable-flags`:

```yumly
<invalid-variant> {
  name = "Dotenv support disabled"
  disable-flags = ["yumlyDotenv"]
  expected-stage = "includes"
  expected-code = "include.dotenv-disabled"

  (expected-span) {
    file = "case1.yumly"
    line = 1
    col = 1
    end-line = 1
    end-col = 19
  }
}
```

Before compiling or executing cases, each runner:

1. Discovers every fixture.
2. Expands every case and variant.
3. Applies each variant's enabled and disabled flags to its fixture base.
4. Rejects contradictory or invalid combinations.
5. Normalizes the resulting flag sets.
6. Deduplicates equal profiles across the entire fixture collection.
7. Compiles one runner binary or library for each unique profile it needs.
8. Executes each variant with its assigned profile.

The runners create only combinations declared by fixtures and variants. They do
not generate an automatic power set of every known flag.

Two combinations with the same normalized flags share one compiled profile,
even when they came from different fixtures. A flag listed in both
`enable-flags` and `disable-flags` is a metadata error.

---

## ✿ Runners ‧₊˚

The Nim, Python, and C runners consume the complete discovered fixture plan.
They share fixture identities, cases, variants, tags, environments, expected
results, and normalized profile definitions.

Each runner remains responsible for its own build and interface behavior:

- The Nim runner compiles and executes the native pipeline profiles.
- The Python runner builds the native extension profiles and verifies their
  Python mappings.
- The C runner builds the ABI profiles and verifies C status, values, and
  diagnostics.

A build failure fails its profile and every execution assigned to it. One
runner failing does not turn another runner's result into success.

---

## ✿ Tags ‧₊˚

Tags classify fixtures and allow focused runs:

```yumly
tags = [
  "regression"
  "boundary"
  "integration"
  "feature:env"
  "interface:python"
  "stress"
]
```

Fixture, case, and variant tags are combined for reporting and filtering. Tags
do not imply a stage, compile flag, validity, or expected result.

Useful tags include:

- `regression` for a defect that must not return;
- `boundary` for limits, EOF positions, overflow, and recursion depth;
- `integration` for behavior crossing stages or external resources;
- `feature:*` for compile-time capabilities;
- `interface:*` for runner-specific behavior;
- `stress` and `performance` for expensive cases.

---

## ✿ Environment Isolation ‧₊˚

The fixture `(envs)` block provides shared string values. The case `(envs)`
block overrides or adds values for that case. An empty case block means that it
uses only the fixture environment.

Cases execute with isolated environments. Their values and modifications must
not leak into another case, variant, profile, or runner process.

---

## ✿ Regression, Integration, And Boundary Cases ‧₊˚

A regression fixture keeps the smallest input that reproduces the failure and
the precise result expected after the fix.

Integration fixtures cover interactions such as includes plus validation,
environment loading plus coercion, or native results crossing a runner's public
interface.

Boundary fixtures cover behavior such as:

- EOF after partial tokens;
- stream refills across token boundaries;
- empty and maximum-size values;
- numeric overflow and malformed exponents;
- Unicode and escape sequences;
- recursion and include-depth limits;
- missing, empty, and uncoercible environment values;
- duplicate symbols across included files;
- compile-time features enabled and disabled.

These are ordinary fixtures selected with tags. They do not use separate
identifier formats or directory trees.

---

## ✿ Discovery Failures ‧₊˚

Discovery fails before any case executes when it finds:

- malformed or duplicate fixture identifiers;
- a metadata number different from its folder number;
- an encoded folder phase different from `until-stage`;
- missing schema, input, or expected files;
- duplicate case or variant names;
- an empty case or variant list;
- an expected suffix incompatible with `until-stage`;
- contradictory or invalid compile flags;
- an expected failure stage beyond `until-stage`;
- an invalid variant without its complete diagnostic expectation;
- a successful variant without an expected file;
- an expected file that no variant references.

Broken test data must fail loudly. It must never look like a successful Yumly
execution!! ദ്ദി •⩊• )

---

#### yeah, now you're actually testing me!! (๑˃ᴗ˂)ﻭ
