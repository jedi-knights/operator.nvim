describe("operator.health", function()
	local health
	local recorded

	before_each(function()
		package.loaded["operator.health"] = nil
		health = require("operator.health")

		-- Stub vim.health so the test observes what check() reports
		-- without depending on the real :checkhealth buffer.
		recorded = { start = {}, ok = {}, warn = {}, info = {}, error = {} }
		vim.health = setmetatable({}, {
			__index = function(_, key)
				return function(msg)
					table.insert(recorded[key], msg)
				end
			end,
		})
	end)

	it("starts a health section named 'operator'", function()
		health.check()
		assert.equals("operator", recorded.start[1])
	end)

	it("reports vim-repeat status", function()
		health.check()
		-- vim-repeat is not vendored in the test env, so this must
		-- surface as info (informational, not a warning — it's optional).
		local combined = table.concat(recorded.info, "\n") .. table.concat(recorded.ok, "\n")
		assert.is_truthy(combined:match("vim%-repeat"))
	end)

	it("does not error", function()
		-- If health.check() raises, the test fails naturally via the
		-- unhandled error. neospec's luassert does not expose
		-- plenary.busted's `assert.has_no.errors` sugar.
		health.check()
	end)
end)
