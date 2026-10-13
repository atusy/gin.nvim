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
  `User GinCommandPost`. `++processor=command\ args` transforms stdout; with a
  processor configured, the event fires only after the processor succeeds.
- `:GinBuffer [++opener=edit|split|vsplit|tabedit|pedit] {git arguments}` displays
  command output. Use `:edit` to reload, or `:read {gin-URI}` to insert output
  into another buffer. `++worktree`, `++filetype`, and
  `++monochrome` are accepted; output is currently monochrome.
  `++enc`/`++encoding` and `++ff`/`++fileformat` select decoding and survive reloads.
  `++processor=command\ args` transforms successful Git output through a command
  run in the repository directory; processor errors fail the read.
- `:GinStatus [++worktree=path] [++opener=...] [flags] [-- pathspecs]` displays
  status. `<<` stages the current line or visual range; `>>` unstages it.
  `<Plug>(gin-action-stage)` and `<Plug>(gin-action-unstage)` are also available.
  `dd` opens a smart diff, `pp` opens a patch tab, `!!` opens a conflict-resolution
  tab, and `==` stashes the selection.
  `<CR>` opens the working file, `yy` yanks its absolute path (register prefixes
  work), `a` chooses an action, `.` repeats the chosen action, and `?` shows help.
  The edit actions include `edit:cached`, `edit:HEAD`, and their `:split`,
  `:vsplit`, and `:tabedit` variants.
- `:GinBranch [flags] [patterns...]` lists branches with commit and upstream
  information and refreshes after successful Gin commands. `<CR>` switches to
  the selected branch; `yy` yanks its name.
  The action menu includes `switch:detach`, `delete`, `delete:force`, and
  yanks for branch, target, and commit. `new`, `new:force`, and `new:orphan`
  create and switch branches. `move`/`move:force` rename a branch or relocate
  its linked worktree. `worktree`, `worktree:force`, and `worktree:orphan` prompt
  for a branch and checkout path, then change cwd to the created worktree.
  `merge`/`merge:ff`, `merge:no-ff`, and `merge:ff-only` merge the selected ref
  into the current branch. `rebase`, `rebase:x`, and `rebase:instant-drop` replay
  onto the selected ref, run an exec command, or drop the selected commit.
  Interactive rebase actions remain pending. Remote deletion deletes the remote ref.
- `:GinLog [flags] [revision] [-- paths...]` displays commit history. `<CR>`
  shows the selected commit; `yy` yanks its hash. Show actions support edit,
  split, vsplit, and tabedit destinations. Branch `log` actions open GinLog
  at the selected ref with the same destination variants. `cherry-pick` and
  `revert` act on the selected commit; `:1`/`:2` variants select a merge parent.
  `reset`, `reset:soft`, `reset:hard`, `reset:merge`, and `reset:keep` reset
  to the selected commit using the corresponding Git mode. `tag:lightweight`
  prompts for a tag at the selected commit; `tag:lightweight:force` replaces
  an existing tag. `fixup` commits staged changes for the selected commit;
  `fixup:instant-fixup` immediately autosquashes them, including root commits.
  `switch:detach` checks out the selected commit without moving a branch ref.
  Merge and non-interactive rebase variants work as in GinBranch, targeting
  the selected commit.
  Annotated/signed tags and fixup amend/reword actions remain pending.
- `:GinReflog [flags] [ref]` displays reflog history with the implemented GinLog
  actions, including show and reset for commits no longer in normal history.
- `:GinStash [flags]` lists saved changes. Actions include `apply`, `pop`, their
  `:index` variants, and `drop`; each acts on the first selected entry. `<CR>`
  shows a stash and `yy` yanks its ref. The view refreshes after Gin commands.
- `:GinTag [flags] [patterns...]` lists tags. `<CR>` shows the selected tag;
  `yy` yanks its name. Actions include `delete`, `switch:detach`, and
  `yank:commit`. `show:split`, `show:vsplit`, and `show:tabedit` choose the
  destination. Show views support diff folds and revision jumps. The tag view
  refreshes after successful Gin commands.
- `:GinEdit [++worktree=path] [++opener=...] [commitish] {path}` opens the index
  file by default, or an immutable revision when a commitish is given. Relative
  paths are repository-relative. Writing the index buffer updates Git's index
  while preserving the working file. `:read {ginedit-URI}` inserts its content
  into another buffer. Encoding and fileformat options are accepted.
- `:GinDiff [++worktree=path] [++opener=...] [flags] [commitish] [-- paths...]`
  displays a Git comparison. Encoding/fileformat and processor options work as
  in GinBuffer.
  `--cached` compares the index; revision ranges are
  supported. Paths are repository-relative. `<CR>` jumps to the matching side of
  a changed line; `g<CR>` selects the old revision and `<C-g><CR>` the new one.
  File sections have manual folds with status and change counts (`zc`/`zo` to
  close/open). Customize labels with `g:gin_difffold_prefixes`.
  `:read {gindiff-URI}` inserts the comparison into another buffer. Reads support
  line addresses and `++enc`/`++ff` without changing destination buffer options.
- `:GinPatch [++no-head] [++no-worktree] [path]` opens HEAD, index, and working-file
  diff panes, focusing the index. The optional path is relative to cwd and defaults
  to the current file. In the index pane, `dor` gets the working hunk and `dol`
  gets the HEAD hunk; `:write` saves the result to the index. `do` gets the right
  pane when available, otherwise the left. `dp` puts the hunk into the working
  pane. Other panes use `do`/`dp` with the index where applicable.
- `:GinChaperon [++no-ours] [++no-theirs] [path]` opens theirs, working-file,
  and ours conflict panes, focusing the working file. The path defaults to the
  current file and is relative to cwd. Conflict blocks are removed from the
  buffer; `dol`/`dor` get a hunk from theirs/ours, and `do` prefers ours when
  available. Side panes use `dp` to put a hunk into the working file. Write the
  resolved file, then stage it explicitly. Supporting commit logs appear below
  the panes; set `g:gin_chaperon_supplement_disable = 1` to hide them or
  `g:gin_chaperon_supplement_height` to adjust their height (default 10).
- `:[range]GinBrowse [flags] [revision] [path]` opens a hosting URL for the
  current file by default. `--no-browser` prints it; `++yank=a` copies it to
  register `a`. Supports `--home`, `--commit`, `--permalink`, `--remote=name`,
  and `++repository`, with GitHub/GitLab/Bitbucket routes and host aliases in
  `g:gin_browse_aliases`. Remote selection prefers `origin` among remotes
  containing the commit, then another containing remote, with `origin` as fallback.
  `--pr` (or `browse:pr`/`browse:pr:yank`) finds GitHub PR URLs from merge
  messages and local ancestry; it uses the remote HEAD ref, falling back to `main`.
- `:GinBlame [commitish] path` opens a tab with synchronized attribution and
  committed file content, plus commit details that follow the cursor. Supports
  `++worktree` and `++opener`. Reloading either source or attribution refreshes
  the existing panes; closing a pane removes its companions. `<CR>` follows a
  line to its source commit and historical filename; selecting that commit again
  visits its parent. `g:gin_blame_disable_default_mappings` disables the default
  key bindings. `<C-O>` and `<C-I>` move backward and forward through visited
  revisions, restoring filenames and cursor positions. `++enc`/`++encoding` and
  `++ff`/`++fileformat` select file decoding and persist through navigation.
  Emoji rendering is still being ported.
- `:GinCd`, `:GinLcd`, and `:GinTcd` change directory to the buffer's repository.

The `echo` action in status, branch, tag, history, and stash views prints the
selected candidate metadata as JSON. `browse` opens selected files or refs;
`:commit`, `:permalink`, and `:yank` suffixes select URL and copy behavior.
Set `g:gin_browse_persistent_args = { "--no-browser" }` to print URLs instead
of opening them.

Commands locate the repository from the current buffer before trying cwd.
`++worktree` explicitly selects a repository. Filenames use Vim's command
argument syntax: escape spaces with backslashes; `%:p` expands the current file.
Git processes currently have a 30-second timeout.

The rewrite is not a complete replacement yet. Other views and actions,
interactive editor/askpass integration, color decorations, and components remain
in the migration checklist. Tests currently run locally on Neovim 0.13 nightly;
the stated minimum version has not yet been exercised.

Statusline components are available as Lua functions:

- `require("gin.component.branch").ascii()` / `.unicode()` show the branch and upstream.
- `require("gin.component.traffic").ascii()` / `.unicode()` show ahead/behind counts.
- `require("gin.component.worktree").name()` / `.full()` show the repository path.

They return cached strings and update asynchronously on buffer/directory changes
and `GinCommandPost`. Listen for `User GinComponentPost` to redraw your statusline.
