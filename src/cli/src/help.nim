const
  generalHelp* = """⋆˚.♪ Yummie CLI ♪.˚⋆

Hey!! what do you want me to do? :3

Usage:
  yumly-cli <command> <file|content> [options]

Commands:
  load    Load and show your config
  check   Make sure everything behaves
  help    Show help for a command

Run `yumly-cli help load` or `yumly-cli help check` for more ;3
"""

  loadHelp* = """⋆˚.♪ Yummie CLI — load ♪.˚⋆

Load and show your config

Usage:
  yumly-cli load <file|content> [options]

Options:
  -u, --until <stage>  Stop at T, P, LI, R, E, or V
  (tokenizer, parser, load includes, resolver, evaluator, validator)
  -yu, --yumly         Output Yumly
  -j,  --json          Output JSON
  -ya, --yaml          Output YAML
      --no-output      Load without rendering the result
  -q,  --quiet         Load without output or success messages
  -h,  --help          Show this help
"""

  checkHelp* = """⋆˚.♪ Yummie CLI — check ♪.˚⋆

Make sure your config behaves! >:3

Usage:
  yumly-cli check <file|content>
"""

proc printHelp*(command = "") =
  case command
  of "load": echo loadHelp
  of "check": echo checkHelp
  else: echo generalHelp
