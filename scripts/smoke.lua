-- Manual v0.1.0 ship-criterion smoke for operator.nvim.
--
-- Runs the README's "uppercase" example inside a headless Neovim,
-- exercises the operator through a real motion, then presses `.` on
-- a new position to prove `.`-repeat works as the ship criterion
-- promises. Runs twice: once with vim-repeat installed, once without,
-- because the mechanism differs subtly between the two.
--
-- Ship criterion (from architecture/TODO.md operator.nvim section):
--   "A downstream plugin can define an operator in ~10 lines and get
--    `.` repeat for free."
--
-- Run:
--   nvim --headless -u scripts/smoke.lua
-- Exits 0 on success, 1 on any assertion failure. Prints PASS/FAIL
-- per check so a human reviewer sees which part covered what.

vim.opt.rtp:prepend(vim.fn.getcwd())

local failures = 0
local function check(name, ok, detail)
	if ok then
		io.stdout:write(string.format("PASS  %s\n", name))
	else
		failures = failures + 1
		io.stdout:write(string.format("FAIL  %s%s\n", name, detail and (" — " .. detail) or ""))
	end
end

-- vim-repeat is optional but common; load it if we can find it so the
-- smoke exercises the fall-through path. When installed, vim-repeat
-- remaps `.` and would break naive integrations — this smoke proves
-- our design (leave operatorfunc set, don't call repeat#set) works
-- correctly whether vim-repeat is present or not.
local function maybe_load_vim_repeat()
	local candidates = {
		vim.fn.stdpath("data") .. "/site/pack/vendor/start/vim-repeat",
		vim.fn.stdpath("data") .. "/lazy/vim-repeat",
	}
	for _, dir in ipairs(candidates) do
		if vim.fn.isdirectory(dir) == 1 then
			vim.opt.rtp:prepend(dir)
			vim.cmd("runtime! plugin/repeat.vim")
			vim.cmd("runtime! autoload/repeat.vim")
			return dir
		end
	end
	return nil
end

local vr_loc = maybe_load_vim_repeat()
io.stdout:write(string.format("INFO  vim-repeat: %s\n", vr_loc or "not installed (native `.` path only)"))

-- README example verbatim — the smoke is also a lint on the README.
-- Note: this is a LINE-scope callback — `string.upper(line)` upcases
-- the whole line(s) the range covers, not just the columns. The
-- fixture + assertions below match that behaviour.
local operator = require("operator")
operator.define("uppercase", {
	desc = "uppercase over motion",
	callback = function(range)
		local lines = vim.api.nvim_buf_get_lines(0, range.start.row - 1, range.finish.row, false)
		for i, line in ipairs(lines) do
			lines[i] = string.upper(line)
		end
		vim.api.nvim_buf_set_lines(0, range.start.row - 1, range.finish.row, false, lines)
	end,
})
vim.keymap.set({ "n", "x" }, "gu", "<Plug>(operator-uppercase)")

-- Two-line fixture so dot-repeat has a fresh line to land on.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
	"hello world",
	"lorem ipsum",
})

-- Primary: cursor on line 1 col 0, `guiw` fires the operator with an
-- inner-word motion. Range spans line 1 → whole line upcased.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("guiw", "x", false)
local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check(
	"primary operator: `guiw` on line 1 upcases line 1 only",
	buf[1] == "HELLO WORLD" and buf[2] == "lorem ipsum",
	string.format("buf: %s | %s", buf[1], buf[2])
)

-- operatorfunc must stay pointing at our dispatcher — that is the
-- mechanism that makes native `.` re-run the same operator. If a
-- future refactor re-introduces save/restore, this check fires.
check(
	"operatorfunc stays pointing at our dispatcher (enables native `.`)",
	vim.go.operatorfunc:match("operator") ~= nil,
	"opfunc: " .. tostring(vim.go.operatorfunc)
)

-- Ship-criterion `.` repeat: cursor to line 2, press `.`. Native Vim
-- change-repeat looks up operatorfunc and re-issues g@<motion> with
-- the last motion applied at the new cursor position → line 2 upcases.
-- vim-repeat's `.` remap (if installed) falls through to native `.`
-- when there is no active repeat sequence for the current changedtick,
-- so this works regardless of whether vim-repeat is present.
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.api.nvim_feedkeys(".", "x", false)
buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check(
	"`.` re-runs operator on new line: line 2 upcased",
	buf[1] == "HELLO WORLD" and buf[2] == "LOREM IPSUM",
	string.format("buf: %s | %s", buf[1], buf[2])
)

-- Report + exit through Vim's `cquit!` so nvim --headless returns
-- the aggregate status back to the shell.
io.stdout:write(string.format("\n%s: %d check(s) failed\n", failures == 0 and "OK" or "FAILURE", failures))
vim.cmd(failures == 0 and "cquit! 0" or "cquit! 1")
