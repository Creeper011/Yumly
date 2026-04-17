# Yumly Grammar Overview

Helloo — I'm going to show you how Yumly's grammar works.
Yumly intentionally differs from common configuration syntaxes — because it's a config language for meeeee — to provide explicit structure and validation.

## Phase 1: Basic Grammar

Let's start with the basics, what is a pair and a block:

- Pairs are the simplest structure, where you assign a value to a key, like `key = value` or with a specific type `key ;type = value`. The language encourages the use of type hints, even though they're optional, for better clarity and validation.
- Blocks are nested structures, delimited by braces `{ ... }`, where you can have multiple pairs or other blocks inside.

- Example:
```yumly
nameWithoutType = "Yumly"
nameWithType ;string = "Yumly"

(block) {
  name ;string = "Yumly"

  (nestedBlock) {
    key ;string = "value"
  }
}
```
---

Also, comments are made with `;> ... <;` (like a shy anime girl) and can be used for inline documentation or block comments.
```yumly
;> This is an inline comment <;
;> This is a veeeery long comment
that can span multiple lines <;
```

## Phase 2: Available Types

The language supports several value types. Type hints are optional — if you don't specify one, the type is inferred automatically.

### Primitives

| Type | Syntax | Example |
|------|--------|---------|
| String | `;string` | `name ;string = "Yumly"` |
| Integer | `;int` | `port ;int = 6767` |
| Float | `;float` | `ratio ;float = 3.14` |
| Boolean | `;bool` | `debug ;bool = true` |
| Environment | `;env` | `token ;env = $["TOKEN"]` |

### Type Inference

If you don't specify the type hint, the language will infer the type based on the value:

```yumly
active = true         ;> inferred as bool <;
count = 42            ;> inferred as int <;
ratio = 3.14          ;> inferred as float <;
name = "Yumly"        ;> inferred as string <;
```

The language encourages the use of type hints for better clarity and validation, but is flexible enough to infer types when they are not explicitly provided.

## Phase 3: Environment Variables

Environment variables are natively supported with the syntax `$["VAR_NAME"]`:

```yumly
token ;env = $["DISCORD_TOKEN"]
home  ;env = $["HOME"]
secret_key ;env = $["API_SECRET"]
```

You can also load a `.env` file with `include`:

```yumly
include { ".env" }
```

## Phase 4: Include

The `include` command allows you to import content from other files. Includes must come at the top of the file!

```yumly
include { ".env" }           ;> loads environment variables <;
include { "base.yumly" }     ;> imports blocks from another file <;
include { "shared.yuy" }     ;> accepts .yuy or .yumly <;
```

## Phase 5: Strings and Escapes

Strings can use double or single quotes, and also support multiline with `"""`:

```yumly
double = "Text with \"quotes\""
single = 'Also works with single quotes'
multiline = """
    This is some text
    that spans multiple
    lines!
"""
```

Available escape sequences:
```yumly
newline = "Line 1\nLine 2"
tab = "Column 1\tColumn 2"
backslash = "X:\\Path\\Windows"
```

## Phase 6: Lists and Tuples

### Lists

Lists are homogeneous — all elements must be of the same type:

```yumly
tags    ;list[string] = ["api", "v2", "stable"]
ports   ;list[int]    = [6767, 4242, 6969]

;> without type hint, inferred from content <;
hosts = ["localhost", "0.0.0.0"]
```

Valid types for lists: `string`, `int`, `float`, `bool`, `env`.

### Tuples

Tuples are heterogeneous — they can have different types:

```yumly
server_info ;tuple = ["localhost", 8080, true]

;> automatically inferred if types are mixed <;
meta = ["staging", 42, false]
```

## Phase 7: Comma Rules

### Inside Blocks

Commas separate pairs and sub-blocks. The last item **does not** need a comma:

```yumly
(block) {
    a = "x",
    b = "y",
    c = "z"    ;> last, no comma <;
}
```

### At Root

Pairs on the same line need a comma, but different lines don't:

```yumly
name = "John", age = 30
job = "dev"
```

## Complete Example

Here is a complete Yumly file demonstrating everything together:

```yumly
include { ".env" }

(global) {
    project ;string = "Cid",
    version ;string = "6.0.0",
    description ;string = """
    The Cid project is a revolutionary platform!
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

## Yumly File Structure

The basic structure of a Yumly file is:

```
[include { "file" }]
[include { ".env" }]

[pair or block]...
```

- **Include** must come first (or with others at the top)
- Then come pairs and blocks, in any order
- No indentation required — uses `{ }` to delimit blocks