## 𐙚 ‧₊˚ ⋅ Hey!! Welcomee ⋅ ˚₊‧ 𐙚

⟡ This is my house, i call it Yumly-md-docs-2000! — cool name, right? ;)

you probably came from the README, but to recap — Yumly is a cute, declarative 
configuration language with fail-fast behavior and optional type safety, blending 
elements from many configuration formats and some ideas from my head.

Here's what Yumly brings to the table:

- **No indentation** — blocks delimited by `{ }`, flexible organization
- **Optional type hints** — declare intent when you want to `;)`
- **Fail-fast** — syntax and validation errors raised immediately
- **No overwriting** — duplicate keys are not allowed, ever
- **Native env vars** — `$["VAR"]` and `include { ".env" }` are first-class
- **Readable** — easy to read and understand ^_^
- **Two extensions** — `.yumly` and `.yuy` (the second one is so cute!!)

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
nimble install yumly
```

```nim
import Yumly
let config = loadYumly("config.yumly")
```

---

### ✿ Learn the basics ‧₊˚

- [Grammar Overview](gramatic/overview.md) — Syntax, structural rules, and 
  all the language features.
- [Yumyumy ♡ Format](yumyumy.md) — The internal AST representation, useful 
  for tests and debugging.

---

### ✿ Use Yumly in your projects ‧₊˚

- [Python Usage](usage/python_usage.md) — Installation, API reference, and 
  real-world examples.
- [Nim Usage](usage/nim_usage.md) — Installation, API reference, and 
  advanced usage.

### ✿ Want to see it in action?

Explore the [playground folder](../playground/) to experiment with parser 
phases, PoCs, and real-world examples.

---

### ✿ Understand the project architecture ‧₊˚

- [Test System](tests.md) — Test structure, fixture conventions, and how 
  assertions work.

### ✿ Tools

- **CLI:** `yumly_cli check config.yumly`
- **VSCode:** Check the [extension folder](../yumly-vscode/) for syntax 
  highlighting installation.

---

### ✿ Known Limitations

- Yumly is not fully streamable by design — it needs all context to resolve 
  includes, blocks, and pairs. Only the tokenizer and parser are streamable 
  for now.
- This is a **super personal project** with open code. Contributions are welcome, 
  but theres no guarantee of support or roadmap. use it, enjoy it, and if 
  something breaks, open an issue ♡

---

i think that's all for now!! :3

bye bye and see you later ♡