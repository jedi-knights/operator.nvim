--- :checkhealth operator entry point.

local M = {}

function M.check()
	vim.health.start("operator")

	local detector = require("operator.detector")
	if detector.should_load() then
		vim.health.ok("environment supports operator")
	else
		vim.health.warn("operator would not load in this environment (detector.should_load returned false)")
	end

	-- vim-repeat is an optional peer. Users only need it if they call
	-- define() with dot_repeat = true; without it, `.` still repeats
	-- the operator (built-in Vim behavior), but the count and mapping
	-- key won't be propagated through the <Plug> layer.
	if vim.fn.exists("*repeat#set") == 1 then
		vim.health.ok("vim-repeat present — dot_repeat = true will propagate through <Plug>")
	else
		vim.health.info(
			"vim-repeat not installed — dot_repeat = true is a silent no-op. "
				.. "Install tpope/vim-repeat for count/mapping propagation on `.`"
		)
	end
end

return M
