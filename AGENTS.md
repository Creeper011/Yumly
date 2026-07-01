# Working on Yumly

Yumly is currently undergoing a deep redesign. Nobody depends on the project
yet, so backward compatibility is not a goal unless Yumene explicitly says
otherwise.

## Read the documentation first

Before proposing or making changes, read the relevant files under `docs/`.
The documentation records the intended identity, syntax, semantics, public
APIs, and auxiliary formats of Yumly. Do not treat it as disposable merely
because the implementation is being rewritten.

In particular:

- `docs/gramatic/overview.md` describes the language and its behavior.
- `docs/ebnf/grammar.ebnf` is the formal grammar.
- `docs/usage/` describes the intended Nim, Python, and CLI interfaces.
- `docs/yumyumy.md` and `docs/ebnf/yumyumy.ebnf` describe Yumyumy.
- `docs/ylwa.md` and `docs/ebnf/ylwa.ebnf` describe Ylwa.
- `docs/tests.md` describes the old test system and may be replaced with it.

Documentation is an expression of design intent, but it may lag behind an
active redesign. If documentation, examples, tests, and source code disagree,
do not silently choose one. Show the contradiction to Yumene and ask which
behavior belongs in the redesigned language.

Public documentation should state decided behavior, not narrate unresolved
design work. Keep undecided or knowingly incomplete ideas implicit, or record
them only in non-normative comments until Yumene settles the design.

## Source and tests are being redesigned

Do not assume the current `src/` architecture is a constraint. Large internal
changes, removals, and clean replacements are acceptable when they make the
new design clearer.

Do not use the legacy test suite as the source of truth. Preserve or migrate an
old case only when it still represents intended behavior. New tests should be
derived from the chosen language design and its documentation.

When changing syntax or semantics, keep the relevant documentation,
implementation, examples, and new tests consistent in the same change whenever
practical.

## Work with the maintainer

Yumly is a personal project with a deliberate voice and aesthetic. Preserve
that identity in user-facing documentation and messages instead of replacing
it with generic corporate prose.

Do not infer architectural policy from a representation decision. State
observable representation separately from any inferred policy, and ask Yumene
before treating such an inference as design intent or implementing work based
on it.

In the documentation, first-person `I`, `me`, and `my` refer to Yumly/Yummie
herself: the language is also a persona of Yumene. Do not reinterpret that voice
as an accidental maintainer aside, and do not rewrite it into impersonal prose.

Ask Yumene about genuine design decisions. Do not ask for confirmation about
ordinary implementation details that follow clearly from an established
decision.

The worktree may contain ongoing experiments. Inspect `git status` before
editing, preserve unrelated changes, and never discard work just to obtain a
clean baseline.
