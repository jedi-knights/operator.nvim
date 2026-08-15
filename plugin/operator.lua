-- operator: Neovim plugin entry point.
-- Loaded on startup; keeps this file tiny and defers real work to the
-- lua/operator/ module so :source and :Lazy reload behave.

if vim.g.loaded_operator then
	return
end
vim.g.loaded_operator = 1

-- Augroup is declared here and reused by lua/operator/init.lua.
-- clear = true is required — a stale augroup from a previous :source
-- would fire autocmds twice.
vim.api.nvim_create_augroup("operator", { clear = true })
