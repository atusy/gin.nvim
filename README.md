# gin.nvim

A Lua rewrite of [vim-gin](https://github.com/lambdalisue/vim-gin) for Neovim.
The reference is fixed at `24cce091cfa32c013bc53cf4ff8f721d6690cf24`.
This implementation is in progress; see [MIGRATION.md](MIGRATION.md).

Requires Neovim 0.10+ and Git. No Denops or Deno runtime is required.

Run `make test` for mini.nvim tests and `make check` for formatting.
Development dependencies are fetched into `.deps/` at the commits in
`deps-lock.json`. Existing dependency checkouts must match the lock and be clean.
