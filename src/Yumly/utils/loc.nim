
template loc*(line, col: int): string =
  " (line " & $line & ", column " & $col & ")"