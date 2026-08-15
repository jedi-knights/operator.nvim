describe("operator", function()
	it("exposes a setup function", function()
		local mod = require("operator")
		assert.is_function(mod.setup)
	end)

	it("merges opts over defaults", function()
		local mod = require("operator")
		mod.setup({ enabled = false })
		assert.is_false(mod.config.enabled)
	end)

	it("accepts injected dependencies", function()
		local mod = require("operator")
		local fake = { notify = function() end }
		mod.setup({}, { notifier = fake })
		assert.equals(fake, mod.deps.notifier)
	end)
end)
