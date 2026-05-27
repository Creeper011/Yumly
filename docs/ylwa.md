# About the Ylwa (wa wa wa) Format
⊹˚. ♡.𖥔 ݁ ˖

Ylwa is Yumly's internal cutesy format, used specifically for structured logging and benchmark results.

## ✿ Why Ylwa?
- Because it maintains the aesthetic of the project.
- It's cute, obviously ˶> ̫ <˶
- I wanted to create another format to avoid the "others format" lol.

## ✿ Formal Specification
For the formal grammar, see the [Ylwa EBNF Specification](ebnf/ylwa.ebnf).

## ✿ Syntax at a Glance

| Element | Syntax | Description |
|---------|--------|-------------|
| Header  | `.> Title <.` | Top-level section title |
| Comment | `.> ... .<` | Multiline comment block |
| Block   | `~ Name : ... :` | A named container for data |
| Field   | `- Key ; Value,` | A key-value pair (Value is always a string) |

There's no type system, every value is a string.

## ✿ Example

```ylwa
.> Ylwa Representative Language Example <.

.> 
  This language is not a config language;
  it is a representative language for benchmarking yumly.
.<

~ Benchmark :
 - File ; examples/example2.yumly,
 - Phase ; tokenize,
 - Time ; 0.00008738199999999696s,
 - Peak RAM ; 0.038787841796875MB,
 - Heap Memory Allocated ; 0.0174713134765625MB,
 - Object Memory Allocated ; 0.0174713134765625MB,
:
```

---
#### wonderhoyy! ⸜( ˶' ᵕ '˶ )⸝
