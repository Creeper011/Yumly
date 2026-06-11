# ✧*･ﾟ Yumly ･ﾟ*✧

> ⚠️ Warning — subject to changes. 

Yumly is a cute, declarative configuration language with fail-fast behavior and optional type safety, blending elements from many configuration formats and some ideas from my head.

⟡ **Hey! New here? Check my [Documentation Home](docs/home.md) for a starter guide!**

---

## ✿ What's in Yumly?

- **No indentation** — blocks delimited by `{ }` allowing flexible organization
- **Optional type hints** — you can declare intent UwU
- **Fail-fast** — syntax and validation errors are raised immediately with cute cute messages
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

## ✿ Syntax & Features

For the complete syntax, see:
- [Grammar Overview](docs/gramatic/overview.md) — detailed guide
- [EBNF Grammar](docs/ebnf/grammar.ebnf) — formal specification
- [Yumyumy ♡ Format](docs/yumyumy.md) — internal AST representation
- [Ylwa Format](docs/ylwa.md) — benchmark and log format

## ✿ Quick Start

### Python

```bash
pip install yumly
```

```python
from yumly import Yumly
data = Yumly().load("config.yumly")
```
> Hey!, check out the [Python Usage Guide](docs/usage/python_usage.md) for more.

### Nim

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:. # not published on Nimble yet
```

```nim
import Yumly
let config = loadYumly("config.yumly")
```
> Hey!, check out the [Nim Usage Guide](docs/usage/nim_usage.md) for more.

### Nix / NixOS (For the [Yumly CLI](docs/usage/yumly_cli.md) ✨)

```bash
nix profile install github:Creeper011/Yumly
```

## ✿ Development & Tools

- **CLI ✨:** Check the Yumly CLI ✨ documentation in [docs/usage/yumly_cli.md](docs/usage/yumly_cli.md)
- **Playground 🛝:** Explore PoCs and interactive notebooks in [The Playground](docs/playground.md)
- **VSCode:** Check the [extension folder](yumly-vscode/) for installation.
- **Tests:** Detailed in [Test System](docs/tests.md).

## ✿ Additional Information:

- This is a **super personal project** with open code. Contributions are welcome, 
  but theres no guarantee of support or roadmap. use it, enjoy it, and if 
  something breaks, open an issue ♡

## ★ License ★

MIT — see [LICENSE](LICENSE).
  