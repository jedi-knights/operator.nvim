.PHONY: test lint format check smoke

# Run the plenary-busted test suite headlessly.
test:
	nvim --headless -u scripts/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'scripts/minimal_init.lua' }"

# Ship-criterion smoke: define an operator, fire it, press `.`, verify.
# Runs against a real Neovim (headless) so `.` repeat is exercised end
# to end. See scripts/smoke.lua for the assertions.
smoke:
	nvim --headless -u scripts/smoke.lua

lint:
	@if ! command -v stylua > /dev/null; then \
		echo "install stylua: https://github.com/JohnnyMorganz/StyLua"; \
		exit 1; \
	fi
	stylua --check .

format:
	@if ! command -v stylua > /dev/null; then \
		echo "install stylua: https://github.com/JohnnyMorganz/StyLua"; \
		exit 1; \
	fi
	stylua .

check: lint test
