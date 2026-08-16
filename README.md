# operator.nvim

[![CI](https://github.com/jedi-knights/operator.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/jedi-knights/operator.nvim/actions/workflows/ci.yml)

Define reusable Vim operators from Lua without hand-rolling the
`operatorfunc` / `g@` / `<Plug>` boilerplate every time.

Define once, get the full operator surface for free: `guiw`, `guap`,
`gU$`, visual + `gu`, and `.`-repeat — the same shape tpope's operator
plugins ship with.

**Requirements:** Neovim 0.10+. No peer dependencies — native `.` re-runs the operator with the last motion on the new cursor position.

**Status:** pre-v0.1.0. Public API is expected to stabilize with the v0.1.0 tag; treat as experimental until then.

## Install

```lua
-- lazy.nvim
{ "jedi-knights/operator.nvim" }
```

No `setup()` call required — the API is stateless.

## Usage

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

Then `guiw`, `guap`, `gU$`, visual + `gu`, and `.` (repeat) all work.

## API

### `operator.define(name, opts)`

- `name` (string) — unique identifier; becomes `<Plug>(operator-<name>)`.
- `opts.callback` (function) — receives a `range` table:
  - `motion_type` — `"char"`, `"line"`, `"block"` (or a `visualmode()` char when triggered from visual).
  - `start`, `finish` — `{ row, col }`. `row` is 1-indexed, `col` is 0-indexed.
- `opts.desc` (string, optional) — mapping description.

`.` re-runs the operator with the last motion on the new cursor
position automatically — the plugin leaves `operatorfunc` pointing at
its dispatcher, which is what Vim's built-in change-repeat mechanism
looks up. No `dot_repeat` opt-in required.

## License

MIT. See [LICENSE](./LICENSE).
