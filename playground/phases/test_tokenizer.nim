##
# Playground for testing the tokenizer
##
import ../../src/Yumly/phases/tokenizer
import ../../src/Yumly/types/token
import std/streams

const q = "\"\"\""
const fileContent = """
include { "example.yumly" }

name ;string = "John Doe", fullName ;string = "John Doe 67!",
age ;int = 30
hobbies ;list[string] = ["reading", "hiking", "cooking"]

;> an commentary <;
;>
multiple line
commentary
<;

multiline_string ;string = """ & q & """
Hello, this is a multiline string.
It can contain "quotes" and backslashes \\.
It can also contain newlines.
""" & q & """

(block1) {
    variable1 ;string = "value",
    variable2 ;int = 1,
    variable3 ;list[int] = [1, 2, 3, 4, 5],
    variable4 ;list[string] = ["one", "two", "three", "four", "five"],
    variable5 = [1, "two", 3.3, "four", ["five"]],
    variable6 ;string = "string with a \"quote\" inside and a \\ backslash inside"
}
"""

let nextToken = tokenize(newStringStream(fileContent))
while true:
  let token = nextToken()
  echo token
  if token.kind == tkEOF:
    break