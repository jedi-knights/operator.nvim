--- operator: define reusable Vim operators from Lua.
---
--- `M.define(name, opts)` registers an operator and emits a
--- `<Plug>(operator-<name>)` mapping for normal and visual mode. The
--- caller binds a default key; the plugin never claims user keys.
---
--- The dispatcher sets `operatorfunc`, restores the previous value on
--- completion, and invokes `opts.callback(range)` with the motion's
--- resolved range.

local M = {}

--- Registry of defined operators, keyed by name.
--- Stored on the module so the dispatcher (called via v:lua) can find
--- an entry after the operator-pending motion resolves.
--- @type table<string, { callback: fun(range: table), dot_repeat: boolean }>
M._registry = {}

--- Name of the operator currently being applied. Set by the <Plug>
--- entry-mapping just before `g@`; read by `_call` when the motion
--- resolves; cleared afterwards. A single scalar is sufficient because
--- Vim can only be evaluating one operator at a time.
--- @type string?
M._pending_name = nil

--- Prior value of `operatorfunc`, saved so we restore it after our
--- callback runs. Prevents us from stomping another plugin's operator.
--- @type string?
M._prev_opfunc = nil

--- Build the range table the callback receives.
--- @param motion_type string One of "char", "line", "block" (from operatorfunc); or "v", "V", "\22" (from visualmode()).
--- @return table
local function build_range(motion_type)
	local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "["))
	local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, "]"))
	return {
		motion_type = motion_type,
		start = { row = start_row, col = start_col },
		finish = { row = end_row, col = end_col },
	}
end

--- Entry point invoked by the <Plug> mapping just before `g@`. Records
--- which operator is pending and saves the prior operatorfunc so the
--- dispatcher can restore it.
--- @param name string
local function begin(name)
	assert(M._registry[name], "operator: no operator registered under name " .. tostring(name))
	M._pending_name = name
	M._prev_opfunc = vim.go.operatorfunc
	vim.go.operatorfunc = "v:lua.require'operator'._call"
end

--- Called by Vim (via operatorfunc) once the motion resolves. Also
--- called directly from the visual-mode <Plug> mapping with the
--- visualmode() type.
--- @param motion_type string
function M._call(motion_type)
	local name = M._pending_name
	M._pending_name = nil

	vim.go.operatorfunc = M._prev_opfunc or ""
	M._prev_opfunc = nil

	if not name then
		return
	end
	local entry = M._registry[name]
	if not entry then
		return
	end

	entry.callback(build_range(motion_type))

	if entry.dot_repeat then
		pcall(function()
			vim.fn["repeat#set"]("\\<Plug>(operator-" .. name .. ")", vim.v.count)
		end)
	end
end

--- Register an operator.
--- @param name string Unique identifier; becomes `<Plug>(operator-<name>)`.
--- @param opts { callback: fun(range: table), desc: string?, dot_repeat: boolean? }
function M.define(name, opts)
	assert(type(name) == "string" and #name > 0, "operator.define: name required")
	assert(type(opts) == "table", "operator.define: opts required")
	assert(type(opts.callback) == "function", "operator.define: opts.callback must be a function")

	M._registry[name] = {
		callback = opts.callback,
		dot_repeat = opts.dot_repeat == true,
	}

	local plug = "<Plug>(operator-" .. name .. ")"
	local desc = opts.desc or ("operator: " .. name)

	vim.keymap.set("n", plug, function()
		begin(name)
		return "g@"
	end, { expr = true, desc = desc })

	vim.keymap.set("x", plug, function()
		begin(name)
		return "g@"
	end, { expr = true, desc = desc })
end

--- Optional setup; kept for parity with the scaffold. Users may skip it
--- entirely and call `M.define` directly — the API is stateless w.r.t.
--- setup.
--- @param opts table?
--- @param deps table?
function M.setup(opts, deps)
	local detector = require("operator.detector")
	if not detector.should_load() then
		return
	end
	M.config = require("operator.config").merge(opts or {})
	M.deps = deps or {}
end

return M
