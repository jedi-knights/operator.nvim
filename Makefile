.PHONY: test lint format check

# Run the plenary-busted test suite headlessly.
test:
	nvim --headless -u scripts/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'scripts/minimal_init.lua' }"

lint:
	@command -v stylua > /dev/null && stylua --check . \
		|| echo "install stylua: https://github.com/JohnnyMorganz/StyLua"

format:
	@command -v stylua > /dev/null && stylua . \
		|| echo "install stylua: https://github.com/JohnnyMorganz/StyLua"

check: lint test
