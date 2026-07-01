# ⋆˚.♪ C Usage ♪.˚⋆
⊹˚. ♡.𖥔 ݁ ˖

Helloo from C!! My C API exposes evaluated Yumly documents as a small,
read-only tree. The ABI uses opaque handles, status returns, output parameters,
and explicit ownership — no Nim objects leak into your structs. ദ്ദി •⩊• )

## ✿ Building

```sh
nimble --nimbleDir:build/nimble buildC
```

This writes the shared library under `build/lib/c/`. The public, C99-compatible
header is [`include/yumly.h`](../../include/yumly.h).
`YUMLY_ABI_VERSION` and `yumly_abi_version()` let consumers check that the
header and loaded shared library speak the same ABI revision.

```sh
cc app.c -Iinclude -Lbuild/lib/c -lyumly -o app
```

At runtime, make sure the platform loader can find the shared library. The
Yumagotchi Makefile demonstrates using an rpath for a repository-local build.

## ✿ Loading and errors

```c
#include <stdio.h>
#include <yumly.h>

int main(void) {
    yumly_document *document = NULL;
    yumly_error *error = NULL;

    yumly_status status =
        yumly_document_load_file("config.yumly", &document, &error);

    if (status != YUMLY_OK) {
        fprintf(stderr, "%s:%llu:%llu: %s: %s\n",
                yumly_error_path(error),
                (unsigned long long)yumly_error_line(error),
                (unsigned long long)yumly_error_column(error),
                yumly_error_code(error),
                yumly_error_message(error));
        yumly_error_free(error);
        return 1;
    }

    yumly_document_free(document);
    return 0;
}
```

`yumly_document_load_content()` performs the same work for resident source
text. Its `working_dir` argument controls where relative includes begin; pass
`NULL` to use `.`.

## ✿ Ownership

- A successful load returns an **owned** `yumly_document`. Free it exactly once
  with `yumly_document_free()`.
- A failed load may return an **owned** `yumly_error`. Its strings are borrowed
  from that error; free the handle with `yumly_error_free()`.
- `yumly_document_root()`, `yumly_object_get()`, and `yumly_list_get()` return
  **borrowed** values. They remain valid until their document is freed.
- `yumly_value_get_string()` returns borrowed, NUL-terminated text. Copy it if
  it needs to outlive the document.
- Every free function accepts `NULL`.

## ✿ Traversing values

Blocks and inline objects both appear as `YUMLY_OBJECT`, so the same lookup
function works naturally at every structural level:

```c
const yumly_value *root = yumly_document_root(document);
const yumly_value *server = NULL;
const yumly_value *port_value = NULL;
int64_t port = 0;

if (yumly_object_get(root, "server", &server) != YUMLY_OK ||
    yumly_object_get(server, "port", &port_value) != YUMLY_OK ||
    yumly_value_get_int(port_value, &port) != YUMLY_OK) {
    fputs("server.port must be an int\n", stderr);
}
```

Use `yumly_value_kind()` when the expected type is not already known.
`yumly_list_size()` and `yumly_list_get()` traverse lists without exposing
their representation.

## ✿ See it breathe

[`playground/projects/yumagotchi`](../../playground/projects/yumagotchi) is a
complete C application. It copies borrowed values into ordinary application
structs, frees the Yumly document, and then runs a terminal pet configured by
schemas, blocks, lists, and primitive values. ♡
