import ./display

type
  CliErrorCode* = enum
    ceUnknownHelpTopic
    ceUnknownCommand
    ceMissingInput
    ceOptionCommandMismatch
    ceMissingStage
    ceUnknownStage
    ceUnknownOption
    ceFormatDisabled

template cliMessage*(cuteMessage, plainMessage: string): string =
  when defined(yumlycliCute):
    cuteMessage
  else:
    plainMessage

func `$`*(code: CliErrorCode): string =
  case code
  of ceUnknownHelpTopic: "yumly-cli.unknown-help-topic"
  of ceUnknownCommand: "yumly-cli.unknown-command"
  of ceMissingInput: "yumly-cli.missing-input"
  of ceOptionCommandMismatch: "yumly-cli.option-command-mismatch"
  of ceMissingStage: "yumly-cli.missing-stage"
  of ceUnknownStage: "yumly-cli.unknown-stage"
  of ceUnknownOption: "yumly-cli.unknown-option"
  of ceFormatDisabled: "yumly-cli.format-disabled"

proc cliError*(message: string, code: CliErrorCode) =
  error(message & "\n  code: " & $code)
