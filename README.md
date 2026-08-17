# operator.nvim

Turn any Lua function into a real Vim operator — a verb that composes with every motion and text object you already know.

[![CI](https://github.com/jedi-knights/operator.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/jedi-knights/operator.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [API](#api)
- [Configuration](#configuration)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Overview

**An operator is a verb that waits for a motion.** `d` is an operator, so is `y`,
`c`, `gU`, and `gq`. You never learned `d` and `diw` and `dap` and `d2j` as
separate commands — you learned one verb and combined it with the nouns you
already knew. That combinatorial grammar is the whole reason Vim editing scales.

Most Neovim plugins don't participate in that grammar. They ship a command
(`:SortLines`), or a keymap that hardcodes one scope (`<leader>s` = sort the
current paragraph). If you want the same behavior over the next 10 lines, inside
a function, or over a visual selection, you need a second keymap, a range
variant, and a visual variant — and none of them repeat with `.`.

Writing a *real* operator fixes that, but Vim makes you earn it. You have to set
`'operatorfunc'`, return `g@` from an `<expr>` mapping, read the `` '[ `` and `` '] ``
marks to recover the range, handle char/line/block motion types, write a
separate visual-mode path, and get `.`-repeat working without breaking anyone
else's `'operatorfunc'`. That's 40 lines of fiddly plumbing that has nothing to
do with what your plugin actually does — and it's the same 40 lines in every
plugin that does it.

operator.nvim is that plumbing, extracted. You write the callback that transforms
a range; you get the full operator surface:

```lua
operator.define("sort", { callback = sort_range })
vim.keymap.set({ "n", "x" }, "gs", "<Plug>(operator-sort)")
```

That one definition gives you `gsip` (sort a paragraph), `gs2j` (sort three
lines), `gsi{` (sort a block), `gsG` (sort to end of file), `gs` over a visual
selection, and `.` to repeat any of them at a new cursor position. You didn't
enumerate those — the grammar did.

## Features

- **One definition, the whole operator surface** — every motion, every text
  object, plus visual mode, from a single callback.
- **Native `.`-repeat, no opt-in** — `.` re-runs your operator with the last
  motion at the new cursor position, the same way `d` and `gU` behave.
- **No peer dependencies** — works with or without
  [tpope/vim-repeat](https://github.com/tpope/vim-repeat).
- **Never claims your keys** — emits a `<Plug>` mapping; you decide the binding,
  so your users can rebind it without patching your plugin.
- **Stateless API** — no `setup()` call, no global config, no load-order concerns.
- **Motion type passed through** — your callback sees `"char"`, `"line"`, or
  `"block"` and can behave differently for each.

## Requirements

- Neovim 0.10+
- No peer dependencies. [tpope/vim-repeat](https://github.com/tpope/vim-repeat)
  is supported but not needed — `.` works either way.

**Status:** pre-v0.1.0. The public API is expected to stabilize with the v0.1.0
tag; treat it as experimental until then.

## Installation

There is no `setup()` call — the API is stateless. Instead, **your operator
definitions are the configuration**, so they live wherever your plugin manager
runs a plugin's config function.

### lazy.nvim

One file per plugin under `~/.config/nvim/lua/plugins/`, picked up by the
`{ import = "plugins" }` spec that every lazy.nvim setup uses:

```lua
-- ~/.config/nvim/lua/plugins/operator.lua
return {
  "jedi-knights/operator.nvim",
  config = function()
    local operator = require("operator")

    operator.define("sort", {
      desc = "sort lines over motion",
      callback = function(range)
        local lines = vim.api.nvim_buf_get_lines(0, range.start.row - 1, range.finish.row, false)
        table.sort(lines)
        vim.api.nvim_buf_set_lines(0, range.start.row - 1, range.finish.row, false, lines)
      end,
    })

    vim.keymap.set({ "n", "x" }, "gs", "<Plug>(operator-sort)", { desc = "sort over motion" })
  end,
}
```

Define as many operators as you like in that one `config` function — each call
to `operator.define` is independent.

### Lazy-loading on the key

Add `keys` and the plugin stays off the startup path until you first press it:

```lua
-- ~/.config/nvim/lua/plugins/operator.lua
return {
  "jedi-knights/operator.nvim",
  keys = { { "gs", mode = { "n", "x" }, desc = "sort over motion" } },
  config = function()
    -- same as above
  end,
}
```

This works with operators, which is not obvious: lazy.nvim intercepts `gs`,
loads the plugin, then replays the key — and the operator still waits for its
motion afterwards, so `gsip` resolves correctly on the very first press.

### vim.pack (Neovim 0.12+)

```lua
-- ~/.config/nvim/init.lua
vim.pack.add({ { src = "https://github.com/jedi-knights/operator.nvim" } })

require("operator").define("sort", { --[[ ... ]] })
vim.keymap.set({ "n", "x" }, "gs", "<Plug>(operator-sort)")
```

### Where this goes in a distribution

Every lazy.nvim-based distribution takes the same spec table, so the rule is
always the same: **your definitions go in the spec's `config` function.** Only
the file path differs.

| Distribution | Put the spec in |
|---|---|
| Plain lazy.nvim, LazyVim, AstroNvim | a new file under `~/.config/nvim/lua/plugins/` |
| NvChad | the returned table in `~/.config/nvim/lua/plugins/init.lua` |
| kickstart.nvim | inline in the `require("lazy").setup({ ... })` table in `init.lua` |
| No plugin manager | anywhere sourced after the plugin is on `runtimepath` |

These are each distribution's conventional location for a user plugin spec; if
yours has been customized, the spec belongs wherever your other plugin specs
already live.

## Usage

Wherever you put it, the shape is the same — define the operator, then bind the
`<Plug>` mapping to whatever key you want:

```lua
local operator = require("operator")

operator.define("uppercase", {
  desc = "uppercase over motion",
  callback = function(range)
    -- range.motion_type is "char", "line", or "block"
    -- range.start / range.finish are { row = 1-indexed, col = 0-indexed }
    local lines = vim.api.nvim_buf_get_lines(0, range.start.row - 1, range.finish.row, false)
    for i, line in ipairs(lines) do
      lines[i] = string.upper(line)
    end
    vim.api.nvim_buf_set_lines(0, range.start.row - 1, range.finish.row, false, lines)
  end,
})

-- Bind whatever key you want; the plugin never claims user keys.
vim.keymap.set({ "n", "x" }, "gu", "<Plug>(operator-uppercase)")
```

That single definition now responds to:

| Keys | Range the callback receives |
|---|---|
| `guiw` | the inner word under the cursor |
| `guap` | the surrounding paragraph |
| `gu$` | cursor through end of line |
| `gu2j` | this line and the next two |
| `v}gu` | the visual selection |
| `.` | the last motion, re-resolved at the cursor's new position |

This particular callback rewrites whole lines, so it upcases every line the range
touches. Read `range.start.col` / `range.finish.col` when you want to honor
character-wise boundaries — see the backtick example below.

## Examples

Every example below is verified end-to-end against a real headless Neovim.

### Sort lines over any motion

The classic case for "this should have been an operator." A `:sort` range
command works, but it doesn't compose and it doesn't repeat.

```lua
local operator = require("operator")

operator.define("sort", {
  desc = "sort lines over motion",
  callback = function(range)
    local lines = vim.api.nvim_buf_get_lines(0, range.start.row - 1, range.finish.row, false)
    table.sort(lines)
    vim.api.nvim_buf_set_lines(0, range.start.row - 1, range.finish.row, false, lines)
  end,
})

vim.keymap.set({ "n", "x" }, "gs", "<Plug>(operator-sort)")
```

`gsip` sorts a paragraph, `gsi{` sorts a block's contents, `gsG` sorts to end of
file — and `.` sorts the next paragraph without re-typing anything.

### Wrap a charwise motion in backticks

Character-wise operators read the range's columns, not just its rows. Note that
`finish.col` is *inclusive*, so add 1 when slicing.

```lua
local operator = require("operator")

operator.define("backtick", {
  desc = "wrap motion in backticks",
  callback = function(range)
    -- "char" comes from a motion; "v" comes from charwise visual mode.
    if range.motion_type ~= "char" and range.motion_type ~= "v" then
      return
    end
    local sr, sc = range.start.row - 1, range.start.col
    local er, ec = range.finish.row - 1, range.finish.col + 1
    local text = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
    text[1] = "`" .. text[1]
    text[#text] = text[#text] .. "`"
    vim.api.nvim_buf_set_text(0, sr, sc, er, ec, text)
  end,
})

vim.keymap.set({ "n", "x" }, "gb", "<Plug>(operator-backtick)")
```

`gbiw` wraps a word, `gbi"` wraps a string's contents, `gbf,` wraps up to the
next comma, `vegb` wraps a visual selection. Pressing `.` on the next identifier
wraps that one too.

### Send a motion's text somewhere else

Operators don't have to modify the buffer. Any function that consumes a chunk of
text — a REPL, a search, an LLM prompt, a scratch buffer — becomes composable
the moment you express it as an operator.

```lua
local operator = require("operator")

operator.define("search", {
  desc = "web-search the motion text",
  callback = function(range)
    local text = vim.api.nvim_buf_get_text(
      0,
      range.start.row - 1, range.start.col,
      range.finish.row - 1, range.finish.col + 1,
      {}
    )
    vim.ui.open("https://duckduckgo.com/?q=" .. vim.uri_encode(table.concat(text, " ")))
  end,
})

vim.keymap.set({ "n", "x" }, "gS", "<Plug>(operator-search)")
```

`gSiw` searches the word, `gSi(` searches the call's arguments, `gS$` searches
the rest of the line.

## API

### `operator.define(name, opts)`

Registers an operator and emits `<Plug>(operator-<name>)` for normal and visual
mode. Call it as many times as you like; the API is stateless.

- `name` (string) — unique identifier; becomes `<Plug>(operator-<name>)`.
- `opts.callback` (function) — receives a `range` table:
  - `motion_type` — `"char"`, `"line"`, or `"block"` when invoked from a motion;
    a `visualmode()` char (`"v"`, `"V"`, `"\22"`) when invoked from visual mode.
  - `start`, `finish` — `{ row, col }`. `row` is 1-indexed (matches `line()`),
    `col` is 0-indexed and `finish.col` is inclusive (matches the `` '[ `` /
    `` '] `` marks Vim sets before calling `'operatorfunc'`).
- `opts.desc` (string, optional) — mapping description, shown by `maparg()` and
  which-key-style UIs. Defaults to `"operator: <name>"`.

Errors on a missing or empty `name`, missing `opts`, or a non-function callback.

### Dot repeat

`.` re-runs the operator with the last motion at the new cursor position
automatically — no `dot_repeat` opt-in. operator.nvim leaves `'operatorfunc'`
pointing at its dispatcher, which is exactly what Vim's built-in change-repeat
mechanism looks up. If vim-repeat is installed, its `.` remap falls through to
native `.` when no repeat sequence is active for the current changedtick, so
behavior is identical either way.

### Health

Run `:checkhealth operator` to confirm the plugin loaded. The vim-repeat probe
in that report is informational only.

Full reference: `:help operator`.

## Configuration

N/A — there is nothing to configure. `operator.define` takes everything it needs
per call, and no `setup()` is required.

## Development

```bash
make test    # plenary-busted suite, headless
make smoke   # end-to-end ship criterion: define, fire, press `.`, verify
make lint    # stylua --check
make format  # stylua
make check   # lint + test
```

`make lint` and `make format` require [StyLua](https://github.com/JohnnyMorganz/StyLua).

## Contributing

Issues and pull requests are welcome at
[jedi-knights/operator.nvim](https://github.com/jedi-knights/operator.nvim).
Run `make check` before opening a PR; CI runs the same targets.

## License

MIT. See [LICENSE](./LICENSE).
