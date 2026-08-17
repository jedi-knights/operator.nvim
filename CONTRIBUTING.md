# Contributing to operator.nvim

Issues and pull requests are welcome. This document covers the local
development loop, what CI checks, and the conventions a PR is expected to
follow.

## Development loop

```bash
make check    # lint + test + smoke — run this before opening a PR
```

Individual targets:

| Target | What it does |
|---|---|
| `make test` | plenary-busted suite, headless |
| `make smoke` | end-to-end ship criterion: define an operator, fire it, press `.`, verify |
| `make lint` | `stylua --check .` |
| `make format` | `stylua .` — applies formatting |
| `make check` | `lint` + `test` + `smoke` |

`make lint` and `make format` require [StyLua](https://github.com/JohnnyMorganz/StyLua).
There is no `stylua.toml`; the repo uses StyLua's defaults, which means
**tab indentation**. Run `make format` rather than hand-aligning.

## What CI runs

CI runs on every pull request against `main`, as four jobs:

| Job | Runs |
|---|---|
| Lint | `make lint` |
| Tests | the [neospec](https://github.com/jedi-knights/neospec) action over `tests/*_spec.lua` |
| Smoke | `make smoke` |
| Validate | nothing — it gates on the other three passing |

The Tests job uses the neospec action rather than `make test` directly, so it
is not a literal `make check`. Running `make check` locally covers the same
ground: the same specs, the same lint, the same smoke.

## Tests

Specs live in `tests/` as `*_spec.lua` and use plenary's busted-style
`describe` / `it` / `before_each`.

Because the module keeps a registry and sets `operatorfunc`, tests must start
from a clean slate. Reset the module and the option in `before_each`:

```lua
before_each(function()
  package.loaded["operator"] = nil
  operator = require("operator")
  vim.go.operatorfunc = ""
end)
```

Test behavior through the public surface — `operator.define` plus a real
motion fed with `nvim_feedkeys` — rather than reaching into `_registry` or
`_pending_name`. Those are internal and are expected to change.

### The smoke test is not optional

`scripts/smoke.lua` is the only end-to-end proof that `.` repeat works, and it
exercises both the with- and without-vim-repeat paths. `.` repeat is this
plugin's headline behavior and is easy to break in ways unit tests do not
catch — the mechanism depends on `operatorfunc` *staying* set after the
callback runs, so a well-intentioned "restore the previous value" cleanup will
pass every spec and break the feature.

If you change anything in the dispatch path, run `make smoke` and say so in
the PR.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): description`
— lowercase, imperative, no trailing period.

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
`ci`, `chore`. A breaking change adds `!` after the type/scope and a
`BREAKING CHANGE:` footer.

```text
fix(dot-repeat): keep operatorfunc set so native `.` works
docs(readme): explain what a Vim operator is and why you'd want one
ci: run the ship-criterion smoke in check and CI
```

Explain *why* in the body, not just what. The diff already shows what changed.

## Pull requests

- **One concern per PR.** If the description needs an "and", it is two PRs.
- **Branch from an up-to-date `main`**, named after the change you intend to
  make.
- **Rebase before pushing** if `main` has moved under files you touched.
- **Run `make check`** and make sure it is green.
- PRs are squash-merged, so the PR title becomes the commit subject on `main`
  — give it the same Conventional Commits shape as a commit.

### Changes to behavior need a test

A new behavior or a bug fix needs a spec that fails before the change and
passes after. For a bug fix, write the failing spec first and confirm it fails
for the reason you expect — a test that never failed proves nothing.

### Changes to documentation need verification

`README.md` and `doc/operator.txt` are both expected to be accurate down to
the literal keys and commands. If you change an example, run it. If you add a
`|reference|` to the vimdoc, confirm it resolves. `doc/operator.txt` wraps at
78 columns, with section tags right-aligned to column 78.

## Reporting bugs

Include the output of `:checkhealth operator`, your Neovim version
(`nvim --version | head -1`), whether
[vim-repeat](https://github.com/tpope/vim-repeat) is installed, and the
smallest operator definition that reproduces the problem.

For anything involving `.` repeat, say which motion you used and where the
cursor was when you pressed `.` — the mechanism re-resolves the last motion at
the new cursor position, so those two details usually determine the outcome.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](./LICENSE) covering this project.
