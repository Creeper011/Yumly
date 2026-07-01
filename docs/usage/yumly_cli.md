# ⋆˚.♪ Yumly CLI ✨ Usage ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

Helloo!! (˵ •̀ ᴗ •́˵ ) — Welcome to ✨ Yumly's ♡ CLI usage documentation! :3

— Yeah, this CLI might not make much sense for practical use, but it's cool and helpful if you want to convert this precious thing into a generic format that's not quite as cute as i am 😭

— well, here's a usage guide for my CLI (˶>⩊<˶)

## ✿ Installation
### GitHub Releases
You can download Yumly from the
[releases page](https://github.com/Creeper011/Yumly/releases).

### Nix / NixOS
If you use Nix, you can install Yumly CLI directly from the flake:

```sh
# Install to your profile
nix profile add github:Creeper011/Yumly

# Or run it directly without installing
nix run github:Creeper011/Yumly -- load example.yumly
```

### Build from source
```sh
nimble --nimbleDir:build/nimble buildCli
# build/bin/yumly-cli
```

The official build enables JSON, YAML, environment, trivia, suggestions, and
my cute CLI messages. Nimble installs the declared dependencies and writes all
generated files under `build/`.

## ✿ Quick Start

```sh
yumly-cli load examples/example2.yumly # shows yumyumy ♡ format
yumly-cli check examples/example2.yumly # checks for errors
yumly-cli check 'key ;string = "value"'
yumly-cli load 'key ;string = "value"'
yumly-cli load examples/example.yumly -yu # shows yumly dump format
yumly-cli load examples/example.yumly -j # shows JSON format
yumly-cli load examples/example.yumly -ya # shows YAML format
yumly-cli load examples/example.yumly -u T # loads until Tokenizer
```

---

## ✿ Usage

```
yumly-cli <check|load> <file|content> [-u <stage>] [-yu] [-j] [-ya] [--no-output|-q]
yumly-cli help [load|check]
```

| Argument | Description |
|----------|-------------|
| `check` | Validate a file or content — returns pass/fail |
| `load`  | Parse and output the configuration |
| `file`  | Path to a `.yumly` or `.yuy` file |
| `content` | Yumly string content (if it's not an existing file) |
| `-u <stage>` or `--until <stage>` | Stop at a specific pipeline stage (default: `E`) |
| `-yu` or `--yumly` | Output in Yumly format instead of Yumyumy ♡ (only for `load`) |
| `-j` or `--json` | Output in JSON format (only for `load`, requires `-d:yumlyJson`) |
| `-ya` or `--yaml` | Output in YAML format (only for `load`, requires `-d:yumlyYaml`) |
| `--no-output` | Consume the selected pipeline stage without retaining or rendering its result; the success message is still shown |
| `-q` or `--quiet` | Consume the selected stage without retaining output or printing the success message |
| `-h` or `--help` | Show general or command-specific help |

Loaded data is written to standard output. Status messages, cute messages, and
diagnostics are written to standard error, so redirecting output does not mix
JSON, YAML, Yumly, or Yumyumy with CLI decoration.

> ⟡ If you don't know what is Yumyumy ♡, check [docs/yumyumy.md](../yumyumy.md)

---

## ✿ Pipeline Stages

| Flag | Stage | Description |
|------|-------|-------------|
| `T` | Tokenizer | Raw token stream |
| `P` | Parser | AST construction |
| `LI` | Load Includes | Resolve `include { }` directives |
| `R` | Resolver | Resolve type hints and env vars |
| `V` | Validator | Structural validation |
| `E` | Evaluator | Final evaluated config (default) |

> Same thing on: [docs/tests.md](../tests.md)
---

## ✿ Commands

### ⟡ `help`

Shows the general command overview or help for one command:

```sh
yumly-cli help
yumly-cli help load
yumly-cli help check
yumly-cli load --help
```

### ⟡ CLI error codes

Argument and capability errors include a stable CLI-specific code, independently
of whether the CLI was compiled with cute messages:

| Code | Meaning |
|------|---------|
| `yumly-cli.unknown-help-topic` | The requested help topic does not exist |
| `yumly-cli.unknown-command` | The command does not exist |
| `yumly-cli.missing-input` | A command is missing its file or content |
| `yumly-cli.option-command-mismatch` | An option was used with the wrong command |
| `yumly-cli.missing-stage` | `--until` has no stage argument |
| `yumly-cli.unknown-stage` | The requested pipeline stage does not exist |
| `yumly-cli.unknown-option` | The option does not exist |
| `yumly-cli.format-disabled` | The requested output format was not compiled in |

### ⟡ `check`

Validates a file or inline content without outputting the parsed data.

```sh
yumly-cli check examples/example.yumly
# Validating file...
# ✓ Valid!  ♡  everything looks cute :3

yumly-cli check examples/example.yumly
# Validating file...
# Check failed ✖
```

```sh
yumly-cli check 'name ;string = "Yumly"'
# Validating content...
# ✓ Valid!  ♡  everything looks cute :3
```

### ⟡ `load`

Parses and outputs the configuration. By default, it shows the **Yumyumy ♡** format.

Use `-yu` or `--yumly` to output the original **Yumly** dump format instead.
Use `-j` or `--json` for JSON output.
Use `-ya` or `--yaml` for YAML output.
Use `--no-output` to consume the selected pipeline stage without retaining or
serializing its result. Use `-q` or `--quiet` to do the same while also
suppressing the success message.

```sh
# Outputs in Yumyumy ♡ format (default)
yumly-cli load examples/example.yumly

# Outputs in Yumly dump format
yumly-cli load examples/example.yumly -yu

# Outputs in JSON format
yumly-cli load examples/example.yumly -j

# Outputs in YAML format
yumly-cli load examples/example.yumly -ya

# Load from string
yumly-cli load 'name ;string = "Yumly"'

# Validate and evaluate without serializing the result
yumly-cli load examples/example.yumly --no-output
```

---

## ✿ Examples

### Full pipeline → Yumyumy ♡ (default)

```sh
yumly-cli load 'name ;string = "Yumly"
version ;string = "2.4.5"
(database) {
    host = "localhost",
    port = 5432
}'
```
```
[
  name (string) -> Yumly
  version (string) -> 2.4.5
  [database] (
    host (string) -> localhost
    port (int) -> 5432
  )
]
```

### Full pipeline → Yumly dump (with `-yu`)

```sh
yumly-cli load 'name ;string = "Yumly"' -yu
```
```
name ;string = "Yumly"
```

### Stop at Tokenizer

```sh
yumly-cli load 'name ;string = "Yumly"' -u T
```
```
tkIdent "name"
tkDeclaration
tkIdent "string"
tkEquals
tkString "Yumly"
tkEOF
```

### Stop at Parser (AST)

```sh
yumly-cli load '(app) { name ;string = "test" }' -u P
```

### Validate and load from raw string

```sh
yumly-cli check '(app) { name = "test" }'
# Validating content...
# ✓ Valid!  ♡  everything looks cute :3

yumly-cli load '(app) { name ;string = "test" }' -yu
# (app) {
#     name ;string = "test"
# }
# ✓ Loaded!  ♡  tadaaa!! ♡
```

### Flags in any order

```sh
yumly-cli load 'name ;string = "Yumly"' -yu -u E
yumly-cli load 'name ;string = "Yumly"' -u E -yu
# both work the same way!
```

---

#### Oh! — you reached the end!! congratulations!! here's a gift for you: ⸜( ˶' ᵕ '˶ )⸝
```text
⠀⠀⠀⠀⠀⠀⠀⠀⣠⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠻⡿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢘⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠿⠥⠤⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⡠⡄⣤⠀⠀⠀⢀⠃⣷⡄⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠠⠀⠆⠀⠀⠐⠀⠈⠀⠨⠂⡄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠚⠀⠠⠀⠀⠀⠀⢀⠀⠈⠐⣠⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠐⠀⠀⠀⠂⠀⠀⡀⠀⠀⠂⢁⢊⡅⠀⠀⠀⠀
⠀⠀⠀⠀⢀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠄⠀⠂⡐⢼⡀⠀⠀⠀
⠀⠀⠀⠀⠂⠀⠀⠀⠂⠀⠀⣆⠀⠀⠀⠈⠄⠀⡔⣣⠀⠀⠀
⠀⠀⠀⡡⠊⢆⠀⡀⠀⠀⡇⠈⠣⡀⠀⠀⠡⠀⠌⠐⣣⠀⠀
⠀⡐⣬⢑⡅⢊⢎⣛⢬⡅⢧⠡⣂⣀⣄⠀⠈⠠⠈⠠⢘⢧⠀
⢀⢱⡖⣍⣿⣧⠀⠣⣧⠓⠀⡜⣅⣿⣿⣧⢀⠐⠀⠂⢤⠭⡂
⠠⠸⢇⠻⣿⡟⠂⠀⠘⢷⠀⠈⢿⣿⡿⡻⡉⠄⡁⠀⢀⠨⡆
⠨⠀⠀⠀⠀⠀⠀⠐⠀⠀⠀⠀⠀⠀⠈⠀⠣⠀⠄⠐⠀⢁⡂
⠈⡀⠀⠀⠀⠀⠀⢤⣀⣀⣠⠆⠀⠀⠀⠀⠁⠐⠌⠄⡠⢷⠃
⠀⠐⡠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠁⠀⡃⠠⣂⢢⡜⠀
⠀⠀⠈⢄⠁⢀⠀⡀⠀⠀⡀⠀⠠⠀⠀⠀⡠⠀⢁⢒⠈⠀⠀
⠀⠀⠀⠀⠐⠠⡀⠂⠈⠄⠀⣀⠀⠈⢂⠈⠠⡰⠖⠁⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠉⠛⠷⣶⢾⣼⣧⡿⠷⠋⠁⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
```
bye bye and see you later ♡
