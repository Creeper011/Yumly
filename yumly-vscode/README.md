# Yumly VS Code Extension

Support for `.yumly` and `.yuy` files highlight syntax

## Features
- Syntax highlighting for `(name) { ... }` blocks, `key ;type = value` pairs, and `"> ... <"` comments.
- Value highlighting: single and double quoted strings, numbers, booleans, and environment variables `$["VAR"]`.
- Auto-closing for `{ }`, `[ ]`, `( )`, quotes, and comment delimiters `"> <"`.

## Installation
1. Generate extension: `npx --yes @vscode/vsce package`
1. Install extension : `code --install-extension yumly.vsix`.

## Licence
MIT.
