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

	-- vim-repeat is optional. Native `.` re-runs our operator with the
	-- last motion on the new cursor position because we leave
	-- operatorfunc pointing at our dispatcher. vim-repeat's `.` remap
	-- falls through to native `.` when there is no active repeat
	-- sequence for the current changedtick — so users get correct `.`
	-- behavior either way. The check stays as an info line so users can
	-- confirm the peer is installed when they expect it.
	if vim.fn.exists("*repeat#set") == 1 then
		vim.health.info("vim-repeat present (optional peer — native `.` works either way)")
	else
		vim.health.info("vim-repeat not installed (optional — native `.` works without it)")
	end
end

return M
