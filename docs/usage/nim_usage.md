# ⋆˚.♪ Nim Usage ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

Helloo!! (˵ •̀ ᴗ •́˵ ) — Welcome to Yumly's ♡ Nim usage documentation! :3

> ⟡ You can also use [the yumly playground](../../playground/) to explore me in action! ദ്ദി •⩊• )

---

## ✿ Installation

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:.
```

---

## ✿ Quick Start

```nim
import Yumly

let config = loadYumly("config.yumly")
echo config["global"]["project"].getStr()
echo config.getBlock("database")["port"].getInt()
```

---

## ✿ Loading

### From a file

```nim
let config = loadYumly("config.yumly")
```

### From a string

```nim
const content = """
(global) {
    project = "Orion"
}
"""
let config = loadYumlyContent(content)
```

---

## ✿ Accessing Values

### Direct access

```nim
echo config["name"].getStr()
echo config["port"].getInt()
```

### With default fallback

```nim
let name = config["name"].getStr("default")
let port = config["port"].getInt(8080)
```

### Conditional access

```nim
if config.hasKey("optional"):
    echo config["optional"].getStr()
```

## ✿ Iterating

### Over blocks

```nim
for blk in config:
    echo blk.name
```

### Over key-value pairs

```nim
for key, val in config:
    echo key & " = " & val.getStr()
```

Ok, now you know the basics, let's proced to the next step

## ✿ Core Types

### `YumlyConf`

The root configuration object containing all your data:

```nim
YumlyConf* = ref object
  blocks*: seq[Block]
  pairs*: seq[Pair]
  includes*: seq[Include]
```

> from: [src/Yumly/types/ast.nim](../../src/Yumly/types/ast.nim) (line: 42–45)

### `Block`

Represents a named block like `(database) { ... }`:

```nim
Block* = ref object
  name*: string
  pairs*: seq[Pair]
  subBlocks*: seq[Block]
  line*: int
  col*: int
```

> from: [src/Yumly/types/ast.nim](../../src/Yumly/types/ast.nim) (line: 32–37)

### `Pair`

Represents a key-value pair like `name ;string = "Emu otori"`:

```nim
Pair* = object
    key*: string
    typeHint*: Option[TypeHint]
    value*: Value
    line*: int
    col*: int
```

> from: [src/Yumly/types/ast.nim](../../src/Yumly/types/ast.nim) (line: 25–30)

### `Value`

Represents typed values in Yumly pairs:

```nim
Value* = object
    case kind*: ValueKind
    of vkString: strVal*: string
    of vkInt: intVal*: int
    of vkFloat: floatVal*: float
    of vkBool: boolVal*: bool
    of vkList, vkTuple:
      elements*: seq[Value]
    of vkEnv:
      envName*: string
      envVal*: string
```

> from: [src/Yumly/types/ast.nim](../../src/Yumly/types/ast.nim) (line: 13–23)

## ✿ Building Configs Programmatically

### Creating values

```nim
let strVal = newStringValue("hello")
let intVal = newIntValue(42)
```

### Creating a config

```nim
var config = newYumly()
config.addPair("host", newStringValue("localhost"))
```

---

## ✿ The `y*` and `y%` Operators ‧₊˚

These are cute helpers to create `Value`s from Nim expressions without all the boilerplate! (˶>⩊<˶)

> ⟡ Note: the `y` prefix is used to avoid conflicts with other libs!

```nim
let list = y*[1, 2, 3]
let str  = y*"hello"
let num  = y*42
let flag = y*true
```

You can also use them when building configs:

```nim
var config = newYumly()
config.addPair("items", y*["a", "b", "c"])
```

## ✿ Mapping to Objects

```nim
type
    App = object
        project: string
        version: string
        production: bool

let config = loadYumly("config.yumly")
let global = config.getBlock("global")

let app = App(
    project:    global["project"].getStr(),
    version:    global["version"].getStr(),
    production: global["production"].getBool()
)

echo app.project  # "Orion"
```

## ✿ Serialization

### To string

```nim
let content = dumpYumly(config)
echo content
```

### To file

```nim
config.writeYumly("output.yumly")
```

## ✿ Search & Lookup ‧₊˚

### Find a block

```nim
if config.findBlock("database").isSome:
    let db = config.getBlock("database")
```

### Find a pair

```nim
let value = config.findPair("port")
if value.isSome:
    echo value.get().getInt()
```

### Check existence

```nim
if config.hasKey("port"):
    echo "port exists! UwU"

if config.hasBlock("database"):
    echo "database block exists! ^_^"
```

## ✿ Type Hints ‧₊˚

### Applying type hints

```nim
config.applyTypeHints()
```

### Inferring types

```nim
let hint = inferTypeHint(value)
# Returns "string", "int", "list[string]", etc.
```

## ✿ API Reference ‧₊˚

### Loading

| Procedure | Description |
|-----------|-------------|
| `loadYumly(path)` | Load and parse a file |
| `loadYumlyContent(content)` | Parse content from a string |
| `parseContentToAST(content)` | Tokenize and parse to AST |

### Accessors

| Function | Description |
|----------|-------------|
| `getStr(val, default)` | Get string value |
| `getInt(val, default)` | Get integer value |
| `getFloat(val, default)` | Get float value |
| `getBool(val, default)` | Get boolean value |

### Indexing & Search

| Operator / Proc | Description |
|-----------------|-------------|
| `config[key]` | Get value by key |
| `hasKey(config, key)` | Check if key exists |
| `hasBlock(config, name)` | Check if block exists |
| `findBlock(config, name)` | Find block by name |
| `findPair(config, key)` | Find pair by key |

---

#### Oh! — you reached the end!! congratulations!! here's a gift for you: ⸜( ˶' ᵕ '˶ )⸝
```text
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣎⠱⣲⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠤⠒⠒⠒⠒⠤⢄⣈⠈⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⡤⠒⠝⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⢄⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀⢠⣢⠐⡄⠀⠉⠑⠒⠒⠒⣄      hello world!
⠀⠀⠀⣀⠴⠋⠀⠀⠀⡎⢀⣘⠿⠀⠀⢠⣀⢄⡦⠀⣛⣐⢸⠀⠀⠀⠀⠀⠀⢘
⡠⠒⠉⠀⠀⠀⠀⠀⡰⢅⠣⠤⠘⠀⠀⠀⠀⠀⠀⢀⣀⣤⡋⠙⠢⢄⣀⣀⡠⠊
⢇⠀⠀⠀⠀⠀⢀⠜⠁⠀⠉⡕⠒⠒⠒⠒⠒⠛⠉⠹⡄⣀⠘⡄⠀⠀⠀⠀⠀⠀
⠀⠑⠂⠤⠔⠒⠁⠀⠀⡎⠱⡃⠀⠀⡄⠀⠄⠀⠀⠠⠟⠉⡷⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠤⠤⠴⣄⡸⠤⣄⠴⠤⠴⠄⠼⠀⠀⠀⠀⠀⠀⠀⠀
```
bye bye and see you later ♡