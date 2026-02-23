# Yumly
WARNING: MVP (sujeito a mudanças).

Yumly é uma linguagem de configuração opcionalmente declarativa (type safety), misturando elementos de YAML e JSON.

O parser de Yumly é escrito em [Nim](https://nim-lang.org/) e também pode ser usado em [Python](https://www.python.org/) via [NimPy](https://github.com/yglukhov/nimpy).

Yumly tem suporte nativo a variáveis de ambiente, centralizando cenários em que é preciso carregar env junto de outra linguagem.

Para ajudar no crescimento da linguagem, existem testes/exemplos (WIP) que mostram funcionamento, sintaxe e casos de uso.

Nim é uma linguagem compilada, isto é, gera um binário. Por isso o parser é um executável que você pode chamar diretamente.

## Python Lib:

- Para importar um código .yumly em python, basta:
```python
from yumly import Yumly

data = Yumly().load("example.yumly")
print(data) # só imprime o valor
```

## Sintaxe
- Você pode ver isso em examples/