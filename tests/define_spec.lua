describe("operator.define", function()
	local operator

	before_each(function()
		-- Force a fresh module so each test starts with an empty registry
		-- and no leftover operatorfunc from a prior spec.
		package.loaded["operator"] = nil
		operator = require("operator")
		vim.go.operatorfunc = ""

		-- Fresh scratch buffer with a known payload so motions have
		-- something to bite on.
		vim.cmd("enew!")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	end)

	it("registers a <Plug> mapping in normal and visual mode", function()
		operator.define("test.mapping", { callback = function() end })

		assert.is_not.equal("", vim.fn.maparg("<Plug>(operator-test.mapping)", "n"))
		assert.is_not.equal("", vim.fn.maparg("<Plug>(operator-test.mapping)", "x"))
	end)

	-- Trigger the <Plug> mapping via a temporary user-facing key.
	-- feedkeys("<Plug>...") does not fire <Plug> mappings reliably in
	-- headless nvim; binding a real key + `remap = true` works because
	-- the plain keystroke expands through the mapping chain the same
	-- way it would from an interactive user.
	local function trigger(name, motion)
		vim.keymap.set("n", "<F13>", "<Plug>(operator-" .. name .. ")", { remap = true })
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<F13>" .. (motion or "iw"), true, false, true),
			"mx",
			false
		)
		vim.keymap.del("n", "<F13>")
	end

	it("invokes the callback with a range when a motion completes", function()
		local received
		operator.define("test.recv", {
			callback = function(range)
				received = range
			end,
		})

		trigger("test.recv")

		assert.is_not_nil(received)
		assert.equals("char", received.motion_type)
		assert.is_table(received.start)
		assert.is_table(received.finish)
	end)

	it("restores the prior operatorfunc after the callback runs", function()
		vim.go.operatorfunc = "PriorFunc"

		operator.define("test.restore", { callback = function() end })

		trigger("test.restore")

		assert.equals("PriorFunc", vim.go.operatorfunc)
	end)

	it("silently no-ops dot_repeat when vim-repeat is absent", function()
		-- vim-repeat is not vendored in the test env; the pcall around
		-- repeat#set must swallow the resulting E117.
		local called = false
		operator.define("test.repeatable", {
			dot_repeat = true,
			callback = function()
				called = true
			end,
		})

		trigger("test.repeatable")

		assert.is_true(called)
	end)

	describe("input validation", function()
		it("rejects a missing name", function()
			assert.has_error(function()
				operator.define(nil, { callback = function() end })
			end)
		end)

		it("rejects an empty name", function()
			assert.has_error(function()
				operator.define("", { callback = function() end })
			end)
		end)

		it("rejects missing opts", function()
			assert.has_error(function()
				operator.define("test.noopts")
			end)
		end)

		it("rejects a non-function callback", function()
			assert.has_error(function()
				operator.define("test.badcb", { callback = "not a function" })
			end)
		end)
	end)
end)
