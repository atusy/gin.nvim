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
- [ ] GinEdit: revision and index buffers with write-back; working files via edit actions.
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

- `tests/test_chaperon.lua`: real merge resolution, explicit staging, supplementary
  commit logs, single-side layouts and status conflict tabs.
- `tests/test_branch.lua`: branch selection, switching, local/remote deletion,
  current-branch rejection, pattern reloads, named-register yanks, creation,
  forced reset, orphan branches, cancellation, rename and linked-worktree moves.
- `tests/test_action.lua`: captured choice ranges, repeat, aliases and mapping help.
- `tests/test_diff.lua`: working/index/revision comparisons, cached reload and smart
  status target selection, working/index/revision jumps, reverse and three-dot
  comparisons, quoted paths, hunk line offsets and fold rebuilding.
- `tests/test_patch.lua`: single-hunk staging/unstaging, subdirectory/current-file
  paths, omitted panes, mapping lifecycle and status patch tabs.
- `tests/test_edit.lua`: revision reads, direct index writes, executable mode, absent
  working files, clean filters, BOM/CRLF, no-EOL, empty blobs, failed writes,
  addressed/empty-buffer reads and filename expansion.
- `tests/test_git.lua`: literal pathspecs, exit status/stderr, NUL output and timeouts.
- `tests/test_worktree.lua`: files/subdirectories, buffer priority, linked worktrees,
  symlinks and explicit invalid selection.
- `tests/test_command.lua`: synchronous/asynchronous Gin, filename expansion,
  completion events, local directory scope, synchronous/asynchronous processors
  and failure propagation without success events.
- `tests/test_buffer.lua`: scratch output, URI reload with spaces/hashes, split
  modifiers, addressed reads, encoding conversion, insertion marks/read events
  and failure handling without destination changes, plus encoding/fileformat
  selection for command buffers and reloads.
- `tests/test_status.lua`: display, staging/unstaging, empty selection, deletion,
  rename, newline/magic/dash paths, path filtering, visual range, event refresh,
  action repeat, local/cached edit navigation, named-register path yanks, restore
  including conflict sides/markers, add/removal, stash/keep-index and intent-to-add.

Gin, GinBuffer and GinStatus remain unchecked above because their full option,
UI and action scope is still incomplete. No full upstream parity claim is made.
URI arguments use whitespace/backslash escaping to preserve argv boundaries
when reloaded; exact upstream URI interoperability still needs an audit.
Unstaging a rename resets both destination and original paths, so the whole
rename leaves the index. This differs from upstream's destination-only reset.

Shared choice/repeat/help/alias dispatch and file edit/yank actions are now
implemented. Their complete mapping and customization compatibility still needs
an audit. GinEdit supports revision and index reads, addressed reads and index
writes; binary/encoding edge cases and full upstream option parity remain to be
verified. Index writes use hash-object/update-index with the existing file mode
and clean filters, avoiding temporary replacement of working files.

GinDiff now displays working-tree, cached and revision comparisons and backs the
status diff actions. Jumps resolve working/index/revision targets, including the
merge base for three-dot comparisons. File folds show status and change counts.
Addressed reads support encoding/fileformat overrides; command buffers also retain encoding/fileformat options on reload.
Buffer/diff processors transform successful Git output and survive reloads/reads;
combined diffs and nonstandard prefix options still need a navigation audit. GinPatch provides three/two-pane diff editing
with index write-back and status actions; remaining option and visual-range
compatibility needs an audit. The checklist stays open until those checks finish.

GinChaperon provides conflict panes, directional resolution mappings, supporting
commit logs and status actions. Opening the view edits only the buffer; writing
and staging remain separate steps. Full option, conflict-type and visual-range
compatibility still needs an audit. When there is no in-progress operation head,
its dependent supplemental logs are omitted instead of running an invalid log
command as upstream does.

Next work: remaining buffer/diff options and parsed views with direct
Git-state tests. Complete status browse/echo actions as their supporting modules
become available. Audit every pinned command, option, mapping, event and component
before marking the migration complete.

GinBranch now displays structured ref metadata and supports switch/delete/yank
actions, plus creation and branch/worktree moves. Worktree creation,
log/browse/merge/rebase actions,
automatic refresh and complete option/display compatibility remain pending.
