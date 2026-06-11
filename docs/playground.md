# 🛝 The Playground ✨
⊹˚. ♡.𖥔 ݁ ˖

Welcome to the **Playground**!! — a cool space for you to explore, break things, and experiment with Yumly without any commitment. ⸜(｡˃ ᵕ ˂ )⸝♡

The `playground/` folder is where PoCs (Proof of Concepts) are born and where we test wild ideas before they become "serious" code.

## ✿ Interactive Learning 📓

### `Yumly.ipynb` 
Features:
- ⟡ Test the **Python bridge** interactively.
- ⟡ Visualize how Yumly translates to Python `dict`.
- ⟡ Prototype your configuration logic before writing a single script.

---

## ✿ Proof-of-Concepts (PoCs) 🚀

> ⟡ **Important:** Oh! a important thing! Since these projects use relative paths for their configuration files (like `config.yumly`), you **must** `cd` into their directory before running them!

### ☕ Cafe Menu (Nim)
A cute CLI app for a cafe. It uses Yumly to load its menu and settings.
- **Highlights:** `include { }` for organizing data and mapping blocks to objects.
- **Run it:** 
  ```sh
  cd playground/projects/cafeMenu && nim c -r cafe.nim
  ```

### 🖼️ GetWaifu CLI (Nim)
An waifu image downloader PoC that fetches images from the web using `waifu.im` API.
- **Highlights:** Shows how to use Yumly for app settings (NSFW flags, paths) and how to document your config with comments (`;> ... <;`) in `config.yumly`.
- **Run it:** 
  ```sh
  cd playground/projects/getWaifu && nim c -r waifuu.nim
  ```

### 📝 Task Manager (Python)
A simple task manager demonstrating Yumly's integration with Python.
- **Highlights:** Using `Yumly().dump()` to save your tasks back to a file.
- **Run it:** 
  ```sh
  cd playground/projects/tasks && python tasks.py
  ```

## ✿ Casual Debugging 🔬

Curious about how the data is made? The `playground/phases/` directory has standalone scripts to test individual pipeline stages:

- `test_tokenizer.nim`: Play with raw tokens.
- `test_parser.nim`: See the AST coming to life.
- `test_encoder.nim`: Explore how data gets serialized.

---

That's all! go ahead and explore, the playground is a casual fun place.

#### oh, a gift for your curiosity! ✧･ﾟ:
```text
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣎⠱⣲⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠤⠒⠒⠒⠒⠤⢄⣈⠈⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⡤⠒⠝⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⢄⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀⢠⣢⠐⡄⠀⠉⠑⠒⠒⠒⣄  yeah! ♡
⠀⠀⠀⣀⠴⠋⠀⠀⠀⡎⢀⣘⠿⠀⠀⢠⣀⢄⡦⠀⣛⣐⢸⠀⠀⠀⠀⠀⠀⢘
⡠⠒⠉⠀⠀⠀⠀⠀⡰⢅⠣⠤⠘⠀⠀⠀⠀⠀⠀⢀⣀⣤⡋⠙⠢⢄⣀⣀⡠⠊
⢇⠀⠀⠀⠀⠀⢀⠜⠁⠀⠉⡕⠒⠒⠒⠒⠒⠛⠉⠹⡄⣀⠘⡄⠀⠀⠀⠀⠀⠀
⠀⠑⠂⠤⠔⠒⠁⠀⠀⡎⠱⡃⠀⠀⡄⠀⠄⠀⠀⠠⠟⠉⡷⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠤⠤⠴⣄⡸⠤⣄⠴⠤⠴⠄⠼⠀⠀⠀⠀⠀⠀⠀⠀
```
