# ✧*･ﾟ Yumly ･ﾟ*✧

> ⚠️ Warning — subject to changes. 

Yumly is a cute, declarative configuration language with fail-fast behavior and optional type safety, blending elements from many configuration formats and some ideas from my head.
The goal is a simple, secure and a personal configuration format that i can use in my projects..

The parser is written in [Nim](https://nim-lang.org/) and exports bindings for [Python](https://www.python.org/) via [NimPy](https://github.com/yglukhov/nimpy). There's also a native Nim API for direct usage.

---

## ✿ What's in Yumly?

- **No indentation** — blocks delimited by `{ }` allowing flexible organization
- **Optional type hints** — you can declare intent UwU
- **Fail-fast** — syntax and validation errors are raised immediately with cute cute messages (you can disable this, baka!)
- **No overwriting** — duplicate keys and bindings are not allowed.
- **Native env vars** — `$["VAR"]` and `include { ".env" }` are first class ;)
- **Symbols** — global `@` values, recursively resolved (order doesn't matter), reusable across the file (root-only after includes) :3
- **Readable** — it's easy to read and understand ^_^
- **Extensions** `.yumly` and `.yuy` (it's so cute!!)

---

<details>
<summary>Why i created Yumly</summary>

1. I created Yumly for fun — I had never built a parser before. I wanted something simple and special to use in my own projects.
2. Yumly mixes ideas from many formats, but initially YAML and JSON, but tries to be more explicit, safe.
3. I know the “cuteness” and personality won’t be for everyone — and that’s okay.
4. I also wanted to learn Nim and avoid going down the “Holy C” path.

</details>

## ✿ Syntax

<details>
<summary>Comments</summary>

```yumly
;> this is a comment <;

;>
multiline
comment
<;
```

</details>

<details>
<summary>Key-value pairs</summary>

```yumly
;> type hints are optional <;
name ;string = "Yumly"
version ;string = "1.0.0"
debug ;bool = true
port ;int = 8080
ratio ;float = 3.14

;> without type hint, type is inferred from value <;
active = true
count = 42
```

</details>

<details>
<summary>Blocks</summary>

```yumly
(app) {
    name ;string = "Yumly",
    version ;string = "1.0.0",
    debug ;bool = false
}
```

Blocks can be nested:

```yumly
(database) {
    (postgres) {
        host = "localhost",
        port ;int = 5432
    },
    (redis) {
        host = "127.0.0.1",
        port = 6379
    }
}
```

</details>

<details>
<summary>Environment variables</summary>

```yumly
token ;env = $["DISCORD_TOKEN"]
home  ;env = $["HOME"]
```

</details>

<details>
<summary>Include</summary>

```yumly
include { ".env" }           ;> loads environment variables <;
include { "base.yumly" }     ;> imports blocks from another file <;
include { "shared.yuy" }     ;> also accepts .yuy or .yumly <;
```

</details>

<details>
<summary>Strings and Escapes</summary>

```yumly
newline = "Line 1\nLine 2"
tab = "Column 1\tColumn 2"
backslash = "C:\\Path\\Windows"
quotes = "He said: \"Hello!\""
```

</details>

<details>
<summary>Lists and Tuples</summary>

**Lists** — homogeneous, all items of the same type:

```yumly
tags    ;list[string] = ["api", "v2", "stable"]
ports   ;list[int]    = [8080, 8081, 8082]

;> without type hint, inferred from elements <;
hosts = ["localhost", "0.0.0.0"]
```

Valid types: `string`, `int`, `float`, `bool`, `env`.

**Tuples** — heterogeneous, different types:

```yumly
server_info ;tuple = ["localhost", 8080, true]

;> automatically inferred if types are mixed <;
meta = ["staging", 42, false]
```

</details>

<details>
<summary>Comma rules</summary>

Inside blocks, commas separate pairs and sub-blocks. The last item doesn't need a comma:

```yumly
(block) {
    a = "x",
    b = "y",
    c = "z"    ;> last, no comma <;
}
```

At root, pairs on the same line need a comma:

```yumly
name = "John", age = 30
job = "dev"
```

</details>

<details>
<summary>Symbols</summary>
Symbols are global values defined at the root level, below includes, prefixed with `@`. They can be used anywhere in the file and are resolved recursively. The order of definition doesn't matter.

```yumly
@base_url = "https://api.example.com"
@api_version = "v1"
@endpoint = !"@base_url/@api_version" ;> the ! prefix indicates that this string needs to be interpolated <;

(api) {
    baseUrl ;string = @base_url,
    apiVersion ;string = @api_version,
    url ;string = @endpoint
}

```
</details>

### Complete example

```yumly
include { ".env" }

@projectName ;string = "Cid"
@version ;string = "6.0.0"

(global) {
    project ;string = @projectName,
    version ;string = @version,
    description ;string = !"""
    The @projectName project is a revolutionary platform that will change the world!
    Currently in version @version!
    """,
    production ;bool = true,
    tags ;list[string] = ["cloud", "scalable"]
}

(database) {
    host = "localhost",
    port ;int = 6767,
    password ;env = $["DB_PASSWORD"]
}

(services) {
    (api) {
        port = 8080,
        tls ;bool = true,
        endpoints ;list[string] = ["/auth", "/v1/data"]
    }
}
```

---

## ✿ Available types

| Type hint    | Example                                      |
|--------------|----------------------------------------------|
| `;string`   | `name ;string = "Yumly"`                    |
| `;int`      | `port ;int = 8080`                           |
| `;float`    | `ratio ;float = 3.14`                        |
| `;bool`     | `debug ;bool = true`                         |
| `;env`      | `token ;env = $["TOKEN"]`                   |
| `;list[T]`  | `tags ;list[string] = ["a", "b"]`            |
| `;tuple`    | `info ;tuple = ["host", 6767, true]`        |

---

## ✿ Python

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

### ✦ Usage

```python
from yumly import Yumly
from typing import Any

PORT = 6767

yumly = Yumly()

data: dict[str, Any] = yumly.load("config.yumly")
print(data["global"]["project"])
print(data["database"]["port"])

data_to_write: dict[str, str] = {
    "port": PORT,
    "uri": "127.0.0.1", 
}
with open("config2.yumly", "w") as file:
    yumly.dump(data_to_write, file)

# or:
content: str = yumly.dumps(data_to_write)
print(content)

result: bool = yumly.validate_content(content)
print(f"Content validation result: {result}")

file_result: bool = yumly.validate_file("config2.yumly")
print(f"File validation result: {file_result}")

```

---

## ✿ Nim

### ✦ Installation

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:.
```

### ✦ Basic usage

```nim
import Yumly

let config = loadYumly("config.yumly")

echo config["global"]["project"].getStr()
echo config.getBlock("database")["port"].getInt()
```

<details>
<summary>Iteration</summary>

```nim
for blk in config:
    echo blk.name
    for key, val in blk:
        echo key & " = " & val.getStr()
```

</details>

<details>
<summary>Mapping to objects with the <code>to</code> macro</summary>

```nim
type
    App = object
        project: string
        version: string
        production: bool

let app = config.getBlock("global").to(App)
echo app.project   # "Orion"
```

</details>

<details>
<summary>File writing</summary>

```nim
var cfg = newYumly()
cfg.addPair("name", newStringValue("Orion"), "string")

var db = newBlock("database")
db.addPair("host", newStringValue("localhost"))
db.addPair("port", newIntValue(5432), "int")
cfg.addBlock(db)

cfg.writeYumly("output.yumly")
```

</details>

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
    - Yumly is not streamable by my clean/modular dumb architecture and by design, as it needs all context to resolve symbols, includes, blocks and pairs. This means that the entire file needs to be loaded and parsed before any data can be accessed.

## ★ License ★

MIT — see [LICENSE](LICENSE).
