import streams, ../src/Yumly/phases/[tokenizer, parser], ../src/Yumly/types/nodes
var p = newParser(tokenize(newStringStream("is_production ;bool = false")))
let res = p.parse().children[0]
echo res.key, " is ", res.valNode.rawValue
