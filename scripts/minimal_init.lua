-- Minimal init used by tests. Adds this repo to runtimepath so
-- `require("<module>")` resolves the local source.
--
-- Run tests with:
--   nvim --headless -u scripts/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ { minimal_init = 'scripts/minimal_init.lua' }"

vim.opt.rtp:prepend(vim.fn.getcwd())

-- Bootstrap plenary.nvim from the vendor pack if present; log a hint
-- rather than crash if it isn't.
local plenary_dir = vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim"
if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.notify(
    "plenary.nvim not found at " .. plenary_dir .. "; install it before running tests",
    vim.log.levels.ERROR
  )
end
vim.opt.rtp:prepend(plenary_dir)
