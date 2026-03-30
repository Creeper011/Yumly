import ../../src/Yumly/tokenizer
import ../../src/Yumly/types/token

const 
  q = "\"\"\""
  source = """
include { ".env" }

(global) {
  project_name ;string = $["PROJECT_NAME"],
  description ;string = "An \"test\" project\nwith multiples features",
  detailedDescription ;string = """ & q & """
  \tAn \"test\" project\nwith multiples features
  Its amazing, you can do very things with this project
  """ & q & """,
  version ;string = $["VERSION"],
  is_production ;bool = false,
  max_retries ;int = 5,
  pi_precision = 3.14159265,
  uptime_goal = 1.5e+3,

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
  T(tkInclude, line = 1, col = 1),
  T(tkLBrace, line = 1, col = 9),
  T(tkString, ".env", 1, 11),
  T(tkRBrace, line = 1, col = 18),

  T(tkLParen, line = 3, col = 1),
  T(tkIdent, "global", 3, 2),
  T(tkRParen, line = 3, col = 8),
  T(tkLBrace, line = 3, col = 10),

  # project_name
  T(tkIdent, "project_name", 4, 3),
  T(tkDeclaration, line = 4, col = 16),
  T(tkIdent, "string", 4, 17),
  T(tkEquals, line = 4, col = 24),
  T(tkDollar, line = 4, col = 26),
  T(tkLBracket, line = 4, col = 27),
  T(tkString, "PROJECT_NAME", 4, 28),
  T(tkRBracket, line = 4, col = 42),
  T(tkComma, line = 4, col = 43),

  # description
  T(tkIdent, "description", 5, 3),
  T(tkDeclaration, line = 5, col = 15),
  T(tkIdent, "string", 5, 16),
  T(tkEquals, line = 5, col = 23),
  T(tkString, "An \\\"test\\\" project\\nwith multiples features", 5, 25),
  T(tkComma, line = 5, col = 71),

  # detailedDescription
  T(tkIdent, "detailedDescription", 6, 3),
  T(tkDeclaration, line = 6, col = 23),
  T(tkIdent, "string", 6, 24),
  T(tkEquals, line = 6, col = 31),
  T(tkString, "  \\tAn \\\"test\\\" project\\nwith multiples features\n  Its amazing, you can do very things with this project\n  ", 6, 33),
  T(tkComma, line = 8, col = 6),

  # version
  T(tkIdent, "version", 9, 3),
  T(tkDeclaration, line = 9, col = 11),
  T(tkIdent, "string", 9, 12),
  T(tkEquals, line = 9, col = 19),
  T(tkDollar, line = 9, col = 21),
  T(tkLBracket, line = 9, col = 22),
  T(tkString, "VERSION", 9, 23),
  T(tkRBracket, line = 9, col = 32),
  T(tkComma, line = 9, col = 33),

  T(tkIdent, "is_production", 10, 3),
  T(tkDeclaration, line = 10, col = 17),
  T(tkIdent, "bool", 10, 18),
  T(tkEquals, line = 10, col = 23),
  T(tkLiteral, "false", 10, 25),
  T(tkComma, line = 10, col = 30),

  T(tkIdent, "max_retries", 11, 3),
  T(tkDeclaration, line = 11, col = 15),
  T(tkIdent, "int", 11, 16),
  T(tkEquals, line = 11, col = 20),
  T(tkLiteral, "5", 11, 22),
  T(tkComma, line = 11, col = 23),

  T(tkIdent, "pi_precision", 12, 3),
  T(tkEquals, line = 12, col = 16),
  T(tkLiteral, "3.14159265", 12, 18),
  T(tkComma, line = 12, col = 28),

  T(tkIdent, "uptime_goal", 13, 3),
  T(tkEquals, line = 13, col = 15),
  T(tkLiteral, "1.5e+3", 13, 17),
  T(tkComma, line = 13, col = 23),

  # metadata
  T(tkLParen, line = 15, col = 3),
  T(tkIdent, "metadata", 15, 4),
  T(tkRParen, line = 15, col = 12),
  T(tkLBrace, line = 15, col = 14),

  T(tkIdent, "tags", 16, 5),
  T(tkDeclaration, line = 16, col = 10),
  T(tkIdent, "list", 16, 11),
  T(tkLBracket, line = 16, col = 15),
  T(tkIdent, "string", 16, 16),
  T(tkRBracket, line = 16, col = 22),
  T(tkEquals, line = 16, col = 24),
  T(tkLBracket, line = 16, col = 26),
  T(tkString, "cloud", 16, 27),
  T(tkComma, line = 16, col = 34),
  T(tkString, "high-availability", 16, 36),
  T(tkComma, line = 16, col = 55),
  T(tkString, "scalable", 16, 57),
  T(tkRBracket, line = 16, col = 67),
  T(tkComma, line = 16, col = 68),

  T(tkIdent, "region_info", 17, 5),
  T(tkDeclaration, line = 17, col = 17),
  T(tkIdent, "tuple", 17, 18),
  T(tkEquals, line = 17, col = 24),
  T(tkLBracket, line = 17, col = 26),
  T(tkString, "us-east-1", 17, 27),
  T(tkComma, line = 17, col = 38),
  T(tkLiteral, "101", 17, 40),
  T(tkComma, line = 17, col = 43),
  T(tkLiteral, "true", 17, 45),
  T(tkRBracket, line = 17, col = 49),
  T(tkComma, line = 17, col = 50),

  T(tkIdent, "owner_id", 18, 5),
  T(tkEquals, line = 18, col = 14),
  T(tkLiteral, "12345", 18, 16),

  T(tkRBrace, line = 19, col = 3),
  T(tkRBrace, line = 20, col = 1),

  T(tkEOF, line = 21, col = 1)
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