import ../types/source

template loc*(line, col: SourcePos): string =
  " (line " & $line & ", column " & $col & ")"
