import ../../src/Yumly/tokenizer
import ../../src/Yumly/types/token

const source = """
include { .env }

(global) {
  project_name ;string = $["PROJECT_NAME"],
  version ;string = $["VERSION"],
  is_production ;bool = false,
  max_retries ;int = 5,
  pi_precision = 3.14159265,
  uptime_goal = 9.99e12,

  (metadata) {
    tags ;list[string] = ["cloud", "high-availability", "scalable"],
    region_info ;tuple = ["us-east-1", 101, true],
    owner_id = 12345
  }
}
"""

proc T(kind: TokenKind, value: string = "", line: int = 0, col: int = 0): Token =
  case kind
  of tkIdent, tkString, tkLiteral:
    Token(kind: kind, value: value, line: line, col: col)
  else:
    Token(kind: kind, line: line, col: col)

const expected = @[
  T(tkInclude, line = 1, col = 8),
  T(tkLBrace, line = 1, col = 9),
  T(tkIdent, ".env", 1, 15),
  T(tkRBrace, line = 1, col = 16),

  T(tkLParen, line = 3, col = 1),
  T(tkIdent, "global", 3, 8),
  T(tkRParen, line = 3, col = 8),
  T(tkLBrace, line = 3, col = 10),

  T(tkIdent, "project_name", 4, 15),
  T(tkDeclaration, line = 4, col = 16),
  T(tkIdent, "string", 4, 23),
  T(tkEquals, line = 4, col = 24),
  T(tkDollar, line = 4, col = 26),
  T(tkLBracket, line = 4, col = 27),
  T(tkString, "PROJECT_NAME", 4, 41),
  T(tkRBracket, line = 4, col = 42),
  T(tkComma, line = 4, col = 43),

  T(tkIdent, "version", 5, 10),
  T(tkDeclaration, line = 5, col = 11),
  T(tkIdent, "string", 5, 18),
  T(tkEquals, line = 5, col = 19),
  T(tkDollar, line = 5, col = 21),
  T(tkLBracket, line = 5, col = 22),
  T(tkString, "VERSION", 5, 31),
  T(tkRBracket, line = 5, col = 32),
  T(tkComma, line = 5, col = 33),

  T(tkIdent, "is_production", 6, 16),
  T(tkDeclaration, line = 6, col = 17),
  T(tkIdent, "bool", 6, 22),
  T(tkEquals, line = 6, col = 23),
  T(tkLiteral, "false", 6, 30),
  T(tkComma, line = 6, col = 30),

  T(tkIdent, "max_retries", 7, 14),
  T(tkDeclaration, line = 7, col = 15),
  T(tkIdent, "int", 7, 19),
  T(tkEquals, line = 7, col = 20),
  T(tkLiteral, "5", 7, 23),
  T(tkComma, line = 7, col = 23),

  T(tkIdent, "pi_precision", 8, 15),
  T(tkEquals, line = 8, col = 16),
  T(tkLiteral, "3.14159265", 8, 28),
  T(tkComma, line = 8, col = 28),

  T(tkIdent, "uptime_goal", 9, 14),
  T(tkEquals, line = 9, col = 15),
  T(tkLiteral, "9.99e12", 9, 24),
  T(tkComma, line = 9, col = 24),

  T(tkLParen, line = 11, col = 3),
  T(tkIdent, "metadata", 11, 12),
  T(tkRParen, line = 11, col = 12),
  T(tkLBrace, line = 11, col = 14),

  T(tkIdent, "tags", 12, 9),
  T(tkDeclaration, line = 12, col = 10),
  T(tkIdent, "list", 12, 15),
  T(tkLBracket, line = 12, col = 15),
  T(tkIdent, "string", 12, 22),
  T(tkRBracket, line = 12, col = 22),
  T(tkEquals, line = 12, col = 24),
  T(tkLBracket, line = 12, col = 26),
  T(tkString, "cloud", 12, 33),
  T(tkComma, line = 12, col = 34),
  T(tkString, "high-availability", 12, 54),
  T(tkComma, line = 12, col = 55),
  T(tkString, "scalable", 12, 66),
  T(tkRBracket, line = 12, col = 67),
  T(tkComma, line = 12, col = 68),

  T(tkIdent, "region_info", 13, 16),
  T(tkDeclaration, line = 13, col = 17),
  T(tkIdent, "tuple", 13, 23),
  T(tkEquals, line = 13, col = 24),
  T(tkLBracket, line = 13, col = 26),
  T(tkString, "us-east-1", 13, 37),
  T(tkComma, line = 13, col = 38),
  T(tkLiteral, "101", 13, 43),
  T(tkComma, line = 13, col = 43),
  T(tkLiteral, "true", 13, 49),
  T(tkRBracket, line = 13, col = 49),
  T(tkComma, line = 13, col = 50),

  T(tkIdent, "owner_id", 14, 13),
  T(tkEquals, line = 14, col = 14),
  T(tkLiteral, "12345", 14, 21),

  T(tkRBrace, line = 15, col = 3),
  T(tkRBrace, line = 16, col = 1),

  T(tkEOF, line = 17, col = 1)
]

proc runTokenizerTest() =
  let tokens = tokenize(source)
  echo "--- TOKENIZER OUTPUT ---"
  for token in tokens:
    echo token
  echo "------------------------"
  echo "--- EXPECTED OUTPUT ---"
  for token in expected:
    echo token
  echo "------------------------"
  assert tokens.len == expected.len

  for i in 0 ..< tokens.len:
    assert tokens[i].kind == expected[i].kind

    if tokens[i].kind in {tkIdent, tkString, tkLiteral}:
      assert tokens[i].value == expected[i].value

    assert tokens[i].line > 0
    assert tokens[i].col > 0

    assert tokens[i].line == expected[i].line
    assert tokens[i].col == expected[i].col

    echo "Token " & $i & " is correct"

runTokenizerTest()