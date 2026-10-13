NVIM_BIN ?= nvim

.PHONY: deps test check
deps:
	python3 scripts/deps.py

test: deps
	env -u NVIM -u NVIM_LISTEN_ADDRESS $(NVIM_BIN) --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run()"

check:
	stylua --check lua plugin ftplugin syntax tests
