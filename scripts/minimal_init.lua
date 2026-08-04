-- Minimal init used by tests. Adds this repo to runtimepath so
-- `require("<module>")` resolves the local source.
--
-- Run tests with:
--   nvim --headless -u scripts/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ { minimal_init = 'scripts/minimal_init.lua' }"

vim.opt.rtp:prepend(vim.fn.getcwd())

-- Bootstrap plenary.nvim. Check the two common install locations:
-- the pack/vendor/start path (CI convention) and lazy.nvim's dir
-- (local dev convention).
local candidates = {
	vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim",
	vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
}

local found
for _, dir in ipairs(candidates) do
	if vim.fn.isdirectory(dir) == 1 then
		vim.opt.rtp:prepend(dir)
		found = dir
		break
	end
end

if not found then
	vim.notify("plenary.nvim not found in any of: " .. table.concat(candidates, ", "), vim.log.levels.ERROR)
end
