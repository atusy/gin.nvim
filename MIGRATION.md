# Migration scope

Reference: vim-gin `24cce091cfa32c013bc53cf4ff8f721d6690cf24`.
The haiku55 trial is not used as implementation input.

The following scope comes from the pinned plugin, autoload, ftplugin, and
Denops source trees. A checked item means implemented and tested for its stated
scope, not proof of complete upstream parity.

- [x] Pin upstream and mini.nvim; headless mini.test harness.
- [x] Git process execution and worktree discovery (files, subdirectories, symlinks, linked worktrees).
- [ ] Gin: arbitrary commands, argument expansion, modifiers, wait, postprocessors, indicators, events.
- [ ] GinBuffer: command output buffers, URI reads, reload and command binding.
- [ ] GinStatus: status display, path selection and all status actions.
- [ ] GinBranch, GinTag: parsed views and ref actions.
- [ ] GinLog, GinReflog, GinStash: parsed views, navigation and commit/stash actions.
- [ ] GinEdit: working tree, revision and index buffers with write-back.
- [ ] GinDiff: revision selection, read and diff navigation/folding.
- [ ] GinPatch: staging/unstaging partial changes.
- [ ] GinChaperon: conflict panes and resolution.
- [ ] GinBlame: blame navigation, history and detail.
- [ ] GinBrowse: remote URL generation and opening.
- [x] GinCd, GinLcd, GinTcd and worktree context.
- [ ] Shared actions: choice, repeat, help, range handling and Plug mappings.
- [ ] Editor/askpass proxies, commit/rebase integration.
- [ ] Branch/traffic/worktree components and component events.
- [ ] Help, syntax, highlights, options and default mappings in Lua.
- [ ] Full command/action audit against the pinned source and real Git-state integration tests.

## Validation rules

Tests use disposable repositories and check Git state as well as displayed
content. Failures, process errors and timeouts must propagate as failures.
Include subdirectory and special-path cases for read/write actions. Shared
external resources must be isolated. Reference comparison alone is insufficient
to prove an action produces the intended Git state.

## Current implementation evidence

- `tests/test_git.lua`: literal pathspecs, exit status/stderr, NUL output and timeouts.
- `tests/test_worktree.lua`: files/subdirectories, buffer priority, linked worktrees,
  symlinks and explicit invalid selection.
- `tests/test_command.lua`: synchronous/asynchronous Gin, filename expansion,
  completion events and local directory scope.
- `tests/test_buffer.lua`: scratch output, URI reload with spaces/hashes and split modifiers.
- `tests/test_status.lua`: display, staging/unstaging, empty selection, deletion,
  rename, newline/magic/dash paths, path filtering, visual range and event refresh.

Gin, GinBuffer and GinStatus remain unchecked above because their full option,
UI and action scope is still incomplete. No full upstream parity claim is made.
URI arguments use whitespace/backslash escaping to preserve argv boundaries
when reloaded; exact upstream URI interoperability still needs an audit.
Unstaging a rename resets both destination and original paths, so the whole
rename leaves the index. This differs from upstream's destination-only reset.

Next work: complete shared actions and the remaining status mappings, then
implement revision/index buffers, diff/patch and conflict handling with direct
Git-state tests. Audit every pinned command, option, mapping, event and component
before marking the migration complete.
