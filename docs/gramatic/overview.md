# ₊⋆⋆⁺ Yumly Grammar Overview ⁺₊⋆⁺
⊹˚. ♡.𖥔 ݁ ˖

Do you want to know about my grammar? don't care, i'll show you anyway! >:3

I intentionally differ from common configuration syntaxes — because **primarily, i'm a config language for meeee >:3** — to provide explicit structure and validation.

I'll show you my grammar in steps (features), because in my fucking head it's easier this way. `¯\_(ツ)_/¯`

> ⟡ Just to remember — no duplicate pairs, blocks or schemas in the
> same scope!
>
> I merge includes into the same AST. Because of that, names brought by an
> include participate in the same duplication rule. but relax, I'll throw a
> specific include error when this happens.


## ✿ Step 1: Basic Grammar

Ok — let's start with the basics, what is a pair and a block:

- Pairs are the simplest structure, where you assign a value to a name, like
  `name = value` or optionally with a specific type: `name ;type = value`.
  Type hints are optional, and idiomatically I don't repeat an obvious primitive
  type. They're most useful when the type carries extra information, such as a
  typed list or a schema.
- Blocks are nested structures, delimited by braces `{ ... }`, where you can have multiple pairs or other blocks inside.

Example:
```yumly
name = "Yumly"
ports ;list[int] = [6767, 8080]

(block) {
  name = "Yumly"

  (nestedBlock) {
    key = "value"
  }
}
```

Indentation does not define my structure — braces do that. My idiomatic style
uses two spaces for each nested scope.

Also, comments are made with `;> ... <;` (like a shy anime girl (ᵕ—ᴗ—). ) and can be used for inline documentation or block comments.
```yumly
;> This is an inline comment <;

;> This is a veeeery long comment
that can have multiple lines
and ends here <;
```

> [!IMPORTANT]
> **Trivia preservation is a compile-time feature.**
>
> Comments are always valid syntax. When compiled with `-d:yumlyTrivia`,
> comments, whitespace, and newlines are preserved on tokens so formatters and
> other tools can reproduce them. Without the flag, trivia is consumed and
> discarded. The standard CLI build enables trivia preservation.

## ✿ Step 2: Available Types

I support several value types, and I infer every value from what it already is.
Type hints are optional assertions that I check against that inferred type.

### Primitives

| Type | Syntax | Example |
|------|--------|---------|
| String | `;string` | `name ;string = "Yumly"` |
| Integer | `;int` | `port ;int = 6767` |
| Float | `;float` | `ratio ;float = 3.14` |
| Boolean | `;bool` | `debug ;bool = true` |

### Numeric Literals

Float literals may also use scientific notation:

```yumly
requests-estimate = 1.2e6
tiny-value = 3.5e-4
```

### Type Inference

Values already tell me what type they are. I infer that type from the literal or
expression whether you write a hint or not:

```yumly
active = true         ;> inferred as bool <;
count = 42            ;> inferred as int <;
ratio = 3.14          ;> inferred as float <;
name = "Yumly"        ;> inferred as string <;
```

A type hint declares the type you expect; it does not magically assign a type
to an otherwise untyped value. When a hint is present, I compare it with the
type I inferred and reject the pair when they disagree:

```yumly
inferred-port = 6767               ;> inferred as int <;
checked-port ;int = 6767            ;> valid: the hint matches <;
wrong-port ;string = 6767           ;> invalid: int is not string <;
```

Type hints validate; they do not coerce. Explicit conversion, such as an
environment variable's `coerceType`, is a separate mechanism.

### Constraints

A type hint can also constrain which values of that type I accept. Constraints belong to type hints themselves, so they can be used on ordinary pairs as well as fields inside schemas.

```yumly
hour-12 ;int[0..12] = 8
hour-24 ;int[0..24] = 18

positive-delay ;float[>0.0] = 0.5
retry-count ;int[>=0] = 3

short-name ;string[0..4] = "Miki"
```

Ranges such as `[0..12]` set inclusive lower and upper bounds. Comparisons such
as `[>0]` and `[>=0]` set strict and inclusive lower bounds. For strings, a
range constrains the number of characters.

Like every other type hint, a constrained hint validates the value without
coercing it.

Use a type hint when it adds information. Writing `name ;string = "Yumly"`
is valid, but usually it only says what the string already told us. That's
boring!! 🥀

## ✿ Step 3: Environment Variables

> [!IMPORTANT]
> **Environment values are a compile-time feature.**
>
> Env values are available when compiled with `-d:yumlyEnv`. Without the flag,
> `$[...]` is rejected with a feature-disabled parser error.
> The standard CLI build enables environment values.

I natively support environment variables with `$[]`. An env expression contains
a variable name and may also provide a coercion type and a default:

```yumly
token = $["DISCORD_TOKEN"]
home = $["HOME" ?? "/tmp"]
workers = $["YUMLY_WORKERS"; int ?? 2]
```

The parts are:

```text
$["VAR_NAME"; coerceType ?? default]
```

- `VAR_NAME` is required.
- `coerceType` is optional and converts the environment value when possible.
- `default` is optional and is used when the environment variable is missing.
- A present value that cannot be converted is an error; it does not silently
  fall back to the default.

You can also load a `.env` file with `include`:

```yumly
include { ".env" }
```

> that's cool, right? (´▽｀) you don't need to use another lib just to load environment variables... i made it easy for you 🥀, do you like me now? ;-;

## ✿ Step 4: Include

The `include` command lets you import content from other files. One include may
contain multiple paths, separated by commas. Includes must come at the top of
the file! >:3

```yumly
;> Example of valid includes <;
include { ".env", "base.yumly", "types.yu" }
```

> [!IMPORTANT]
> **`.env` loading is a compile-time feature.**
>
> Including a `.env` file requires both `-d:yumlyEnv` and `-d:yumlyDotenv`.
> `yumlyDotenv` cannot be enabled without `yumlyEnv`; that flag combination is
> rejected at compile time. Builds without `yumlyDotenv` reject `.env` includes
> with a feature-disabled error. The standard CLI build enables both flags.

- `.env` files provide environment variables.
- `.yumly` and `.yuy` files provide configuration content.
- `.yu` files contain schemas only.
- A trailing comma before `}` is not allowed in an include.

Oh, an important thing — I merge includes into the parent AST, so they count for the
**no duplication** rule! If an imported pair collides with a sibling pair, or
an imported block collides with a sibling block, I'll reject it. (i'm talking seriously >:3)
Make sure you don't include a file A that includes a file B that includes a file A, as this is a circular import (if you do this, I will crash- out!!) >_<

## ✿ Step 5: Strings and Escapes

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

## ✿ Step 6: Lists And Objects

I let lists be homogeneous (all values use the same type with `;list[T]`) or
heterogeneous (mixed values with `;list` or no type hint):

```yumly
tags ;list[string] = ["api", "v2", "stable"]
ports ;list[int] = [6767, 4242, 6969]
info ;list = ["localhost", 8080, true]

;> without type hint, inferred from content <;
hosts = ["localhost", "0.0.0.0"]
```

List items are values that can be primitives or other lists.
Also, for more complex data, you can organize it as an object:
a brace-delimited value with no name whose body may contain pairs and blocks.

```yumly
mixed-values ;list = [
  1
  "two"
  ["nested", "list"]
  {
    label = "inline object"
    enabled = true

    (metadata) {
      source = "list"
    }
  }
]
```

Objects are exclusive to lists!! **A pair cannot have an object directly as its value >_<**. Therefore, use the blocks when organizing data outside of lists:

```yumly
(maintainer) {
  name = "Miki"
}
```

An empty list starts without a concrete element type — it behaves like `any`
until context constrains it. A hint can provide that context immediately:

```yumly
anything = []
ports ;list[int] = [] ;> can only have int values, but is empty <;
```

## ✿ Step 7: Schemas (for validation shaping)

Schemas describe reusable object shapes. A field without a value is required;
a field with a value provides a default:

```yumly
[dependency] {
  name ;string
  description ;string
  optional ;bool = false
}
```

Every schema field needs a type hint. A bare field such as `name` is invalid;
write `name ;string` instead.

### Blocks in schemas

Schemas can describe named blocks with the schema-only `;blk` type. This is
not a value type for ordinary pairs: it declares that the object validated by
the schema may or must contain a block with that name.

A block declaration without `=` is required. The body describes the pairs
accepted inside it, using the same required/default rules as the surrounding
schema:

```yumly
[service] {
  database ;blk {
    host ;string
    port ;int = 5432
  }
}
```

Here, `(database) { ... }` must exist. Its `host` pair is required and `port`
has a default.

Adding `=` makes the whole block optional:

```yumly
[service] {
  metadata ;blk = {
    owner ;string
    private ;bool = false
  }
}
```

The braces after `;blk =` describe the block's shape; they do not create a
default block. `(metadata) { ... }` may be absent, but, when present, its
contents must satisfy the inline schema. In the example above, `owner` is still
required whenever the block exists.

When pair names are not known in advance, `;blk[type]` declares a required,
open block whose pair values must all have the selected type:

```yumly
[test-case] {
  envs ;blk[string]
}
```

An `envs` block accepted by this schema may contain any pair names, but every
value must be a string:

```yumly
(envs) {
  HOME = "/tmp/yumly"
  TOKEN = "secret"
}
```

Bare `;blk` without either an inline body or `[type]` is invalid.

`.yu` files contain schemas only. Schemas may also be declared in yumly's files

A schema name can be used as the element type of a list:

```yumly
dependencies ;list[dependency] = [
  {
    name = "Yumene"
    description = "yu core"
  }
]
```

When the list type does not identify the schema, an object can carry
its own schema tag:

```yumly
mixed ;list = [
  <dependency> {
    name = "Yumene"
    description = "yu core"
  }
]
```

I reject unknown fields in typed objects and missing required (that does not have an default value) fields also fail immediately.

## ✿ Step 8: Comma Rules

> this is a little bit different from other syntaxes — so, lock in bro. (ㆆ_ㆆ)

For any scope, a newline acts as a separator. When two sibling items (pair, blocks, includes, schemas)
share a line, put a comma between them:

```yumly
name = "John", age = 30
job = "dev"

(block) {
  a = "x"
  b = "y", c = "z"
}

list ;list[int] = [
  1
  2
  3, 4, 5
]

list2 = [{a = "a", (x) {y = "z"}}]

hello = "world", (config) {}
t
(name) {}, version = "1.0"

[yumene] { favorite ;bool = true }, (block) { y = "z" }

list = [{name = "A"}, { (metadata) {enabled = true}, x = "y" }]
```

Includes also use commas between paths, but do not accept a trailing comma.

> But I'll make one exception!! **You can use a trailing comma instead of a newline** — but i don't recommend it (it's not idiomatic) >:3

## ✿ Step 9: File Structure

My files have a syntax order — includes first, then schemas, then pairs and blocks.
these orders are analyzed in parsing! >:3

```yumly
include { ".env", "file.yumly" }

[schema] {
  field ;string
}

pair or block...
```

- Include must come first (comments before includes do not count! so you can add comments before includes)
- Schemas come after includes and before the configuration body.
- Pairs and blocks come after schemas and may be mixed in any order.
- `.yu` files are schema-only.

## ✿ Examples

Okay :3, now i think you're know most part of my grammar, so finally, i can show you examples:

### 1. Discord Bot
```yumly
;> Discord Bot Configuration <;
include { ".env" }

;> plugins for additional features <;
[plugin] {
  module-path ;string
  enabled ;bool = true
  load-order ;int[>=0]
}

name = "Cid"
prefix = "?yu", version = "0.1.0"
owner-id = $["OWNER_ID"; int]

(application) {
  token = $["DISCORD_TOKEN"]
  shard-count ;int[>0] = 5

  plugins ;list[plugin] = [
    {
      module-path = "plugins/music-plugin"
      enabled = true ;> explicitly defining this as true <;
      load-order = 0
    }
    {
      module-path = "plugins/funny-commands-plugin"
      load-order = 1
    }
    {
      module-path = "plugins/moderation-plugin"
      load-order = 2
    }
  ]

  (intents) {
    guilds = true
    members = true
    messages = true
    message-content = true
  }

  (presence) {
    status = "online"
    activity-type = "watching"
    activity-name = "over the server"
  }
}

(logging) {
  level = $["LOG_LEVEL"; string ?? "INFO"]
  stream-log = "/dev/tty1"
}
```

### 2. Package
```yumly
;> Package Manifest Example <;
include { "dependency.yu" }

name = "Package"
version = "1.0.0", author = "my brain"
description = "Package - a description is really necessary?? :c"

(details) {
  build-file = "./build-steps.yumly"
  license = "MIT"

  (dependencies) {
    dependencies ;list[dependencies] = [
      {
        path = "github:Creeper011/Yumly"
      }
      {
        path = "github:golang/go"
      }
    ]
  }
}
```
```yu
;> Package Manifest Example (Schema) <;
[dependencies] {
  path ;string ;> a url or a local path <;
}
```

### 3. Cafe Menu
```yumly
;> Cafe configuration <;

[item] {
  name ;string
  type ;string
  price ;float[>0.0]
  description ;string
  ingredients ;list[string]
}

customer-name = "Miki"
menu ;list[item] = [
  {
    name = "Coffee"
    type = "drink"
    price = 2.5
    description = "Hot coffee"
    ingredients = ["Coffee", "Water"]
  }
  {
    name = "Tea"
    type = "drink"
    price = 2.0
    description = "Hot tea"
    ingredients = ["Tea", "Water"]
  }
  {
    name = "Juice"
    type = "drink"
    price = 3.0
    description = "Fresh juice"
    ingredients = ["Juice", "Water"]
  }
  {
    name = "Snack"
    type = "food"
    price = 1.5
    description = "Snack"
    ingredients = ["Snack", "Water"]
  }
  {
    name = "Cake"
    type = "food"
    price = 2.5
    description = "Cake"
    ingredients = ["Cake", "Water"]
  }
  {
    name = "Burrito"
    type = "food"
    price = 5.0
    description = "Burrito"
    ingredients = ["Burrito", "Water"]
  }
  {
    name = "Burguer"
    type = "food"
    price = 6.0
    description = "Burguer"
    ingredients = ["Burguer", "Water"]
  }
  {
    name = "Pizza"
    type = "food"
    price = 7.0
    description = "Pizza"
    ingredients = ["Pizza", "Water"]
  }
]
```

> ⟡ look this syntax!!! is soooo cuteee (˶>⩊<˶)

Now you can finally use me! :3

#### Oh! — you reached the end!! congratulations!! here's a gift for you: ⸜( ˶' ᵕ '˶ )⸝
mikuu dayoo!
