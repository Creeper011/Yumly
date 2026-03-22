# ✧*･ﾟ Yumly ･ﾟ*✧

> ⚠️ MVP — sujeito a mudanças. 

Yumly é uma linguagem de configuração declarativa com type safety opcional, misturando elementos de YAML e JSON — sem depender de indentação.

O parser é escrito em [Nim](https://nim-lang.org/) e exporta bindings para [Python](https://www.python.org/) via [NimPy](https://github.com/yglukhov/nimpy). Há também uma API Nim nativa para uso direto.

---

## ✿ O que tem Yumly?

- **Sem indentação** — blocos delimitados por `{ }` permitindo organização flexível
- **Type hints opcionais** — você pode declarar intenção ._.
- **Env vars nativas** — `$["VAR"]` e `include { .env }` de primeira classe ;)
- **Legível** — você lê de cima pra baixo e entende tudo ^_^ (human friendly)
- **Extensões** `.yumly` e `.yuy` (é mto fofo!!)

---

## ✿ Sintaxe

<details>
<summary>Comentários</summary>

```yumly
;> isso é um comentário <;

;>
comentário
de múltiplas linhas
<;
```

</details>

<details>
<summary>Pares chave-valor</summary>

```yumly
;> type hints são opcionais <;
name ;string = "Yumly"
version ;string = "1.0.0"
debug ;bool = true
port ;int = 8080
ratio ;float = 3.14

;> sem type hint, o tipo é inferido pelo valor <;
active = true
count = 42
```

</details>

<details>
<summary>Blocos</summary>

```yumly
(app) {
    name ;string = "Yumly",
    version ;string = "1.0.0",
    debug ;bool = false
}
```

Blocos podem ser aninhados:

```yumly
(database) {
    (postgres) {
        host = "localhost",
        port ;int = 5432
    },
    (redis) {
        host = "127.0.0.1",
        port = 6379
    }
}
```

</details>

<details>
<summary>Variáveis de ambiente</summary>

```yumly
token ;env = $["DISCORD_TOKEN"]
home  ;env = $["HOME"]
```

</details>

<details>
<summary>Include</summary>

```yumly
include { .env }           ;> carrega variáveis de ambiente <;
include { base.yumly }     ;> importa blocos de outro arquivo <;
include { shared.yuy }     ;> também aceita .yuy ou .yumly <;
```

</details>

<details>
<summary>Strings e Escapes</summary>

```yumly
newline = "Line 1\nLine 2"
tab = "Column 1\tColumn 2"
backslash = "C:\\Path\\Windows"
quotes = "He said: \"Hello!\""
```

</details>

<details>
<summary>Listas e Tuples</summary>

**Listas** — homogêneas, todos os itens do mesmo tipo:

```yumly
tags    ;list[string] = ["api", "v2", "stable"]
ports   ;list[int]    = [8080, 8081, 8082]

;> sem type hint, inferido pelo primeiro elemento <;
hosts = ["localhost", "0.0.0.0"]
```

Tipos válidos: `string`, `int`, `float`, `bool`, `env`.

**Tuples** — heterogêneas, tipos diferentes:

```yumly
server_info ;tuple = ["localhost", 8080, true]

;> inferido automaticamente se os tipos forem mistos <;
meta = ["staging", 42, false]
```

</details>

<details>
<summary>Regras de vírgula</summary>

Dentro de blocos, vírgulas separam pares e sub-blocos. O último item não precisa de vírgula:

```yumly
(block) {
    a = "x",
    b = "y",
    c = "z"    ;> última, sem vírgula <;
}
```

No root, pares na mesma linha precisam de vírgula:

```yumly
name = "John", age = 30
job = "dev"
```

</details>

### Exemplo completo

```yumly
include { .env }

(global) {
    project ;string = "Orion",
    version ;string = "2.0.0",
    production ;bool = false,
    tags ;list[string] = ["cloud", "scalable"]
}

(database) {
    host = "localhost",
    port ;int = 5432,
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

## ✿ Tipos disponíveis

| Type hint    | Exemplo                                      |
|--------------|----------------------------------------------|
| `;string`    | `name ;string = "Yumly"`                    |
| `;int`       | `port ;int = 8080`                           |
| `;float`     | `ratio ;float = 3.14`                        |
| `;bool`      | `debug ;bool = true`                         |
| `;env`       | `token ;env = $["TOKEN"]`                   |
| `;list[T]`   | `tags ;list[string] = ["a", "b"]`           |
| `;tuple`     | `info ;tuple = ["host", 8080, true]`        |

---

## ✿ Python

### ✦ Instalação

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
make deps   # instala dependências Nim
pip install . # ou caminho para o repositório Yumly
```

### ✦ Uso

```python
from yumly import Yumly
from typing import Any

PORT = 6767

yumly = Yumly()

data: dict[str, Any] = yumly.load("config.yumly")
print(data["global"]["project"])   # "Orion"
print(data["database"]["port"])    # 5432

data_to_write: dict[str, str] = {
    "port": PORT,
    "uri": "127.0.0.1", 
}
with open("config2.yumly", "w") as file:
    yumly.dump(data_to_write, file)

# or:
content: str = yumly.dumps(data_to_write)
print(content)

result: bool = yumly.validate_content(content)
print(f"Content validation result: {result}")

file_result: bool = yumly.validate_file("config2.yumly")
print(f"File validation result: {file_result}")

```

---

## ✿ Nim

### ✦ Instalação

```bash
git clone https://github.com/Creeper011/Yumly
cd Yumly/
nimble install --path:.
```

### ✦ Uso básico

```nim
import Yumly

let config = loadYumly("config.yumly")

echo config["global"]["project"].getStr()
echo config.getBlock("database")["port"].getInt()
```

<details>
<summary>Iteração</summary>

```nim
for blk in config:
    echo blk.name
    for key, val in blk:
        echo key & " = " & val.getStr()
```

</details>

<details>
<summary>Mapeamento para objetos com macro <code>to</code></summary>

```nim
type
    App = object
        project: string
        version: string
        production: bool

let app = config.getBlock("global").to(App)
echo app.project   # "Orion"
```

</details>

<details>
<summary>Escrita de arquivos</summary>

```nim
var cfg = newYumly()
cfg.addPair("name", newStringValue("Orion"), "string")

var db = newBlock("database")
db.addPair("host", newStringValue("localhost"))
db.addPair("port", newIntValue(5432), "int")
cfg.addBlock(db)

cfg.writeYumly("output.yumly")
```

</details>

---

## ✿ CLI

```bash
yumly_cli check config.yumly
yumly_cli load config.yumly
```

---

## ✿ Extensão VSCode

```bash
cd yumly-vscode
npx --yes @vscode/vsce package
code --install-extension yumly.vsix
```

---

## ✿ Testes

```bash
python tests/run_tests.py
nim c -r tests/test_encoder.nim
```

---

## ✿ Sobre Projetos (Testes)

- Yumly possui um conjunto de projetos PoC (Proof of Concepts) que visam testar implementações de yumly de forma mais integrada ao um cenário real; podem ser encontrados em [tests/projects](./tests/projects/).

---

## ★ Licença ★

MIT — veja [LICENSE](LICENSE).