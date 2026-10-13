# gin.nvim

A Lua rewrite of [vim-gin](https://github.com/lambdalisue/vim-gin) for Neovim.
The reference is fixed at `24cce091cfa32c013bc53cf4ff8f721d6690cf24`.
This implementation is in progress; see [MIGRATION.md](MIGRATION.md).

Requires Neovim 0.10+ and Git. No Denops or Deno runtime is required.

Run `make test` for mini.nvim tests and `make check` for formatting.
Development dependencies are fetched into `.deps/` at the commits in
`deps-lock.json`. Existing dependency checkouts must match the lock and be clean.

Currently implemented:

- `:Gin [++wait] [++worktree=path] {git arguments}` runs asynchronously by
  default. `++wait` waits for the result. Successful commands emit
  `User GinCommandPost`.
- `:GinBuffer [++opener=edit|split|vsplit|tabedit|pedit] {git arguments}` displays
  command output. Use `:edit` to reload. `++worktree`, `++filetype`, and
  `++monochrome` are accepted; output is currently monochrome.
- `:GinStatus [++worktree=path] [++opener=...] [flags] [-- pathspecs]` displays
  status. `<<` stages the current line or visual range; `>>` unstages it.
  `<Plug>(gin-action-stage)` and `<Plug>(gin-action-unstage)` are also available.
  `<CR>` opens the working file, `yy` yanks its absolute path (register prefixes
  work), `a` chooses an action, `.` repeats the chosen action, and `?` shows help.
  The edit actions include `edit:cached`, `edit:HEAD`, and their `:split`,
  `:vsplit`, and `:tabedit` variants.
- `:GinEdit [++worktree=path] [++opener=...] [commitish] {path}` opens the index
  file by default, or an immutable revision when a commitish is given. Relative
  paths are repository-relative. Writing the index buffer updates Git's index
  while preserving the working file. `:read {ginedit-URI}` inserts its content
  into another buffer. Encoding and fileformat options are accepted.
- `:GinCd`, `:GinLcd`, and `:GinTcd` change directory to the buffer's repository.

Commands locate the repository from the current buffer before trying cwd.
`++worktree` explicitly selects a repository. Filenames use Vim's command
argument syntax: escape spaces with backslashes; `%:p` expands the current file.
Git processes currently have a 30-second timeout.

The rewrite is not a complete replacement yet. Other views and actions,
interactive editor/askpass integration, color decorations, and components remain
in the migration checklist. Tests currently run locally on Neovim 0.13 nightly;
the stated minimum version has not yet been exercised.
