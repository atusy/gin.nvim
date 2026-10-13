# Migration scope

Reference: vim-gin `24cce091cfa32c013bc53cf4ff8f721d6690cf24`.
The haiku55 trial is not used as implementation input.

The following scope comes from the pinned plugin, autoload, ftplugin, and
Denops source trees. A checked item means implemented and tested for its stated
scope, not proof of complete upstream parity.

- [x] Pin upstream and mini.nvim; headless mini.test harness.
- [x] Git process execution and worktree discovery (files, subdirectories, symlinks, linked worktrees).
- [ ] Gin: arbitrary commands, argument expansion, modifiers, wait, postprocessors, indicators, events.
- [ ] GinBuffer: command output buffers, URI reads, reload and decorations.
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
  forced reset, orphan branches, cancellation, rename, linked-worktree moves,
  worktree creation, orphan checkouts, command-driven refresh, event cleanup,
  merge ancestry, ff-only rejection, rebase replay/exec and instant-drop history.
- `tests/test_log.lua`: history order, default/oneline/graph selection, revision
  and path filters, reloads, show/yank actions, branch-to-log navigation,
  cherry-pick, ordinary/mainline revert, reset-mode HEAD/index/worktree effects
  keep-mode rejection of local changes, lightweight tag targets, forced tag
  replacement, cancellation, fixup messages/trees, root-commit autosquash,
  reflog recovery after reset, ref/limit reloads, detached switching from both
  history views, rejection of ordinary switches to commit IDs, selected-log
  merges and selected-reflog rebases.
- `tests/test_stash.lua`: selected stash apply/index restoration, pop/drop
  entry retention, range handling and failed-pop conflict state.
- `tests/test_tag.lua`: lightweight/annotated tags, pattern reloads, show,
  deletion, named-register yanks, detached checkout, split/tab show views
  and jumps from shown content to historical files.
- `tests/test_browse.lua`: encoded file URLs, ranges, permalinks, host-specific
  home/commit routes, current-file named-register yanking without a browser,
  ancestry-based remote selection, origin preference, explicit overrides,
  status browse from subdirectories and selected-history commit URLs.
- `tests/test_action.lua`: captured choice ranges, repeat, aliases, mapping help and JSON echo selection.
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
actions, plus branch/worktree creation and moves. Browse and interactive rebase actions,
complete option/display compatibility remain pending. Branch views refresh after
GinCommandPost while preserving the current view.

Worktree creation supplies `-b` when the requested branch differs from the
selected starting ref; the pinned implementation omits it and fails that case.

Branch merge actions now support ff/no-ff/ff-only. Tests bypass the commit editor
using a fixture-local configuration; editor proxy integration remains pending.

GinTag now provides listing, show/delete/switch/yank actions and command-driven
refresh. Browse/echo, emoji show variants, custom format/parser options, encoding and
emoji handling still require implementation or compatibility checks.

GinLog now displays history with revision/path filters, show/yank actions and
command-driven refresh. Other commit actions, custom parsing, emoji/color and
full option compatibility remain pending.

GinLog cherry-pick/revert actions include parent-one/parent-two variants.
Revert supplies --mainline only when selected, correcting the inverted condition
in the pinned implementation. Tests use a fixture-local editor configuration;
interactive editor proxy support is still pending.

GinLog reset actions now cover default/soft/hard/merge/keep modes. Tests assert
actual HEAD, index and worktree state rather than only command output.

GinLog lightweight tag creation and force replacement are implemented.
Annotated tag actions and the default tag alias now use the editor proxy.
Signed tag actions use the same proxy with Git signing configuration.

GinLog fixup and instant-fixup are implemented. Instant autosquash starts at the
selected parent (or --root), correcting the pinned double-parent traversal.
Amend/reword variants now use the editor proxy; instant variants remain pending.

GinReflog now uses the shared history display and implemented commit actions,
with separate default/persistent arguments and mapping settings. Its remaining
commit-action, format and UI audits follow GinLog.

GinStash now lists saved changes with apply/pop/drop, show/yank and automatic
refresh. Browse/echo, custom formatting, emoji/encoding and combined-diff show
navigation still need implementation or compatibility checks.

Shared echo actions now expose each implemented view’s selected candidate
metadata as compact JSON. Upstream uses indented JSON; exact field/display
compatibility remains part of the final action audit.

GinBrowse supports file/tree/home/commit URLs, explicit remotes, aliases, ranges
and permalinks. Provider routes were checked against deno-git-browse v1.0.1
(the minimum version referenced by pinned vim-gin). Full URL edge-case parity remains
pending. Browser opening uses vim.ui.open and was not launched by the tests.

Shared browse actions now support file/ref, commit, permalink and yank variants
in implemented candidate views. PR variants now use merge-message/ancestry lookup.

GitHub PR lookup recognizes standard merge messages, either directly or along
remote-default-branch ancestry. It uses local remote HEAD (fallback main) rather
than upstream’s network remote-show discovery. Squash/rebase-merged PRs without
matching messages are not inferred. Tests cover direct/containing merges and
missing matches without network access.

GinBlame now opens the three-pane attribution/content/detail layout. Its Git
line-porcelain reader retains per-line source metadata and physical/source line
maps; cursor movement updates details, preserving the last commit on intermediate
dividers. Tests exercise a subdirectory, a dirty working file, repeated commit
groups and detail selection. Commit selection now follows per-line historical
filenames and source positions, with parent selection when already viewing the
selected commit. Quoted filename decoding and failed-parent view retention are
tested. Back/forward history restores visited revisions, filenames and both pane
cursors; selecting a new commit discards forward history after the current entry.
Commit dividers use the Comment colors with strikethrough and refresh when the
colorscheme changes. A dedicated sign group preserves unrelated plugin signs.
Encoding/fileformat options now persist in blame URIs through reload and history.
A Latin-1/CRLF fixture verifies decoded source content while preserving UTF-8 Git
author metadata. Multibyte encodings, BOMs, Mac line endings and raw URI cmdargs
still need auditing. Emoji options and broader parser/UI parity checks remain. Source/attribution reload now
refreshes existing panes; unloading a pane removes its companions after the
operation settles so reload does not trigger cleanup. Tests cover all three
close paths and retention of an unrelated file buffer. Restoring missing panes
from an independently opened navigation URI remains unaudited.

Lua branch/traffic/worktree components now publish cached strings asynchronously
and emit debounced GinComponentPost events on changes. A generation check ignores
stale results after context changes. Tests currently prove ASCII/Unicode output
for a repository with diverged upstream history and the published worktree path.
Command-event refresh covers detached, unborn and no-upstream branches; leaving
a repository clears cached values. A controlled late Git response from a previous
repository cannot replace the new context; disabling generation guards makes
that regression test fail. Legacy Vimscript component function names are not
installed.

GinBuffer now forces Git color output by default and renders SGR attributes as
Neovim highlights. `++monochrome` skips forced coloring and persists on reload.
The processor fixture uses monochrome because uppercase conversion also changes
ANSI control sequences. Command-post binding belongs to candidate views in the
pinned source, not GinBuffer; the checklist has been corrected. Extended color,
attribute reset and Unicode byte-offset fixtures now verify rendered highlight
spans. Colorscheme changes restore generated groups using the current terminal
palette. Broader ANSI control-sequence and cross-view decoration parity remain
unaudited.

GinDiff now requests colored output and uses the shared ANSI renderer. The
`--no-color` Git flag persists on reload and disables forced colors, including
for text-transforming processors. Tests verify added-line colors and no-color
reloads alongside the existing navigation, fold and addressed-read coverage.

GinLog and GinReflog now force Git color output by default through the shared
ANSI renderer. Tests resolve parsed candidates back to real commits after colored
rendering/reload and verify `--no-color` suppresses highlight spans.

The asynchronous Gin command now supplies a Neovim RPC editor client via its
child environment. Git waits for buffer-local Apply/Cancel; Apply writes the
file and releases Git, while Cancel returns failure. A real commit fixture
verifies the edited message and committed content. The editor opener/disable
settings are supported. Unlike the pinned global-environment proxy, this stage
is scoped to asynchronous Gin children; synchronous calls, action/terminal
integration, askpass and client-disconnect lifecycle
audits remain pending. Cancellation is verified to reject the commit, clear the
draft message and retain staged content.

Editor QuitPre handling now asks whether to apply, or applies automatically with
g:gin_proxy_apply_without_confirm. Cleanup is deferred until the quit operation
finishes so it does not close a different tab. A real commit verifies automatic
apply-on-quit. Prompt acceptance and rejection are also checked against real Git
completion and staged state. A failed Apply write preserves the pending request
and modified buffer, and a later retry commits successfully. Whole-editor
shutdown still needs lifecycle coverage.

Asynchronous Gin children now receive an askpass launcher as well as the editor
command. Git credential fill verifies username/password exchange with masked
Neovim input using synthetic credentials and no network. The Unix launcher is
created with owner-only permissions and removed on editor exit; Windows launching
still needs verification. Interrupted prompts are tested to fail Git without
returning credentials. Editor and askpass disable settings are independently
verified. Global environment/terminal inheritance remains pending.

Lua gitcommit/gitrebase filetype plugins now supply the upstream Accept/Cancel
aliases, respecting existing commands and the disable option. A real commit
verifies Accept through the proxy's quit handling. The formatter check now
includes ftplugin Lua files.

Interactive rebase actions (rebase:i and rebase:i:x) now dispatch asynchronously
from branch and history views through the editor proxy. Completion runs checktime
and the usual command-post refresh. A history fixture edits the todo to drop a
commit and verifies resulting HEAD and worktree content. A branch fixture checks
interactive exec execution and rewritten ancestry. Broader conflict and
cancellation coverage remains pending.

The annotated-tag fixture verifies the edited message, tag object type and peeled
target commit. Signed force replacement is verified with an ephemeral SSH key,
including Git verify-tag and the peeled target. Other signing backends and
annotated-force-specific coverage remain pending.

History fixup:amend and fixup:reword now open editable fixup messages without
blocking Neovim. The amend fixture verifies the new commit message, staged file
content and unchanged parent relationship. Reword coverage verifies an unchanged
commit tree and retained staged content. Instant amend/reword now reuse the
root-aware autosquash implementation after a successful message edit. Real Git
fixtures verify replacement of the root message, preservation of descendants,
and amend content; cancellation preserves HEAD and the staged changes. Reword
with dirty state, autosquash conflicts, and other editor failures still need
broader coverage.

Branch and history merge actions now run through the asynchronous command proxy,
so Git can request an editable merge message. A no-ff branch fixture applies a
custom message and verifies both parents. Fast-forward branch/history fixtures
and divergent ff-only rejection verify completion and unchanged failure state.
Recovery fixtures now verify that editor cancellation preserves MERGE_HEAD and
staged merge content, and conflicts preserve the base/ours/theirs index stages.
Both paths finish through Gin commit and the proxy editor, with checks for the
message, both parents, final content, clean status and removed MERGE_HEAD.
Failed merges emit no success event; the completed recovery emits one.

History cherry-pick and revert actions now dispatch through the asynchronous
command proxy, including their mainline variants. Hook fixtures request both
credential fields through Git credential fill with terminal prompting disabled,
use isolated dummy responses, and check the resulting parent, tree and status.
They make no network requests. Ordinary pick/revert and mainline-one revert
fixtures also wait for the returned process and check its exit status.

Cherry-pick and revert recovery fixtures exercise real add/add and modify/delete
conflicts. They check operation markers, index contents, unchanged HEAD and no
success event after failure. Gin cherry-pick/revert --continue produces a child
of the original HEAD with the resolved content; --abort restores the original
files and HEAD. Both recovery paths clear operation state and emit the success event.

Bare-command fileformat decoding now preserves carriage returns when unix is
explicitly selected, matching the pinned separator behavior. Raw Git blob
fixtures cover ff/fileformat aliases, unix/dos/mac/default output and both
synchronous and asynchronous execution.

Filename expansion now resolves the first filtered path from diff and log
buffers, alongside revision/index edit buffers. Git-state fixtures stage through
% from both views with relative and absolute filenames containing spaces, and
verify that the second path stays unstaged. Log expansion currently uses paths
after an explicit -- separator; full URI and modifier interoperability remains
under audit.

Subdirectory fixtures now distinguish root/file from sub/file for diff and log
filters, verify reload output/history, then use the alternate-buffer # expansion
to stage only root/file. Relative filter paths remain repository-relative,
matching the pinned upstream; the same-named subdirectory file stays unstaged.

Log/reflog ++emojify now uses a vendored Unicode map derived from the pinned
upstream dependency @lambdalisue/github-emoji 1.0.0. Its source checksum and MIT
license are recorded under vendor/github-emoji. Conversion runs before ANSI
highlight span calculation and leaves unknown/image-only names literal.
Fixtures cover reload, opt-in behavior, commit selection, compound Unicode
sequences and overlapping name delimiters. Other emojify views/actions remain
pending.

GinBuffer accepts ++emojify and stores it in the URI for reload and addressed
reads. A colored Git-log fixture verifies the converted text, exact ANSI byte
span after conversion, and insertion between existing destination lines.

Show actions now include show:emojify and all four show:{opener}:emojify
variants in log, reflog, tag and stash views. Real-repository fixtures verify
the selected commit, converted message, window/tab counts and reload behavior
for every view/opener combination. Plain show actions retain their existing
behavior.

Tag and stash lists now accept ++emojify and retain it across reloads. Conversion
runs on display lines after candidate extraction, preserving original refs and
object IDs. Integration tests delete the selected annotated tag and pop the
selected stash after reload, checking remaining refs and restored file content.

GinBlame ++emojify converts attribution summaries and commit details while
leaving source lines unchanged. Its URI option propagates to companion panes
and history entries. The integration fixture verifies initial display, reload,
detail updates, commit navigation and backward history with literal emoji names
in source content.

Tag/stash lists now accept enc/encoding and ff/fileformat options, retaining
them in reload URIs and using the shared display decoder. Latin-1 fixtures
verify descriptions, buffer options and the original candidate targets through
tag deletion and stash pop. Candidate extraction continues to use raw Git
identifiers before display decoding.

Branch lists now retain enc/encoding and ff/fileformat options in their URIs
and decode display output through the shared buffer path. A Latin-1 commit
subject fixture verifies reload, buffer options and a subsequent switch to the
original branch and commit. Raw branch/worktree identifiers remain separate
from display decoding.

Status accepts enc/encoding and ff/fileformat, retaining the normalized options
in its URI while excluding them from Git flags. Display decoding follows raw
porcelain parsing. A fixture deliberately decodes a UTF-8 filename as Latin-1,
then stages it after reload and checks Git's NUL-delimited path and blob content,
verifying the original path remains the action target. Invalid-UTF-8
filesystem names could not be exercised on this macOS filesystem.

Lua filetype plugins now apply the pinned list-view display options for branch,
status, log, reflog, tag and stash: no list characters, spelling, wrapping,
folding or modelines; history/tag/stash cursorline; unlisted buffers except
branch. Each provides undo_ftplugin restoration. Six filetype tests verify
application and restoration with filetype plugins enabled.

Diff-fold setup explicitly enables folding so a diff/show window inherited from
a list view still builds usable folds. The diff regression fixture starts with
folding disabled; the existing tag-to-show test also exercises this transition.

Default choice/repeat mappings now include Visual mode in branch, log, reflog,
tag and stash views. Show Enter also includes Visual mode in the four history
and object views; branch switching remains Normal-only as upstream specifies.
Key-driven fixtures verify range capture and repeat against a new selection in
all five views, plus a two-commit visual show from log.

Command-buffer diff jumps now respect gin_buffer_disable_default_mappings
independently of gin_diff_disable_default_mappings, matching the pinned filetype
plugins. Fixtures exercise both switches in opposite states for GinBuffer and
GinDiff, checking all three default keys and retained Plug callbacks.

Diff header path decoding now processes C/octal escapes in one pass, avoiding
a second interpretation of escaped literal backslashes. A real diff fixture
uses backslashes before octal digits and an escape letter alongside Japanese
characters; its jump verifies the exact working-file path and line content.

Diff and blame now share a single Git C-quoted filename decoder. The blame
rename fixture includes literal backslashes before octal digits alongside tabs,
quotes and Japanese characters, and verifies both directions of history plus
source content. Diff-specific prefix/timestamp handling stays outside the
shared decoder.

GinDiff jump targets and fold labels now honor explicit no-prefix, src-prefix
and dst-prefix options, including reverse diffs. Four real Git fixtures retain
a genuine a/ directory and use custom prefixes containing pattern characters,
checking both fold labels and exact working-file navigation. A deletion fixture
also preserves /dev/null under a custom slash prefix and verifies index
navigation. Prefixes inherited from Git configuration and arbitrary GinBuffer
argv remain under audit.

GinTag now honors --format instead of overriding it with its internal metadata
format. The default display includes the creator date, matching the pinned
upstream format. Private ref/object fields retain action targets across custom
display formats, sorting and reloads; multiline displays map each line to its
ref and range actions deduplicate those refs. Real Git tests check exact display
and selected deletion. Custom parse-pattern settings remain under audit.

Tag records use a per-read boundary so NUL bytes and newlines in custom display
formats do not become action metadata. A regression fixture checks the exact
binary-containing lines after reload and verifies deletion of the selected ref.

Tag URIs now support addressed :read through FileReadCmd. Output generation is
shared with the tag view, while insertion reuses the command-buffer read path
for decoding, emoji conversion, marks and FileReadPost. Integration tests verify
destination options and content, no tag-view metadata installation, empty output
and failure without a success event.

Log, reflog and stash URIs also support addressed :read. These paths use the
requested Git arguments without adding view decorations or private parsing
formats, matching the pinned read implementations. Twelve integration cases
cover custom output, emoji conversion, encoding, insertion marks, destination
options, empty output and failed Git commands with no FileReadPost event.
