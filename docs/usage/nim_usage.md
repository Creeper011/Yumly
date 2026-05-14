# Nim Usage

Helloo — Yumly's Nim API documentation heree!

## Installation

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:.
```

---

## Quick Start

```nim
import Yumly

let config = loadYumly("config.yumly")
echo config["global"]["project"].getStr()
echo config.getBlock("database")["port"].getInt()
```

---

## Core Types

### YumlyConf

The root configuration object containing all your data:

```nim
YumlyConf* = ref object
  blocks*: seq[Block]
  pairs*: seq[Pair]
  includes*: seq[Include]
```

### Block

Represents a named block like `(database) { ... }`:

```nim
Block* = ref object
  name*: string
  pairs*: seq[Pair]
  subBlocks*: seq[Block]
  line*: int
  col*: int
```

### Value

Represents typed values in the configuration:

```nim
Value* = object
  case kind*: ValueKind
  of vkString:    strVal*: string
  of vkInt:       intVal*: int
  of vkFloat:     floatVal*: float
  of vkBool:      boolVal*: bool
  of vkList, vkTuple: elements*: seq[Value]
  of vkEnv:       envName*: string, envVal*: string
```

### ValueKind

The enum for value types:

```nim
vkString, vkInt, vkFloat, vkBool, vkList, vkTuple, vkEnv
```

---

## Loading

### From File

```nim
let config = loadYumly("config.yumly")
```

### From String

```nim
let content = """
(global) {
    project = "Orion"
}
"""
let config = loadYumlyContent(content)
```
---

## Partial Loading (Pipeline Stages)

Yumly's pipeline can be interrupted at specific stages. This is useful for inspection or custom processing.

```nim
import Yumly

# Load up to Parser stage
let res = loadYumly("config.yumly", psParser)
echo res.ast.repr

# Valid stages:
# psTokenizer
# psParser
# psResolver
# psValidator
# psEvaluator (default)
```

The `PipelineResult` object contains either the AST or the final `YumlyConf`:

```nim
case res.stage
of psTokenizer:
    discard # Tokens are processed internally
of psParser, psResolver, psValidator:
    let ast = res.ast
of psEvaluator:
    let config = res.config
```

Both `loadYumly` and `loadYumlyContent` accept an optional `PipelineStage`:

```nim
let astResult = loadYumly("config.yumly", psParser)
let validatorResult = loadYumlyContent(content, psValidator)
```

---

### Low-Level Pipeline

For manual control, you can call each phase separately:

```nim
# Tokenize + Parse → AST
let ast = parseContentToAST(content)

# Resolve includes and type hints
resolveYumly(ast, ".")

# Validate
validateYumly(ast)

# Evaluate to final config
let config = evaluateYumly(ast)
```

---

## Accessing Values

### Direct Access

```nim
echo config["name"].getStr()
echo config["port"].getInt()
echo config["ratio"].getFloat()
echo config["debug"].getBool()
```

### With Defaults

```nim
let name = config["name"].getStr("default")
let port = config["port"].getInt(8080)
```

### Safe Access with Options

```nim
if config.hasKey("optional"):
    echo config["optional"].getStr()
```

### Indexing Lists/Tuples

```nim
echo config["ports"][0].getInt()
```

### Nested Access

```nim
let value = config{"nested", "key"}
if value.isSome:
    echo value.get().getStr()
```

---

## Iteration

### Over Blocks

```nim
for blk in config:
    echo blk.name
```

### Over Key-Value Pairs

```nim
for key, val in config:
    echo key & " = " & val.getStr()

for key, val in block:
    echo key & " = " & val.getStr()
```

### Over Sub-Blocks

```nim
for subBlock in block:
    echo subBlock.name
```

---

## Building Configs Programmatically

### Creating Values

```nim
let strVal = newStringValue("hello")
let intVal = newIntValue(42)
let floatVal = newFloatValue(3.14)
let boolVal = newBoolValue(true)
let envVal = newEnvValue("API_KEY")
let listVal = newListValue(@[newStringValue("a"), newStringValue("b")])
```

### Creating Config

```nim
var config = newYumly()
config.addPair("host", newStringValue("localhost"))
config.addPair("port", newIntValue(8080))
config.addPair("enabled", newBoolValue(true))
```

### Creating Blocks

```nim
var dbBlock = newBlock("database")
dbBlock.addPair("name", newStringValue("mydb"))
dbBlock.addPair("port", newIntValue(5432))

config.addBlock(dbBlock)
```

### Adding Sub-Blocks

```nim
var apiBlock = newBlock("api")
apiBlock.addPair("version", newStringValue("v1"))
dbBlock.addSubBlock(apiBlock)
```

### Adding to Lists

```nim
var listVal = newListValue(@[])
listVal.add(newStringValue("item1"))
listVal.add(newStringValue("item2"))
```

---

## The `%*` Operator

Create values from Nim expressions:

```nim
let list = %*[1, 2, 3]
let str = %*"hello"
let num = %*42
let flag = %*true
```

Create config from key-value pairs:

```nim
var config = newYumly()
config.addPair("items", %*["a", "b", "c"])
```

---

## Mapping to Objects

Use the `to` macro to convert blocks to Nim objects:

```nim
type
    App = object
        project: string
        version: string
        production: bool

let app = config.getBlock("global").to(App)
echo app.project    # "Orion"
echo app.production # true
```

For nested structures, use `seq[T]` for multiple blocks:

```nim
type
    Service = object
        name: string
        port: int

let services = config.getBlock("services").to(seq[Service])
```

---

## Serialization

### To String

```nim
let content = dumpYumly(config)
echo content
```

### To File

```nim
config.writeYumly("output.yumly")
```

### With Type Inference

```nim
config.writeYumly("output.yumly", inferType = true)
```

---

## Validation

Validate without throwing:

```nim
if validateContent(content):
    echo "Valid!"

if validateFile("config.yumly"):
    echo "File is valid!"
```

---

## Search & Lookup

### Find Block

```nim
if config.findBlock("database").isSome:
    let db = config.getBlock("database")
    # ...
```

### Find Pair

```nim
let value = config.findPair("port")
if value.isSome:
    echo value.get().getInt()
```

### Safe Get

```nim
let value = config.safeGet("key")
```

### Check Existence

```nim
if config.hasKey("port"):
    echo "port exists"

if config.hasBlock("database"):
    echo "database block exists"
```

---

## Type Hints

### Applying Type Hints

```nim
config.applyTypeHints()
```

### Inferring Types

```nim
let hint = inferTypeHint(value)
# Returns "string", "int", "list[string]", etc.
```

---

## API Reference

### Loading Procedures

| Procedure | Description |
|-----------|-------------|
| `loadYumly(path)` | Load and parse a file |
| `loadYumlyContent(content, workingDir)` | Parse content from string |
| `parseContentToAST(content)` | Tokenize and parse to AST |
| `parseFileToAST(path)` | Parse file to AST |

### Accessor Functions

| Function | Description |
|----------|-------------|
| `getStr(val, default)` | Get string value |
| `getInt(val, default)` | Get integer value |
| `getFloat(val, default)` | Get float value |
| `getBool(val, default)` | Get boolean value |
| `getElems(val)` | Get list/tuple elements |

### Indexing

| Operator | Description |
|----------|-------------|
| `config[key]` | Get value by key |
| `blk[key]` | Get value from block |
| `val[index]` | Index into list/tuple |
| `config{keys}` | Safe nested access |

### Search Procedures

| Procedure | Description |
|-----------|-------------|
| `safeGet(config, key)` | Safe lookup returning Option |
| `findPair(config, key)` | Find pair by key |
| `findBlock(config, name)` | Find block by name |
| `getBlock(config, name)` | Get block (raises if not found) |

### Existence Checks

| Procedure | Description |
|-----------|-------------|
| `hasKey(config, key)` | Check if key exists |
| `hasBlock(config, name)` | Check if block exists |

### Construction Functions

| Function | Description |
|----------|-------------|
| `newYumly()` | Create empty config |
| `newBlock(name)` | Create named block |
| `newStringValue(v)` | Create string value |
| `newIntValue(v)` | Create integer value |
| `newFloatValue(v)` | Create float value |
| `newBoolValue(v)` | Create boolean value |
| `newEnvValue(name)` | Create env reference |
| `newListValue(elems)` | Create list value |
| `newTupleValue(elems)` | Create tuple value |

### Modification Procedures

| Procedure | Description |
|-----------|-------------|
| `addPair(config, key, value, typeHint)` | Add pair to config |
| `addBlock(config, block)` | Add block to config |
| `addSubBlock(block, subBlock)` | Add sub-block |
| `addInclude(config, path)` | Add include directive |

### Serialization

| Procedure | Description |
|-----------|-------------|
| `dumpYumly(config)` | Serialize to string |
| `writeYumly(config, path, inferType)` | Write to file |
| `toYumly(pairs, inferType)` | Convert pairs to string |

### Validation

| Procedure | Description |
|-----------|-------------|
| `validateContent(content)` | Validate content string |
| `validateFile(path)` | Validate file |

### Iterators

| Iterator | Yields |
|----------|--------|
| `items(config)` | Blocks |
| `items(block)` | Sub-blocks |
| `items(value)` | List/tuple elements |
| `pairs(config)` | (key, value) tuples |
| `pairs(block)` | (key, value) tuples |
| `mitems(config)` | Mutable pairs |

### Macros

| Macro | Description |
|-------|-------------|
| `%*(x)` | Create Value from Nim expression |
| `to(node, T)` | Convert to Nim object type |

---

