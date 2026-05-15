# ₊⋆⋆⁺ Yumly Grammar Overview ⁺₊⋆⁺
⊹˚. ♡.𖥔 ݁ ˖

Do you want to know about Yumly's grammar? don't care, i'll show you anyway! >:3

Yumly intentionally differs from common configuration syntaxes — because **primarily, it's a config language for meeee >:3** — to provide explicit structure and validation.

I'll show you the yumly grammar in phases (features), because in my fucking head it's easier this way. `¯\_(ツ)_/¯`

> ⟡ Just to remeber — no duplicate keys, blocks, or values in the same file, including includes! >:3
> - If an file with `(blockA)` imports other file with `(blockA)` — it's a duplication!

## ✿ Phase 1: Basic Grammar

Ok — let's start with the basics, what is a pair and a block:

- Pairs are the simplest structure, where you assign a value to a key, like `key = value` or with optional a specific type `key ;type = value`. The language encourages the use of type hints, even though they're optional, for better clarity and validation.
- Blocks are nested structures, delimited by braces `{ ... }`, where you can have multiple pairs or other blocks inside.

Example:
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

Also, comments are made with `;> ... <;` (like a shy anime girl (ᵕ—ᴗ—). ) and can be used for inline documentation or block comments.
```yumly
;> This is an inline comment <;

;> This is a veeeery long comment
that can have multiple lines
and ends here <;
```

> you can use comments anywhere! pairs, blocks, includes, etc. in parser, they are not "counted" at all :3

## ✿ Phase 2: Available Types

The language supports several value types. Type hints are optional — if you don't specify one, the type is inferred automatically (use type hints pls 🥀).

### Primitives

| Type | Syntax | Example |
|------|--------|---------|
| String | `;string` | `name ;string = "Yumly"` |
| Integer | `;int` | `port ;int = 6767` |
| Float | `;float` | `ratio ;float = 3.14` |
| Boolean | `;bool` | `debug ;bool = true` |
| Environment | `;env` | `token ;env = $["TOKEN"]` |

### Type Inference

If you don't specify the type hint, the language will infer the type based on the value: (use type hints pls, they're cute 🥀)

```yumly
active = true         ;> inferred as bool <;
count = 42            ;> inferred as int <;
ratio = 3.14          ;> inferred as float <;
name = "Yumly"        ;> inferred as string <;
```

The language encourages the use of type hints for better clarity and validation, but is flexible enough to infer types when they are not explicitly provided. (if you don't use type hints, you're a bad person 😭)

## ✿ Phase 3: Environment Variables

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

> that's cool, right? (´▽｀) you don't need to use another lib just to load environment variables... i made it easy for you 🥀, do you like me now? ;-;

## ✿ Phase 4: Include

The `include` command allows you to import content from other files. Includes must come at the top of the file! >:3

```yumly
;> Example of valid includes <;
include { ".env" }           ;> Loads environment variables, this will populate the $[] variable values <;
include { "base.yumly" }     ;> Imports blocks and pairs from another file <;
include { "shared.yuy" }     ;> Accepts .yuy or .yumly <;
```

Oh, an important thing — includes count for the **no duplication** rule! if an file with `(blockA)` imports other file with `(blockA)` — it's a duplication! (i'm talking seriously >:3)

Includes "merges" into the parent file! so, if a file that you're importing has the same block as another file, it will be counted as a duplication! >:3
Make sure if you don't include an file A that includes an file B that includes an file A, this is a circular import >_<

## ✿ Phase 5: Strings and Escapes

Strings can use double or single quotes, and also support multiline with `"""`:

```yumly
double = "Text with \"quotes\""
single = 'Also works with single quotes'
multiline = """
    This is some text
    that spans multiple
    lines! >:3
"""
```

Available escape sequences:
```yumly
newline = "Line 1\nLine 2"
tab = "Column 1\tColumn 2"
backslash = "X:\\Path\\Windows\\Microslop"
```

The escapes available are:
- `\n` (newline)
- `\t` (tab)
- `\\` (backslash)
- `\"` (double quote)
- `\'` (single quote)

## ✿ Phase 6: Lists and Tuples

### ⟡ Lists

Lists are homogeneous — all elements must be of the same type: (don't forget it!)

```yumly
tags    ;list[string] = ["api", "v2", "stable"]
ports   ;list[int]    = [6767, 4242, 6969]

;> without type hint, inferred from content <;
hosts = ["localhost", "0.0.0.0"]
```

Valid types for lists: `string`, `int`, `float`, `bool`, `env`.

### ⟡ Tuples

Tuples are heterogeneous — they can have different types:

```yumly
server_info ;tuple = ["localhost", 8080, true]

;> automatically inferred if types are mixed <;
meta = ["staging", 42, false]
```

## ✿ Phase 7: Comma Rules

> this is a little bit different from other syntaxes — so, lock in bro. (ㆆ_ㆆ)

### ⟡ Inside Blocks

Commas separate pairs and sub-blocks. The last item **does not** need a comma:

```yumly
(block) {
    a = "x",
    b = "y",
    c = "z"    ;> last, optional comma <;
}
```

### ⟡ At Root

Pairs on the same line need a comma, but different lines don't:

```yumly
name = "John", age = 30
job = "dev"
```

## ✿ Phase 8: File Structure

The yumly has an syntax order — includes first, then pairs and blocks.
these orders are analyzed in parsing! >:3

```yumly
include { "file.yumly" }
include { ".env" }

pair or block...
```

- **Include** must come first (comments before includes does not count! so you can add before of includes)
- Then come pairs and blocks, in any order

## ✿ Complete Example

A complete Yumly file demonstrating everything together:

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

> ⟡ look this syntax!!! is soooo cuteee (˶>⩊<˶)

Now you can finally use yumly! :3

#### Oh! — you reached at the end!! congratulations!! here's an gift for you: ⸜( ˶' ᵕ '˶ )⸝
mikuu dayoo!