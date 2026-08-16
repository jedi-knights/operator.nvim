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
--- @type table<string, { callback: fun(range: table) }>
M._registry = {}

--- Name of the operator currently being applied. Set by the <Plug>
--- entry-mapping just before `g@`; read by `_call` when the motion
--- resolves. **Intentionally not cleared afterwards** so native `.`
--- (which re-invokes operatorfunc with the last motion applied to the
--- new cursor position) fires the same operator again. A single scalar
--- is sufficient because Vim can only be evaluating one operator at a
--- time; the next `<Plug>` invocation overwrites it.
--- @type string?
M._pending_name = nil

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
--- which operator is pending and installs our dispatcher as
--- `operatorfunc`. We deliberately do NOT save the prior value so we
--- can restore it — every operator plugin in the ecosystem (commentary,
--- surround, unimpaired) leaves operatorfunc set on the last op that
--- fired, because that is what makes native `.` re-run the same
--- operator. Save/restore looks polite but silently breaks the
--- ship-criterion `.` repeat.
--- @param name string
local function begin(name)
	assert(M._registry[name], "operator: no operator registered under name " .. tostring(name))
	M._pending_name = name
	vim.go.operatorfunc = "v:lua.require'operator'._call"
end

--- Called by Vim (via operatorfunc) once the motion resolves. Also
--- called directly from the visual-mode <Plug> mapping with the
--- visualmode() type.
--- @param motion_type string
function M._call(motion_type)
	-- Read but don't clear: native `.` re-invokes operatorfunc with the
	-- last motion applied to the new cursor position, and we want that
	-- re-invocation to fire the same operator. The next `<Plug>` call
	-- overwrites _pending_name naturally.
	local name = M._pending_name
	if not name then
		return
	end
	local entry = M._registry[name]
	if not entry then
		return
	end

	entry.callback(build_range(motion_type))
	-- No repeat#set call: our <Plug> mapping returns g@ (motion-agnostic
	-- setup), and vim-repeat's replay would only re-issue <Plug> without
	-- capturing the motion — leaving the operator hanging in op-pending.
	-- Native `.` works via Vim's own change-repeat, which re-invokes
	-- operatorfunc with the last motion applied to the new cursor
	-- position; that requires operatorfunc to stay set (see the comment
	-- on begin()). vim-repeat's `.` remap falls through to native `.`
	-- when no active repeat sequence exists for the current changedtick,
	-- so leaving repeat#set uncalled is the right choice.
end

--- Register an operator.
---
--- Native Vim `.` re-runs the operator with the last motion on the new
--- cursor position — no `dot_repeat` opt-in required. See the comment
--- on `begin()` for the mechanism.
---
--- @param name string Unique identifier; becomes `<Plug>(operator-<name>)`.
--- @param opts { callback: fun(range: table), desc: string? }
function M.define(name, opts)
	assert(type(name) == "string" and #name > 0, "operator.define: name required")
	assert(type(opts) == "table", "operator.define: opts required")
	assert(type(opts.callback) == "function", "operator.define: opts.callback must be a function")

	M._registry[name] = {
		callback = opts.callback,
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
