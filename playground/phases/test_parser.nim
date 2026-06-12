import streams, ../../src/Yumly/phases/tokenizer/tokenizer, ../../src/Yumly/phases/parser/parser, ../../src/Yumly/types/nodes
var p = newParser(tokenize(newStringStream("name ;string = \"Hello\", age ;int = 20, hobbies ;list[string] = [\"reading\", \"hiking\", \"cooking\"]")))
for pair in p.parse().children:
  if pair.kind == nkPair:
    let val = pair.valNode
    if val.kind == nkLiteral:
      echo pair.key, " is ", val.rawValue
    else:
      echo pair.key, " have type ", val.kind
