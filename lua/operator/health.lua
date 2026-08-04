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
end

return M
