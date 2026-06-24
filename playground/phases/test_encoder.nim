import ../../src/Yumly/types/ast
import ../../src/Yumly/core/builders
import ../../src/Yumly/serializers/yumly/encoder

var cfg = newYumly()
cfg.pairs.add(Pair(key: "hello", value: Value(kind: vkString,
    strVal: "\t\"world\nhello\"")))
var blk = newBlock("test")
blk.pairs.add(Pair(key: "test", value: Value(kind: vkString, strVal: "test")))
cfg.blocks.add(blk)
cfg.includes.add(Include(includePath: "test"))

let encoded = dumpYumly(cfg)

echo encoded
