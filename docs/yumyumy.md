# About the Yumyumy ♡ format  
⊹˚. ♡.𖥔 ݁ ˖

It's timeeeee
Ok, formal introduction — The Yumyumy ♡ format is the internal representation from the AST (Abstract Syntax Tree) of a yumly file. It's **not a file format**, but rather a data structure that is used to represent the structure of a yumly file.

## ✿ Why? ⸝> . <⸝
- It's a way to represent the yumly file without using any bindings or language, in a readable and explicit way.

## ✿ Syntax and Examples ദ്ദി◝ ⩊ ◜)
As an internal representation of Yumly, Yumyumy has a few structural distinctions:

| Element | Yumly | Yumyumy |
|---------|-------|---------|
| Root | none | `[]` |
| Pair | `key = value` | `key -> value` |
| Type hint | `;type` | `(type)` or `(list, type)` |
| Block | `(block) { ... }` | `[block] ( ... )` |
| Assignment | `key ;type = value` | `key (type) -> value` |
| List | `[a, b, c]` | `[a, b, c]` |
| Tuple | `(a, b, c)` | `(a, b, c)` |

NOTE: comments are not preserved in yumyumy format

---

An example from [examples/example2.yumly](example2.yumly):

```yumyumy
[
  name (string) -> John Doe
  fullName (string) -> John Doe 67!
  age (int) -> 30
  hobbies (list) -> [reading, hiking, cooking]
  homeDir (env) -> "/home/yumene"
  [block1] (
    variable1 (string) -> value
    variable2 (int) -> 1
    variable3 (list, int) -> [1, 2, 3, 4, 5]
    variable4 (list, string) -> [one, two, three, four, five]
    variable5 (tuple) -> (1, two, 3.3, four, [five])
    variable6 (string) -> string with a "quote" inside and a \ backslash inside
  )
]
```

---

## ✿ Where is Yumyumy used? 
- Yumly CLI (for loading files in terminal and visualizing the AST in a human-readable format)

- Python Lib (using the `to_yumyumy` method to parse and `dict` to yumyumy)

- Nim Lib (using the `loadYumyumy` method to load an yumly file into a yumyumy)

- Tests suites (specifically in .expected.yumyumy files for assertions)

---

[!IMPORTANT]
TODO: currently the enconder of yumyumy doesn't support `(list, type)`, only the `(list)`

### oh, you reached the end? congrats! here's an gift ✧･ﾟ:
```yumly
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣎⠱⣲⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠤⠒⠒⠒⠒⠤⢄⣈⠈⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⡤⠒⠝⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⢄⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀⢠⣢⠐⡄⠀⠉⠑⠒⠒⠒⣄  love you <3
⠀⠀⠀⣀⠴⠋⠀⠀⠀⡎⢀⣘⠿⠀⠀⢠⣀⢄⡦⠀⣛⣐⢸⠀⠀⠀⠀⠀⠀⢘
⡠⠒⠉⠀⠀⠀⠀⠀⡰⢅⠣⠤⠘⠀⠀⠀⠀⠀⠀⢀⣀⣤⡋⠙⠢⢄⣀⣀⡠⠊
⢇⠀⠀⠀⠀⠀⢀⠜⠁⠀⠉⡕⠒⠒⠒⠒⠒⠛⠉⠹⡄⣀⠘⡄⠀⠀⠀⠀⠀⠀
⠀⠑⠂⠤⠔⠒⠁⠀⠀⡎⠱⡃⠀⠀⡄⠀⠄⠀⠀⠠⠟⠉⡷⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠤⠤⠴⣄⡸⠤⣄⠴⠤⠴⠄⠼⠀⠀⠀⠀⠀⠀⠀⠀
```