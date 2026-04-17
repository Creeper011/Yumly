# ✧*･ﾟ Yumly ･ﾟ*✧

> ⚠️ Warning — subject to changes. 

Yumly is a cute, declarative configuration language with fail-fast behavior and optional type safety, blending elements from many configuration formats and some ideas from my head.
The goal is a simple, secure, and personal configuration format that I can use in my projects, meaning the project's focus is on a configuration format tailored to my needs without any external compromises.

The parser is written in [Nim](https://nim-lang.org/) and exports bindings for [Python](https://www.python.org/) via [NimPy](https://github.com/yglukhov/nimpy). There's also a native Nim API for direct usage.

---

## ✿ What's in Yumly?

- **No indentation** — blocks delimited by `{ }` allowing flexible organization
- **Optional type hints** — you can declare intent UwU
- **Fail-fast** — syntax and validation errors are raised immediately with cute cute messages (you can disable this, baka!)
- **No overwriting** — duplicate keys and bindings are not allowed.
- **Native env vars** — `$["VAR"]` and `include { ".env" }` are first class ;)
- **Readable** — it's easy to read and understand ^_^
- **Extensions** `.yumly` and `.yuy` (it's so cute!!)


<details>
<summary>Why i created Yumly</summary>

1. I created Yumly for fun — I had never built a parser before. I wanted something simple and special to use in my own projects.
2. Yumly mixes ideas from many formats, but initially YAML and JSON, but tries to be more explicit, safe.
3. I know the “cuteness” and personality won’t be for everyone — and that’s okay.
4. I also wanted to learn Nim and avoid going down the “Holy C” path.

</details>

## ✿ Syntax & Types

For the complete syntax, see:
- [docs/gramatic/overview.md](docs/gramatic/overview.md) — detailed guide
- [docs/ebnf/grammar.ebnf](docs/ebnf/grammar.ebnf) — formal specification

---

## ✿ Python

For complete documentation, see [docs/usage/python_usage.md](docs/usage/python_usage.md).

### ✦ Installation

```bash
pip install yumly
```

<details>
<summary>Install from source (unstable/git version)</summary>

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
make deps   # install Nim dependencies
pip install .
```

</details>

---

## ✿ Nim

For complete documentation, see [docs/usage/nim_usage.md](docs/usage/nim_usage.md).

### ✦ Installation (source)

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:.
```

---

## ✿ CLI

```bash
yumly_cli check config.yumly
yumly_cli load config.yumly
```

---

## ✿ VSCode Extension

```bash
cd yumly-vscode
npx --yes @vscode/vsce package
code --install-extension yumly.vsix
```

---

## ✿ Tests

```bash
python tests/run_tests.py
nim c -r tests/test_encoder.nim
```

---

## ✿ About Projects (Tests)

- Yumly has a set of PoC (Proof of Concepts) projects that aim to test yumly implementations in a more integrated real-world scenario; they can be found in [tests/projects](./tests/projects/).


## ✿ Limitations:
- hahaha, i made sure to leave this down here.
- The current limitations are:
    - Yumly is not streamable by my clean/modular dumb architecture and by design, as it needs all context to resolve includes, blocks and pairs. This means that the entire file needs to be loaded and parsed before any data can be accessed.

## ★ License ★

MIT — see [LICENSE](LICENSE).
