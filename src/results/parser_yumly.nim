import ../tokenizer, ../parser, ../additional/validate
import ../types/ast
import ../yumly_file

proc parseConfig*(path: string): string =
  checkFileExtension(path)
  let content = openFileContent(path)
  let tokens  = tokenize(content)
  var config  = generateAST(tokens)
  validateConfig(config)
  $config