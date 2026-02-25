import unittest
import std/options
import ../src/Yumly/tokenizer
import ../src/Yumly/parser
import ../src/Yumly/types/ast

suite "Yumly AST Logic":
  test "Basic block and pair parsing":
    let code = """(project) { name = "Orion", version = 1 }"""
    let tokens = tokenize(code)
    let ast = generateAST(tokens)
    
    check ast.kind == nkConfig
    check ast.children.len == 1
    
    let blk = ast.children[0]
    check blk.kind == nkBlock
    check blk.name == "project"
    check blk.children.len == 2
    
    let pair1 = blk.children[0]
    check pair1.kind == nkPair
    check pair1.key == "name"
    check pair1.valNode.kind == nkString
    check pair1.valNode.rawValue == "Orion"

  test "Type hints parsing":
    let code = "(data) { count ;int = 10, pi ;float = 3.14 }"
    let tokens = tokenize(code)
    let ast = generateAST(tokens)
    
    let blk = ast.children[0]
    let pair1 = blk.children[0]
    check pair1.key == "count"
    check pair1.typeHint.isSome
    check pair1.typeHint.get().kind == thInt

  test "Environment variables and lists":
    let code = """(env) { db_pass = $["DB_PWD"], tags = ["a", "b"] }"""
    let tokens = tokenize(code)
    let ast = generateAST(tokens)
    
    let blk = ast.children[0]
    let pair1 = blk.children[0]
    check pair1.valNode.kind == nkEnv
    check pair1.valNode.rawValue == "DB_PWD"
    
    let pair2 = blk.children[1]
    check pair2.valNode.kind == nkList
    check pair2.valNode.children.len == 2
