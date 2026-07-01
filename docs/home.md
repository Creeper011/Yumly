## 𐙚 ‧₊˚ ⋅ Hey!! Welcomee ⋅ ˚₊‧ 𐙚

⟡ This is my house, i call it Yumly-md-docs-2000! — cool name, right? ;)

you probably came from the README, but to recap — Yumly is a cute, declarative 
configuration language with fail-fast behavior and optional type safety, blending 
elements from many configuration formats and some ideas from my head.

Here's what Yumly brings to the table:

- **Optional type hints** — you can declare intent and some behaviors — uwu
- **Fail-fast** — syntax and validation errors are raised immediately with cute cute messages (you can disable the cute errors, ok? :c )
- **No overwriting** — duplicate pairs (keys) and blocks are not allowed!!
- **Native env vars** — `$["VAR"]` and `include { ".env" }` ;)
- **Cute** — it's easy to read and understand :3
- **Cute Extensions** `.yumly` and `.yuy` (it's so cute!!)

I'll guide you through Yumly's features, syntax, and project structure — and 
honestly... i hope you'll enjoy it because ts was hard to make 🥀

---

## ✿ Quick Start ‧₊˚

### Python

```bash
pip install yumly
```

```python
from yumly import Yumly
data = Yumly().load("config.yumly")
```

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

### C

```c
#include <yumly.h>

yumly_document *document = NULL;
yumly_error *error = NULL;
yumly_status status =
    yumly_document_load_file("config.yumly", &document, &error);
```

---

### ✿ Learn the basics ‧₊˚

- [Grammar Overview](gramatic/overview.md) — Syntax, structural rules, and 
  all the language features.
- [Yumyumy ♡ Format](yumyumy.md) — The internal AST representation, useful 
  for tests and debugging.
- [Ylwa (wa wa wa) Format](ylwa.md) — The internal format for benchmarks and logs.

---

### ✿ Use Yumly in your projects ‧₊˚

- [Python Usage](usage/python_usage.md) — Installation, API reference, and 
  real-world examples.
- [Nim Usage](usage/nim_usage.md) — Installation, API reference, and 
  advanced usage.
- [C Usage](usage/c_usage.md) — Building, ownership, errors, and read-only
  document traversal.

### ✿ Want to see it in action?

Explore the [playground folder](../playground/) to experiment with parser 
phases, PoCs, and real-world examples.

---

### ✿ Understand the project architecture ‧₊˚

- [Test System](tests.md) — Test structure, fixture conventions, and how 
  assertions work.

### ✿ Tools

- **CLI ✨:** Check the Yumly CLI ✨ documentation in [docs/usage/yumly_cli.md](usage/yumly_cli.md)
- **VSCode:** Check the [extension folder](../yumly-vscode/) for syntax 
  highlighting installation.

---

### ✿ Known Limitations

- Yumly is not fully streamable by design — it needs all context to resolve 
  includes, blocks, and pairs. Only the tokenizer and parser are streamable 
  for now.
- By default, includes are sandboxed to your home directory (`~`) using the compile-time constant `YumlySandboxDir` (configured via Nim's `--define:YumlySandboxDir=...` or `-d:YumlySandboxDir=...`). If you are running Yumly in a server or shared environment, the default `"~"` lets includes access any `.env`, `.yumly`, or `.yuy` file under your home folder.
- This is a **super personal project** with open code. Contributions are welcome, 
  but theres no guarantee of support or roadmap. use it, enjoy it, and if 
  something breaks, open an issue ♡

---

### ✿ Misc
— I think I’ve noticed the contrast between first-person and impersonal language. I, as Yumly, am not only a config language but also a persona of Yumene. You can call me Yummie or Yumly; that’s why I also have a soundtrack on Spotify — check it out: [Yummie (Yumly) - Spotify](https://open.spotify.com/playlist/4q9OXUzEk62ClOdmAalo1W)

i think that's all for now!! :3

bye bye and see you later ♡
