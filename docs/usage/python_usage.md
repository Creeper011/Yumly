# ⋆˚.♪ Python Usage ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

Helloo!! (˵ •̀ ᴗ •́˵ ) — Welcome to Yumly's ♡ Python usage documentation! :3 

- — this was tuff?

Oh — before i forget, you also can use [the yumly playground notebook](../../playground/Yumly.ipynb) to test as a demo ദ്ദി •⩊• )

## ✿ Installation

```bash
pip install yumly
```

Or from source:

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
pip install .
```

---

## ✿ Quick Start

```python
from yumly import Yumly

yumly = Yumly()
data = yumly.load("config.yumly") # returns a dict (YumlyData)
print(data["app"]["name"])
```

---

ok, now — lock in guys. ᗜ ⩊ ᗜ

## ⟡ The Yumly Class

The `Yumly` class is your main entry point for all operations.

### ✿ Loading Files

```python
from yumly import Yumly

yumly = Yumly()
data = yumly.load("config.yumly")
```

### ✿ Loading from String

```python
content = '''
(app) {
    name = "Yumly",
    version = "1.0.0",
}
'''
data = yumly.loads(content)
print(data["app"]["name"])  # "Yumly"
```

---

## ✿ YumlyData

`load()` and `loads()` don't return a plain `dict` — they return a `YumlyData` instance, which is a `dict` subclass with one extra capability: it caches the original Yumyumy ♡ representation produced during parsing.

> ⟡ If you don't know what is Yumyumy ♡, check [docs/yumyumy.md](../yumyumy.md)

```python
from yumly import Yumly, YumlyData

yumly = Yumly()
data = yumly.load("config.yumly")

print(type(data))          # <class 'yumly.yumly.YumlyData'>
print(isinstance(data, dict))  # True — behaves exactly like a dict
```

### ✿ `original_yumyumy()`

Returns the cached Yumyumy ♡ generated during parsing. Returns None if the instance was modified after loading.

```python
data = yumly.load("config.yumly")

# immediately after loading — returns the cached representation
print(data.original_yumyumy())

# after any mutation — returns None
data["new_key"] = "new_value"
print(data.original_yumyumy())  # None
```

> ⟡ This is useful when you load a file and want to display its internal representation without calling `to_yumyumy()` again, which would require re-serializing the dict from scratch.

---

## ✿ Validation

Validate content or files without loading them:

```python
is_valid = yumly.validate_content('(app) { name = "test" }')
print(f"Valid: {is_valid}")  # True
```

```python
is_valid = yumly.validate_file("config.yumly")
print(f"File valid: {is_valid}")
```

---

## ✿ Serialization

Convert Python dictionaries to Yumly format:

```python
data = {
    "name": "Yumly",
    "version": "1.0.0",
    "active": True,
    "port": 8080
}
content = yumly.dumps(data)
print(content)
```

Write directly to a file:

```python
with open("config.yumly", "w") as file:
    yumly.dump(data, file)
```

### ✿ To Yumyumy ♡ (Serialization 2.0 in python context)

Convert a dictionary to the internal Yumyumy string representation (useful for tests or visualization):

```python
yumyumy_str = yumly.to_yumyumy(data)
print(yumyumy_str)
```

> ⟡ When possible, Yumly reuses the cached representation stored inside YumlyData. 

---

## ✿ Error Handling

All errors are raised as `YumlyError`:

```python
from yumly import Yumly, YumlyError

yumly = Yumly()
try:
    yumly.load("invalid.yumly")
except YumlyError as e:
    print(f"Yumly error: {e.message}")
```

---

## ✿ Real-World Example: Task Manager

A complete example using `dataclasses` with Yumly to manage tasks:

```python
from yumly import Yumly, YumlyError
from dataclasses import dataclass, asdict

@dataclass
class Task:
    name: str
    description: str
    completed: bool = False

class TaskManager():
    def __init__(self):
        self.yumly = Yumly()
        self.tasks: dict[str, Task] = self.load_index()

    def load_index(self) -> dict[str, Task]:
        try:
            raw: dict[str, dict] = self.yumly.load("tasks.yumly")
            return {name: Task(**task_data) for name, task_data in raw.items()}
        except YumlyError:
            return {}

    def save_index(self) -> None:
        data = {name: asdict(task) for name, task in self.tasks.items()}
        with open("tasks.yumly", "w") as file:
            self.yumly.dump(data, file)

    def add_task(self, task: Task) -> bool:
        if task.name in self.tasks:
            return False
        self.tasks[task.name] = task
        self.save_index()
        return True

    def complete_task(self, name: str) -> bool:
        if name not in self.tasks:
            return False
        self.tasks[name].completed = True
        self.save_index()
        return True
```

> ⟡ — now, i'll never forget to feed my fish! (˶>⩊<˶)

---

## ✿ Partial Parsing (Pipeline Stages)

Yumly allows you to stop the parsing process at different stages. This is useful for debugging or if you only need tokens/AST.

```python
from yumly import Yumly, PipelineStage

yumly = Yumly()

# Stop at Tokenizer (returns list of Tokens)
tokens = yumly.load_until("config.yumly", PipelineStage.Tokenizer)

# Stop at Parser (returns YumNode AST)
ast = yumly.load_until("config.yumly", PipelineStage.Parser)

# Stop at Load_Includes — resolves include { } directives and .env files,
# but does not yet validate types or evaluate values (returns YumNode AST)
ast_with_includes = yumly.load_until("config.yumly", PipelineStage.Load_Includes)

# Stop at Resolver (returns YumNode AST)
ast = yumly.load_until("config.yumly", PipelineStage.Resolver)

# Stop at Validator (returns YumNode AST)
ast = yumly.load_until("config.yumly", PipelineStage.Validator)

# Full pipeline — default used by load() (returns YumlyData)
data = yumly.load_until("config.yumly", PipelineStage.Evaluator)

# Valid stages:
# PipelineStage.Tokenizer
# PipelineStage.Parser
# PipelineStage.Load_Includes
# PipelineStage.Resolver
# PipelineStage.Validator
# PipelineStage.Evaluator -> default used by load()
```

## ✿ API Reference (for you never forget ;3)

| Method | Description |
|--------|-------------|
| `load(path)` | Load and parse a `.yumly` or `.yuy` file — returns `YumlyData` |
| `load_until(path, stage)` | Load up to a specific pipeline stage |
| `loads(content)` | Parse Yumly content from a string — returns `YumlyData` |
| `loads_until(content, stage)` | Parse up to a specific pipeline stage |
| `to_yumyumy(data)` | Convert dict or `YumlyData` to Yumyumy string |
| `dump(data, stream)` | Serialize dict to a file-like stream |
| `dumps(data)` | Serialize dict to a Yumly string |
| `validate_content(content)` | Check if content is valid Yumly |
| `validate_file(path)` | Check if file is valid Yumly |

### ✿ YumlyData

| Method / Property | Description |
|-------------------|-------------|
| `original_yumyumy()` | Returns the cached Yumyumy ♡ string if the instance was not mutated, `None` otherwise |

---

#### Oh! — you reached at the end!! congratulations!! here's a gift for you: ⸜( ˶' ᵕ '˶ )⸝
```text
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⡤⠤⠤⠤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠞⠋⠁⠀⠀⠀⠀⠀⠀⠀⠉⠛⢦⣤⠶⠦⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⣴⠞⢋⡽⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠃⠀⠀⠙⢶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣰⠟⠁⠀⠘⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡀⠀⠀⠉⠓⠦⣤⣤⣤⣤⣤⣤⣄⣀⠀⠀⠀
⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣷⡄⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣆⠀
⠀⠀⣠⠞⠁⠀⠀⣀⣠⣏⡀⠀⢠⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠿⡃⠀⠀⠀⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⡆
⢀⡞⠁⠀⣠⠶⠛⠉⠉⠉⠙⢦⡸⣿⡿⠀⠀⠀⡄⢀⣀⣀⡶⠀⠀⠀⢀⡄⣀⠀⣢⠟⢦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃
⡞⠀⠀⠸⠁⠀⠀⠀⠀⠀⠀⠀⢳⢀⣠⠀⠀⠀⠉⠉⠀⠀⣀⠀⠀⠀⢀⣠⡴⠞⠁⠀⠀⠈⠓⠦⣄⣀⠀⠀⠀⠀⣀⣤⠞⠁⠀
⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠀⠁⠀⢀⣀⣀⡴⠋⢻⡉⠙⠾⡟⢿⣅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠙⠛⠉⠉⠀⠀⠀⠀
⠘⣦⡀⠀⠀⠀⠀⠀⠀⣀⣤⠞⢉⣹⣯⣍⣿⠉⠟⠀⠀⣸⠳⣄⡀⠀⠀⠙⢧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠈⠙⠒⠒⠒⠒⠚⠋⠁⠀⡴⠋⢀⡀⢠⡇⠀⠀⠀⠀⠃⠀⠀⠀⠀⠀⢀⡾⠋⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⢸⡀⠸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⢠⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣇⠀⠀⠉⠋⠻⣄⠀⠀⠀⠀⠀⣀⣠⣴⠞⠋⠳⠶⠞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⠦⢤⠤⠶⠋⠙⠳⣆⣀⣈⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
```