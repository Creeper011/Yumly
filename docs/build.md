# ⋆˚.♪ Building Yumly ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

Nimble is my official local build interface. All generated files belong under
`build/`, so the source tree stays cute and `nimble clean` can remove the whole
lot safely!! ദ്ദി •⩊• )

## ✿ Commands

Keep Nimble's package cache inside the project build directory:

```bash
export NIMBLE_DIR="$PWD/build/nimble"
```

Equivalently, pass `--nimbleDir:build/nimble` to an individual command.

| Command | Output |
|---------|--------|
| `nimble buildCli` | `build/bin/yumly-cli` |
| `nimble buildNim` | `build/lib/nim/libyumly` with the platform library suffix |
| `nimble buildC` | C ABI library under `build/lib/c/` (public header: `include/yumly.h`) |
| `nimble buildPython` | Python extension under `build/lib/python/yumly/` |
| `nimble buildTools` | Repository utilities under `build/tools/` |
| `nimble checkSources` | Compiler caches under `build/nimcache/` |
| `nimble packagePython` | Python sdist and wheel under `build/packages/` |
| `nimble clean` | Removes `build/` |

The Python build continues to use `pyproject.toml` as its packaging contract.
Its setuptools hook delegates native compilation to `buildPython`, then copies
that artifact into the wheel. Likewise, `nix build` uses the same `buildCli`
task with dependency paths supplied by Nix.

Build environments that need extra compiler arguments can set
`YUMLY_NIM_FLAGS`. For example:

```bash
YUMLY_NIM_FLAGS="--cc:clang" nimble buildCli
```
