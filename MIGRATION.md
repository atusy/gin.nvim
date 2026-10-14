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

## Configuration audit: remaining parser overrides

The pinned command implementations expose four custom candidate parsers beyond
the globals listed in doc/gin.txt:

| Setting | Pinned source | Lua status |
| --- | --- | --- |
| `g:gin_log_parse_pattern` | `command/log/edit.ts`, `gatherCandidates` | Type validation implemented; custom matching not implemented; candidates are parsed from displayed commit headers. |
| `g:gin_reflog_parse_pattern` | `command/reflog/edit.ts`, `gatherCandidates` | Type validation implemented; custom matching not implemented; shares the Lua log candidate parser. |
| `g:gin_tag_parse_pattern` | `command/tag/edit.ts`, `gatherCandidates` | Type validation implemented; custom matching not implemented; candidate refs come from structured Git metadata. |
| `g:gin_stash_parse_pattern` | `command/stash/edit.ts`, `gatherCandidates` | Type validation implemented; custom matching not implemented; candidate refs come from structured Git metadata. |

Each upstream override is validated as a string and passed to JavaScript
`new RegExp`. Supporting arbitrary display formats through structured metadata
does not implement these overrides: they can change which rows match and which
captured identifiers become action targets. Lua/Vim regex syntax must not be
silently substituted and described as compatible. The pinned branch parser has
fixed expressions and no corresponding global override, so earlier mentions of
branch custom parse-pattern settings are not an outstanding public setting.

Recent file-action fixes apply persistent arguments through the command handlers
used upstream. Diff jumps deliberately keep the internal executor route. These
dispatch checks do not close the four parser overrides or the broader API/URI
compatibility audit. The completion checklist above remains unchanged.

## Execution-path audit

| Lua route | Live output | Proxy handling | Current deadline |
| --- | --- | --- | --- |
| `command.execute`, including `++wait` | Both Git channels | Editor/askpass environment and scheduled RPCs | None |
| `git.run` with progress for views and mutations | Stderr or both channels as selected by the caller | Editor/askpass environment and scheduled RPCs, including processors | Explicit caller timeout only |
| Patch and Chaperon panes | Through GinEdit/GinBuffer | Inherits those executors | Inherits those executors |
| Internal `git.run` queries | Captured | No automatic proxy setup; blocking wait | Explicit caller timeout only |
| Component `git.start` queries | Captured | Asynchronous callbacks; no automatic proxy setup | Explicit caller timeout only |

Remaining direct queries include repository discovery, browse URL/ref resolution,
diff merge-base lookup, branch color configuration, index-mode lookup and fixup
parent detection. Upstream also separates captured internal process execution
from its indicator executor (for example finder and component queries). This
inventory does not establish full compatibility for those queries. Manual
keyboard interaction during synchronous waits, custom indicator APIs and
the wider command/URI contracts remain open audit items.

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
that regression test fail. The six public Vimscript component function names
now delegate to these Lua implementations through minimal autoload wrappers.
An integration fixture evaluates an actual legacy statusline expression,
checks all six function results against a real diverged repository and verifies
refresh after switching branches. These wrappers require no Denops runtime;
internal component APIs and other legacy public APIs remain under audit.

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

GinStash now honors explicit --format while retaining private stash selectors
and commit IDs. Per-read record boundaries preserve embedded NULs and multiline
display text; range candidates deduplicate lines from the same stash. Real Git
fixtures filter to an older stash, reload, and verify pop:index restores its
worktree and index content while retaining the newer stash. Named pretty formats,
graph/patch output and custom parse-pattern settings remain under audit.

GinBranch honors --format while retaining local/remote ref identities, current
branch state and worktree metadata separately from display text. Tests cover
sorted selection after reload, multiline/NUL display, deduplicated deletion and
deleting the selected remote ref through a custom display. Default layout
alignment, other display flags and custom parse-pattern settings remain under
audit.

Diff fold prefix presets are published as g:gin#difffold#prefixes_ascii and
g:gin#difffold#prefixes_nerdfont, with the pinned glyphs and spacing. Lua config
can also use require('gin.difffold').presets. Integration fixtures select each
published preset and check the rendered fold label; partial configuration still
falls back to the ASCII values.

Shared action discovery now includes user-defined global and buffer-local
<Plug>(gin-action-...) mappings. Calls honor remapped aliases and callback
overrides, and custom Ex mappings receive the captured selection range. Tests
cover alias discovery, overridden callbacks, range propagation and restoration
after callback errors. Complete mapping/help customization parity remains under
audit.

Expression action mappings run through Neovim's mapping engine so their returned
key sequences execute with the captured action range. A callback-expression
fixture resolves another action and verifies the propagated selection.

Action help now reads effective mappings across modes, including global keys
and their buffer-local overrides. Reduced help retains explicitly bound detailed
actions, and aliases are listed as actions rather than mistaken for user keys.
The reduced-help hint uses the pinned bordered layout. Tests cover visual-only
shortcuts, global/local shadowing and alias presentation.

The full 308-case suite passes on official Neovim 0.10.0 and 0.10.4 macOS arm64
releases. These runs exposed and fixed compound blame filetypes missing their
Tree-sitter language mapping and older JSON encoding that escaped status path
separators. The test harness now isolates runtimepath and uses the running
installation's bundled parsers, avoiding unrelated system-parser ABI conflicts.
This verifies the exercised behavior at the documented minimum version; the
remaining migration checklist still applies.

Commands with default/persistent argument settings now share their expansion
path and validate both settings as lists of strings, matching upstream even
when explicit arguments replace the defaults. Invalid booleans, dictionaries
and list elements fail with the setting name before opening a view. A real
status fixture verifies persistent worktree selection, explicit-argument
precedence and unchanged configuration arrays.

Asynchronous Gin commands now echo live stdout/stderr without adding progress
chunks to message history. The Git runner retains complete binary-safe output
for final reporting and processors. The indicator restores command-line height
after idle output and restores options after the last concurrent command closes;
silent commands suppress it. Tests gate a real Git alias until progress is
observed, verify final output/events, and cover silent and concurrent lifecycles.
Streaming for synchronous commands and buffer reads and custom indicator APIs
remain under audit.

Progress display retains incomplete UTF-8 and SGR escape sequences between
chunks, independently for stdout and stderr. Tests cover every byte boundary of
two-, three- and four-byte characters, interleaved streams, and EOF handling for
truncated characters/escape sequences. Non-UTF-8 stream encodings and other
terminal control sequences remain under audit.

The test harness clears inherited Git editor/sequence-editor and askpass
variables so fixture-local configuration cannot accidentally invoke a user's
running proxy. A synchronous failed-editor fixture verifies that the index is
preserved and no success event is emitted. A separate headless input probe
confirmed that vim.wait does not process normal editor input, so merely pumping
scheduled RPC callbacks would not establish usable ++wait editor integration;
that integration remains pending.

Native Neovim help now documents the implemented commands, action mappings and
Lua selection API, configuration, proxies, components and events. All 29 tags
were opened successfully with isolated runtimes on Neovim 0.10.0 and the current
development build. This is a guide to the implemented subset, not a claim of
complete upstream help/API compatibility. README statements about colors,
Blame emoji rendering and minimum-version validation were brought up to date.

Blame detail emoji conversion now follows the pinned detail.ts behavior: only
the first message line is converted. Author metadata and later message lines
remain literal. A real commit fixture checks full detail output on initial
open, cursor-driven update and reload, alongside the existing history fixture.

GinBlame now expands and validates g:gin_edit_default_args and
g:gin_edit_persistent_args, matching the pinned command's shared edit settings.
A repository fixture verifies default revision selection, explicit-argument
precedence, persistent opener/encoding and unchanged configuration arrays.
The pinned command tree has 12 fillCmdArgs call sites; each now has a matching
shared argument-expansion call in Lua (log/reflog share a module). This closes
the command-setting wiring audit, not the remaining command behavior audits.

The gin-diff Lua ftplugin now loads Neovim's bundled diff ftplugin, as the pinned
upstream does. It inherits modeline suppression, comment settings and the
runtime's undo behavior rather than duplicating those settings. A filetype
fixture checks application and undo; diff fold setup and jump mappings remain
owned by their existing Lua modules.

Blame source and attribution windows now enable winfixbuf, as in the pinned
Blame ftplugins. A real view fixture verifies that ordinary :edit cannot replace
either pane and that protection survives reload, commit selection and history
navigation. Tests reset this window-local setting after forced teardown.

Worktree discovery now shares ordered filesystem candidates with asynchronous
components. For a file symlink outside a repository, both try its real target's
parent before falling back to cwd; a repository containing the link still wins.
This matches normSuspect in the pinned worktree implementation. A real symlink
fixture verifies both APIs before and after initializing a repository around
the link. Existing stale-result component tests cover asynchronous invalidation.

Worktree discovery also decodes repository roots from the eight Gin URI schemes
listed in the pinned GIN_BUFFER_PROTOCOLS, without relying on b:gin_worktree.
The shared candidate resolver serves direct commands and async components.
A fixture covers each scheme with encoded fragments and no cached buffer data,
resetting component context between cases so stale values cannot pass the check.
Tag/Blame URI discovery without buffer metadata remains outside this pinned
protocol list and is not claimed by this audit.

Explicit :edit ++enc/++encoding and ++ff/++fileformat now override URI decoding
settings for the current read in shared output views and GinEdit. A byte-level
fixture opens UTF-8/CRLF data with Latin-1/DOS defaults, reloads it as UTF-8/Unix,
and verifies both text and options before returning to the unchanged URI
settings on ordinary reload. Blame's separate decoding path and other builtin
read options remain under audit.

Blame source and attribution reloads now use the same explicit read-option
precedence. A UTF-8/CRLF fixture reloads each pane with encoding/fileformat
overrides, verifies both synchronized buffers and literal UTF-8 author metadata,
and returns to the unchanged URI defaults on an ordinary reload. Other builtin
read options and complete decoding compatibility remain under audit.

ANSI decoration groups now use the pinned GinColor naming order for indexed/RGB
foreground and background colors plus bold, inverse, italic, strike and
underline attributes. Dim text continues to use Comment. A regression fixture
checks the exact public group names; existing fixtures verify color attributes,
UTF-8 byte spans, reset handling and restoration after ColorScheme. Complete
ANSI sequence compatibility and read-event behavior remain under audit.

A read-event audit traced the pinned buffer/edit call chain into
[denops/std v7.0.0 buffer.ts](https://github.com/vim-denops/deno-denops-std/blob/v7.0.0/buffer/buffer.ts).
Its replace/concrete helpers do not emit BufReadPost: concrete installs cache
store/restore handlers, while replace overwrites lines and removes the excess.
No extra BufReadPost emission was added on this evidence. The upstream import
uses a major-version range, so this inspection alone does not establish the
behavior of every allowed dependency version.

A real status refresh fixture stages a path while the same view is visible in
two windows, then verifies updated status text and both cursor positions. The
existing implementation already passes; no buffer-replacement change was needed.

GinEdit URI insertion now applies explicit :read encoding/fileformat overrides,
matching the pinned edit/read.ts option path. The fixture reads UTF-8 bytes with
an explicit Unix format over Latin-1/DOS URI defaults, checks addressed insertion
and marks, and verifies destination options plus literal ANSI bytes are retained.

Gin command completion now retains an eventignore=all snapshot from dispatch,
matching the pinned bare-command executor. Restoring eventignore while Git is
running no longer causes an unintended GinCommandPost. A real asynchronous Git
config command verifies successful mutation and completion without the event;
existing ordinary-command fixtures still require successful event delivery.

Status display now quotes control-bearing paths before ANSI decoration parsing.
An ESC sequence in a filename previously disappeared as if it were a Git color
code. A real filename fixture verifies escaped display, staging through the
selected action with the original path bytes, and unchanged working content.
This retains the current JSON-style display quoting; complete upstream quoting
and Git-config display compatibility remain under audit.

Status parsing now separates color escapes in the two status columns from raw
filename bytes. color.status=always previously corrupted selected paths. The
renderer retains Git's configured status colors while actions use plain status
codes and untouched filenames. Fixtures verify a custom blue/bold untracked
style, staging and refreshed index status, plus control-bearing filenames with
forced colors enabled. Default color forcing and other display flags remain
under audit.

GinStatus now enables color.status=always for its display command, following the
pinned status-to-buffer executor path. Repository configuration is unchanged.
A fixture sets color.status=never and a custom untracked color, then verifies
colored extmarks, plain visible text and unchanged config on open and reload.
The full status suite consequently exercises action parsing with default colors.

GinStatus does not force --untracked-files on every URI read: an explicit URI
without visibility flags honors Git configuration and default directory grouping.
The command entry point, however, supplies --untracked-files by default in the
pinned status/command.ts before the URI reaches status/edit.ts. The earlier audit
of only the reader missed this distinction. Lua now includes that command default
in the URI, displaying individual untracked files even when Git configuration
hides them. Separate fixtures cover flag-free URI reloads, command defaults,
explicit no/normal/all overrides, and staging the selected nested file.

Short status flag coverage now checks -u, -uno, -unormal and -uall on initial
open and URI reload, plus the -- boundary before a literal -uall filename.
Staging that filtered selection affects only the literal file. These cases
already pass with the existing parser; no command implementation change was
needed. The pinned status flag list and denops/std v7.0.0 short-flag parser
were inspected during this audit.

GinBranch now enables color output before user flags so %(color:...) atoms in
custom formats render as highlights, as in the pinned buffer executor path.
A fixture checks color spans across reload, selection-driven branch switching,
explicit --no-color and unchanged repository configuration. Native default
branch layout/color parity remains under audit; metadata stays independent of
the formatted display.

GinTag color coverage now checks its pinned --color=never default even with
color.ui=always, explicit --color=always and --no-color, sorted custom formats
across reload, and deletion of the selected tag. The existing implementation
passes without changes; unlike GinBranch, the pinned tag executor explicitly
opts out of forced color settings. Repository color configuration is preserved.

Gin ++wait now shares the asynchronous Git execution path, including editor
and askpass environment, live output, and postprocessing. Its wait processes
scheduled callbacks and RPC requests instead of blocking them; Git and processor
errors still propagate to the caller without a success event. Fixtures verify
a real commit accepted through the editor proxy while waiting and a Git command
that requires receipt of its progress output before it can finish. User-driven
interactive editor input during ++wait remains unverified.

The default GinBranch display now includes Git's + marker and parenthesized
path for branches checked out in another worktree. The existing move fixture
compares a filtered row with native branch -vv output before and after reload
and after moving the worktree, including upstream tracking information. It
also checks that the current branch omits its own worktree path. Action targets
continue to come from the same structured Git record as the display. Column
alignment and default branch color parity remain pending.

Default branch rows now pad names to the widest selected name before the commit
column. A native branch -vv comparison covers unequal ASCII names, Japanese
wide characters, filtered results and reloads. The width is computed from the
same Git response used for action metadata; custom formats retain their own
spacing. Remote prefixes, aliases, detached HEAD labels, unusual character
width rules and default colors still need display parity checks.

Default branch listings now add the remotes/ prefix in all-ref mode and show
symbolic remote refs as aligned name -> target rows. A native branch -vv
comparison covers --all/--remotes, -a/-r, mixed flag ordering and reloads.
Metadata and target yanks retain the underlying origin/name target independent
of the display prefix; custom formats remain unchanged. Detached HEAD labels,
unusual character width rules and default colors remain under audit.

GinBranch now applies --abbrev and --no-abbrev to its commit metadata atom,
so the default commit column and yank:commit match the requested length.
A native branch -vv comparison covers detached HEAD labels, core.abbrev,
explicit lengths, zero/full length, a below-minimum length, flag ordering and
reloads. Git still resolves abbreviation uniqueness. Ordinary detached labels
already matched; rebase/bisect labels and detached-row actions remain unaudited.

The default GinBranch display now renders current/local/remote/worktree branch
colors, upstream names and linked-worktree paths. Git config --get-color
interprets each used color slot, with Git's default palette as fallback; values
are cached for the current read only. Native-output comparisons verify exact
highlight ranges with custom colors and attributes, aliases, reloads, forced
default color despite color.branch=never, and explicit never/auto/no-color.
Configuration is unchanged. Other native formatting flags and uncommon color
settings still require audit.

GinBranch now passes the pinned -vv default to Git and applies subsequent
verbosity flags to its display. --no-verbose hides commit/details and padding;
a following --verbose includes commits and ahead/behind status; -vv restores
upstream names and linked-worktree paths. A native-output fixture covers all
three modes, reloads and selected branch yanks with a linked branch ahead of its
upstream. Structured action metadata remains available in every mode. Combined
short-option spellings and column-layout flags remain to be checked.

Successful GinEdit :read operations now emit FileReadPost for empty blobs too,
consistent with this port's nonempty GinEdit and generic buffer read paths.
The early empty-output return previously skipped that notification. A fixture
checks the event's URI and observed unchanged text, an unchanged modified flag,
and no additional event for a missing index path. This is native read-event
consistency within the Lua port, not a claim that the pinned Denops append
implementation explicitly emits the same event.

The shared echo action now uses two-space JSON indentation, matching the pinned
action/echo.ts presentation. Formatting operates on encoded JSON and leaves
quoted content untouched. A fixture verifies exact nested output with escaped
quotes, backslashes, punctuation, newlines, booleans, null and an empty object;
decoding the output recovers the original candidates. Empty selections retain
the existing [] representation.

Cached/HEAD file edit actions now dispatch through GinEdit's command handler,
as the pinned action/edit.ts does, so persistent encoding and other command
arguments apply. A fixture opens a Latin-1 index/HEAD file through both actions,
checks decoding and rejects an opener duplicated by persistent and action
arguments. The selected path is made absolute before command expansion so a literal
% prefix remains a filename. Other action-to-command dispatch paths, including
diff, still need the same configuration audit.

File diff actions now dispatch through GinDiff's command handler so persistent
flags and decoding/processor options apply. A real-diff fixture verifies
--word-diff=plain for local, cached, HEAD and smart selections, with distinct
HEAD/index/worktree contents and a literal % filename under a subdirectory.
It checks full output across reloads, selected-path isolation and rejection of
duplicate openers. Other direct action open paths remain under audit.

Patch file actions now dispatch through GinPatch's command handler, matching
the pinned action/patch.ts route. Persistent pane/decoding arguments therefore
apply before the explicit action arguments. A status-action fixture verifies
that persistent ++no-head yields two panes, a duplicate opener is rejected,
and applying one hunk changes only that part of the
index while preserving the working file. The path remains anchored to the
selected repository even when invoked from a subdirectory.

Chaperon file actions likewise dispatch through GinChaperon's command handler,
following action/chaperon.ts. A real merge-conflict fixture applies persistent
++no-ours through the both action, rejects a duplicate opener,
resolves from the remaining theirs pane, then checks
that only explicit staging clears unmerged index entries. The resulting staged
blob is asserted. This completes the direct file edit/diff/patch/chaperon
configuration-path fixes; other action families remain under audit.

Branch log actions now dispatch through GinLog's command handler so persistent
history filters apply, following action/log.ts. A fixture selects a %prefixed
branch behind the current branch, applies --max-count=1, verifies the exact
selected commit across reloads and checks duplicate-opener rejection. Named
branches are passed as full refs to avoid Vim filename/option expansion;
detached display labels use their recorded commit instead.

Show actions from log/reflog, tag and stash views now retain GinBuffer's
gin-buffer filetype instead of forcing git. This matches the pinned show action,
which supplies diffjump/difffold but no filetype override, and allows the same
FileType customizations as a normal GinBuffer. Existing opener/emojify fixtures
now assert the filetype on open and reload across all four source views; their
content and window-layout checks remain in place.

Diff-jump configuration dispatch was checked separately from file actions.
The pinned feat/diffjump/jump.ts calls the internal edit executor rather than
edit:command, so GinEdit persistent arguments do not apply. A fixture confirms
the existing Lua path retains UTF-8 decoding and the current tab despite
persistent Latin-1/tabedit settings, then jumps back to the correct working
file. No production change was needed for this distinction.

Lua syntax files now provide the pinned tag, stash and reflog highlight groups
and default links. Native syntax-engine tests identify hashes, tag names/dates/
subjects, stash types/branches and reflog selectors/actions/decorations. Stash
branch and reflog action matching use chained groups/highlight offsets so the
fields are actually highlighted in Neovim; current_syntax is set after clearing
definitions. Custom formats outside the native layouts are not inferred by
these rules. The syntax directory is included in formatter checks.

GinBlame navigation now has a Lua syntax file for the pinned line-number,
relative-time, author and summary groups. It retains the specified GUI/terminal
time and author colors and bold author text. Syntax-engine fixtures cover
just-now, past and future relative times, names with spaces, and highlight
attributes. Divider signs continue to use the existing independent renderer.

Blame navigation highlight definitions now share the existing ColorScheme
refresh hook with the divider. A real colorscheme reload reproduced missing
time/author colors; default definitions restore them while respecting a theme's
explicit author style. Additional lifecycle fixtures verify list default links
survive colorscheme reload and user-defined tag colors survive syntax reload.

GinBuffer buffer reads now display stderr progress while Git is running, matching
the pinned `command/buffer/edit.ts` executor's null stdout indicator and default
stderr indicator. A real Git alias waits for acknowledgement from the displayed
progress before exiting, proving live delivery rather than a final-output echo.
The fixture also checks ANSI removal, buffer-only stdout and restored editor
options. Git failure/timeout cleanup has a separate check.
These reads retain the existing process timeout and processor behavior.

The pinned bare and buffer command parsers do not expose custom indicator names
as command options; `stdoutIndicator` and `stderrIndicator` are internal executor
arguments. This change covers the default GinBuffer edit/reload route only.
FileReadCmd insertion and other buffer executors still need streaming audits;
custom executor APIs remain unported.

FileReadCmd insertion through `gin://` now streams both stdout and stderr, as
the pinned `command/buffer/read.ts` uses the executor's default indicators for
both channels. A Git alias waits for both channels to be displayed before it
finishes. The fixture verifies stripped stderr colors, processed stdout inserted
at the requested address without stderr contamination, and restored editor
options. Buffer edit/reload continues to display stderr only. Other executors
and custom indicator APIs remain under audit.

GinEdit blob display and FileReadCmd insertion now stream stderr only, matching
the null stdout indicators in the pinned `command/edit/edit.ts` and
`command/edit/read.ts`. Real Git trace output verifies delivery on both paths
without echoing blob contents, while asserting the loaded content and restored
editor options. Index writes and other executors still need a streaming audit.

Diff, log, reflog, branch, tag, stash and status buffer reads now display stderr
through the same progress lifecycle. Their pinned edit executors all delegate
to `command/buffer/edit.ts`, which defaults to stderr-only progress. Seven real
Git trace fixtures verify the corresponding commands are displayed, listing
payload stays in the buffer, and editor options are restored. Shared diff/tag
output helpers take an explicit progress option so their FileReadCmd paths keep
their existing behavior pending the separate insertion audit.

FileReadCmd for diff, log, reflog, tag and stash now streams both output channels,
matching their pinned delegation to `command/buffer/read.ts`. Five real Git
fixtures check both progress channels, insertion at the requested address and
absence of trace messages in inserted text. Tag insertion now requests only the
display format, without candidate metadata, so private NUL-delimited records
cannot leak into progress. Buffer display still obtains metadata for actions.

Blame initial loads, history visits and commit-detail reads now stream stderr,
matching the pinned blame edit/detail executors' null stdout indicators. A real
Git trace fixture checks initial blame/detail execution and cursor-driven detail
updates without echoing porcelain or commit-body output. It also verifies the
selected commit, three-pane layout and restored editor options. Existing blame
navigation, reload and failure fixtures exercise the same progress lifecycle.

Cursor-driven blame detail updates now honor the pinned detail executor's
`throwOnError: false`. A missing commit reports Git stderr and replaces stale
details with the empty output instead of raising from CursorMoved. The fixture
temporarily moves a real loose commit object, checks the cleared detail and
unchanged source pane, then restores it and verifies another selection displays
the correct commit. Blame generation itself still fails on invalid revisions.

Git and processor exceptions and Gin wait/asynchronous error reports now remove
SGR color sequences, following the pinned executor's ANSI-free error messages.
Four real-process fixtures reproduce colored errors and check plain reporting;
unchecked Git/processor results retain the original stderr bytes and exit code.
This covers SGR color removal, not the remaining general ANSI/CSI audit.

CSI removal now uses the grammar from `lambdalisue/deno-ansi-escape-code`
`v1.0.0` (`csi.ts`, `parser.ts`), the dependency family imported by the pinned
upstream. Shared stripping covers plain output, insertion, errors and progress;
the decoration parser removes non-SGR CSI without changing the active colors.
Fixtures cover erase/cursor/private/intermediate sequences, every streaming byte
boundary and UTF-8 highlight columns. Non-CSI escapes and unmatched sequences
remain literal, as in that parser. This does not establish complete SGR attribute
or terminal-emulation parity.

The SGR attribute audit now explicitly covers the five non-color styles rendered
by upstream `highlightExprFromSgr`: bold, italic, underline, inverse and strike.
Each has a runtime highlight assertion for activation and its independent reset
while retaining foreground color. Further fixtures verify dim maps to Comment,
intensity reset clears both dim and bold, and blink/conceal/unknown codes leave
supported styling intact. Upstream parses blink/conceal but does not render them.
These seven characterization cases pass without production changes; malformed
and compound-reset sequences still need separate compatibility decisions.

GinEdit index writes now stream stderr from blob filtering and index updates,
preserving the progress exposed by upstream's `git add` write executor. The Lua
implementation continues to use hash-object/update-index so it never temporarily
overwrites the working file; plumbing stdout (blob IDs) is not displayed. A real
required clean filter waits for its progress to be displayed before proceeding.
The fixture checks transformed index content, unchanged working content, no blob
or hash echo, cleared modified state and restored editor options.

Shared file mutation actions (add/rm/restore/stash) and status stage/unstage paths
now stream both Git output channels, matching upstream's bare-command dispatch.
Real required clean-filter fixtures independently cover `stage` and `add`, waiting
for displayed progress before completing and asserting transformed index content,
unchanged working content and restored editor options. Existing action fixtures
continue to validate selection and resulting Git state. This streaming change
does not close the wider action executor/proxy compatibility audit.

Branch mutations, tag mutations and stash apply/pop/drop now stream both output
channels through their existing command paths, including worktree removal before
branch deletion. Three real Git trace fixtures cover branch switching, tag
deletion and stash dropping, asserting progress independently of final messages,
the resulting refs and preserved working-file contents. Other action execution
semantics remain subject to the wider command/proxy audit.

The remaining synchronous log/reflog mutations now stream both output channels:
switch, reset, lightweight tags, shared branch operations, fixup commits and
instant autosquash. Real trace fixtures independently cover Log and Reflog soft
reset, proving progress is delivered before final echo and checking HEAD moves
to the selected commit while index and working content remain intact. Existing
log action fixtures validate the other mutation results; command/proxy behavior
beyond streaming remains under audit.

Synchronous executions that service progress now inherit the configured editor
and askpass proxy environment, as upstream installs those overrides before Git
execution. Explicit per-call environment entries remain authoritative and proxy
disable settings are respected. A real `git credential fill` regression exposed
missing proxy variables; fixtures now cover masked credential responses, askpass
opt-out and an actual commit completed through the editor Apply command. The
same merged environment is passed to output processors. Manual keyboard-driven
editing while a synchronous call waits remains unverified.

Synchronous output processors now use the same scheduled-event wait as the Git
process. A real credential-fill processor reproduced an unanswered askpass RPC,
a nil timeout result and a stranded test client under SystemObj:wait. The new
fixture passes Git-produced credential input through the processor and verifies
both masked prompt responses in its returned output. Processor output remains
captured rather than streamed, matching the pinned postprocessor executor.

Gin's own output processors now receive the same proxy environment as the Git
process. Separate real credential-fill fixtures reproduced missing askpass
variables in both `++wait` and asynchronous commands and now verify successful
prompt responses through the processor output. This closes the missing
environment path identified by the execution inventory above.

Implicit 30-second deadlines have been removed from Git and processor launches,
matching the pinned process/executor implementations. Explicit Lua-call timeouts
remain supported, including the existing real timeout-failure fixtures. Launch
boundary tests run real Git/processors and verify no default deadline is passed.
Separate long-running checks completed a Git alias after 31.02 seconds and a Gin
output processor after 31.32 seconds. These slow checks are kept outside the
routine suite; the current execution table and help reflect the new policy.

The public Lua `gin.util.expand(expr)` now supplies the filename-expansion
utility corresponding to upstream `gin#util#expand`, and command argument
expansion uses it. Fixtures cover native filename modifiers, edit/diff/log file
resolution, single-path diff fragments and views with no usable file path.
Lua log URIs retain their argv representation, resolving paths after `--`.
Malformed URI data is contained rather than raising from expansion. A minimal
autoload wrapper also supplies `gin#util#expand`; URI-format compatibility
remains a separate audit.

The public Lua `gin.util.worktree([path])` now corresponds to upstream
`gin#util#worktree`, sharing the existing worktree discovery implementation.
The API fixture checks current-view context, an explicit subdirectory, failure
without fallback for a missing explicit path, and string argument validation.
Existing discovery fixtures cover linked worktrees and symlinks. The public
`gin#util#worktree` wrapper delegates optional arguments to the same Lua API.

The public Lua `gin.util.reload([bufnr])` now supplies the asynchronous reload
utility corresponding to upstream `gin#util#reload` and denops std v7's
buffer reload helper. It runs `:edit` in the current or another visible buffer,
restoring the original window, and coalesces hidden-buffer requests into one
nested, one-shot BufEnter handler. Modified buffers retain their edits and
report errors through `vim.notify`; wiped buffers are skipped. Five fixtures
cover asynchronous GinStatus refresh, visible-window focus, hidden-buffer
coalescing, unsaved changes and a buffer wiped before execution. The public
`gin#util#reload` wrapper captures the current buffer when omitted and delegates
to this Lua implementation.
The handler is explicitly removed before `:edit`: Neovim 0.10 otherwise
re-enters a Lua `once` callback during the nested BufEnter event. The same five
fixtures pass on the minimum supported Neovim 0.10.0.

Legacy utility API fixtures verify filename expansion with quotes, spaces and
Unicode, current/explicit worktree discovery including a missing-path error,
and asynchronous current/hidden-buffer reloads. Argument values cross the
Vimscript/Lua boundary as data rather than interpolated expressions. These
wrappers do not restore any dependency on Denops.

The log/reflog candidate parser now requires the ASCII word boundary used by
the pinned JavaScript parser, rather than accepting any non-hex character.
For example, `%H_suffix` display rows no longer become actionable commit IDs.
A real Git fixture verifies that a reset action on such a row leaves HEAD
unchanged. This fixes the default boundary rule; custom regex overrides remain
open in the configuration audit above.

Reflog candidates now use the pinned reflog rule, which starts at column one,
instead of stripping graph/header prefixes as the log parser does. A real
`GinReflog --format` fixture includes an indented parent hash and verifies both
the exact selected entries and that resetting the indented row leaves HEAD
unchanged. The view is identified by its URI, so changing its filetype does
not change action targets.

The remaining default history-header rules now follow the pinned parser:
hexadecimal captures have no minimum length, and log `commit` headers require
exact spaces around optional `+`, `-`, `=`, `<` and `>` markers. The new
`tests/test_log_parser.lua` fixture checks 24 positive/negative rows including
graph prefixes, short captures, invalid spacing and non-ASCII word boundaries.
An additional local audit evaluated the actual pinned JavaScript log/reflog
regexes against 12,210 generated rows, then compared both Lua candidate modes:
all 24,420 comparisons matched. This audits the default expressions on those
inputs, not arbitrary custom JavaScript regular expressions.

Stash action candidates now expose the pinned fields: `stashRef`, numeric
`index` for numeric selectors, and `commit` containing the stash reference.
The `echo` action reports this shape, and shared show/browse actions receive
the reference rather than the stored object's hash. Apply/pop/drop and yank
continue to use that same selected stash reference. Structured per-row Git
metadata remains available internally for custom and multiline displays;
this change does not close the custom parse-pattern audit.
A real stash-show fixture additionally checks the selected reference in the
show argv and diffjump URI parameter, and the selected stash's combined-diff
content. Combined (`@@@`) hunk jumps are unsupported by both the pinned
diffjump parser and the Lua parser; this fixture does not claim to test them.

Log/reflog `GinCommandPost` bindings now call the public asynchronous reload
utility, as pinned `bare/command.ts` does, instead of reading buffers directly
inside the event. Hidden views defer Git execution until entry and use normal
`:edit` handling when reloaded. A real log fixture verifies that the hidden
view retains its old contents until BufEnter and then shows the new commit.
Branch/tag/stash/status now use the same path, including status refreshes from
file-write events. Thirteen integration fixtures cover all six listing types
while hidden or visible in another window, asynchronous dispatch, restored
focus and a real file write. Existing action tests await scheduled refreshes
before inspecting view contents or issuing a second action on the new rows.
Reload also saves/restores each displaying window's view: normal `:edit` resets
positions before Lua replaces the contents, so the existing multiple-window
status cursor regression remains covered. Broader reload/URI compatibility
is not established by these fixtures.

`GinCommandPost` now follows the pinned 100ms trailing debounce. A new success
replaces the previous timer; a generation check also rejects an older callback
already queued on the main loop. A fixture verifies that one completion burst
publishes one delayed event and a later burst publishes another. `++wait`
still returns after the command/processor finishes, before this deferred event.
The internal pending-state query lets tests wait for actual notification
completion and drain scheduled reloads before inspecting or deleting fixtures.
Broader reload/URI contracts remain subject to the migration audit.

Bare or empty GinBuffer `++diffjump` now resolves to HEAD/HEAD^, matching the
pinned buffer commitish map. Previously a bare option became the literal
revision `true`, while an empty URI value could select the index. The fixture
exercises both option spellings through URI reload and verifies old/new jumps
against actual parent/current file contents and immutable GinEdit revisions.

The shared `++option` parser now stops extracting options at `--`, preserving
that separator and subsequent arguments. This matches denops std v7's
`argument/opts.ts`, used by the pinned command handlers. A real Git fixture
stages files named `++unknown`, `++wait` and `++worktree=elsewhere`, checking the
exact NUL-delimited index paths. Filename placeholder expansion remains active
after the separator, as upstream normalizes arguments before parsing options.

Repeated `++option` names now fail before executing Git, matching denops std
v7's option parser. This also applies when a persistent option collides with
an action's explicit option. Earlier fixtures incorrectly treated last-wins
opener precedence as compatible; edit/diff/log/patch/chaperon action fixtures
now verify the duplicate error, then retain their content and Git-state checks
with non-conflicting persistent arguments. Repeated Git flags and different
option aliases are outside this same-name validation.

File edit/diff/patch/chaperon actions, branch-log actions and shared browse
actions no longer inject an extra `++worktree` argument. The pinned action
dispatchers rely on buffer worktree discovery instead, allowing the destination
command's persistent `++worktree` setting to apply without an artificial
duplicate. Existing real-Git action fixtures now include that setting alongside
encoding, diff/history filters or pane options; browse fixtures verify the
resulting selected-path and selected-commit URLs. Explicit duplicate openers
still fail, and file paths remain anchored to the selected buffer's repository.

GinDiff now preserves repeated Git flags rather than overwriting earlier values.
The pinned command uses denops std v7's array-valued flags and buffer parameters;
the Lua URI query now likewise stores repeated keys in their original value
order and restores them on read. A real Git fixture combines `--diff-filter=M`
and `--diff-filter=A` and checks both modified and added file diffs against Git,
including a buffer reload. This does not establish legacy URI-format parity or
complete short-flag parsing parity; those remain part of the migration audit.

GinDiff now separates each short flag's name from its attached value, matching
denops std v7's flag representation. Previously `-U5 -U0` became two distinct
URI keys and sorting reversed their effect. A real Git fixture verifies zero
context for both `-U5 -U0` and the equivalent parsed spelling `-U5 --U=0`, before
and after reload. Reverse diff jumps recognize the normalized `R` key while
retaining support for existing Lua URIs with `-R`. General malformed-argument
and legacy URI compatibility remain unverified.

GinDiff also retains the first-occurrence order of distinct flag names through
URI formatting and parsing. Sorting keys had reversed the effect of
`--unified=5 -U0`; a real Git fixture checks that ordering and its inverse,
including reloads. Repeated values stay grouped under their first-occurring
key, as in the pinned denops std parser/formatter. Lua callers supplying a flags
map can provide `flag_order`; maps without it retain deterministic sorted keys.
This preserves command semantics without claiming legacy URI syntax parity.

Diff folds and jumps now use the final value of repeated `--src-prefix` and
`--dst-prefix` flags, as Git does. Passing their newly preserved value arrays
directly to path parsing had left the display prefix attached to actual paths
and mislabeled ordinary modifications as renames. The real-file prefix fixture
now covers repeated values and verifies both the folded label and the contents
of the file reached by a jump.

Diff path decoding now applies `--no-prefix`, `--src-prefix` and `--dst-prefix`
in their saved flag order. Previously the presence of `--no-prefix` always
overrode explicit prefixes even when Git applied those prefixes later. Real
file fixtures cover both complete overrides, each one-sided override and a
reverse diff; they assert folded path labels and the contents reached by jumps.

The public `gin#difffold#foldtext()` entry point now delegates to the Lua fold
renderer. That renderer also accepts ordinary diff buffers, using standard
`a/` and `b/` prefixes when no Gin URI parameters exist. A real Git fixture
evaluates the legacy foldtext expression in both GinDiff and an unnamed buffer
containing the same patch, checking the path and added/deleted line counts.
Existing fixtures cover the published ASCII/Nerd Font presets and overrides.

The legacy fold preset variables also autoload before `plugin/gin.lua` runs.
They previously existed only after plugin initialization, breaking Vimscript
startup settings that select a preset. An isolated Neovim process started with
`-u NONE` reads both presets through Vimscript, verifies all four symbols and
asserts that the plugin remains uninitialized. The values come from Lua's
existing preset tables rather than a second implementation.

The built-in `gin#indicator#echo#{open,write,close}` entry points now delegate
to Lua. They synchronously display line arrays, preserve whitespace, ignore
empty/unopened writes and retain the pinned backend's ID-independent reference
counting. Native byte streams and legacy echo calls share one display-state
lifetime; tests verify restoration only after the final user closes, including
a mixed legacy/native session. Legacy-only opens preserve `more`, while native
stream opens continue disabling its prompt.

Progress-enabled `gin.git.run` now accepts independent `stdout_indicator` and
`stderr_indicator` names, including the built-in `echo` and `null` backends.
Named backends call the pinned `gin#indicator#{name}#{open,write,close}` API with
distinct channel IDs. Real Git fixtures verify ANSI-free displayed lines while
retaining original captured bytes, null suppression and nonzero Git results.
Backend open/write/close failures reach the caller after cleanup; a failure
opening stderr also closes stdout before any Git process starts. Existing raw
stdout listeners remain active when stdout progress is not selected. The
broader internal executor API remains subject to audit.

`gin.command.execute` now also accepts `stdout_indicator` and `stderr_indicator`
for its asynchronous and `++wait` paths. Both default to echo, while silent
execution starts neither backend. Paired channels close together even if a
backend fails. Integration fixtures verify both execution modes, preserving
captured output and callback completion; backend failures report through the
appropriate synchronous/asynchronous route without launching a processor or
publishing GinCommandPost. The original process-launch and interruption errors
retain priority if indicator cleanup also fails.

The URI reader now recognizes the pinned denops std semicolon parameter format
and fragments without Lua's trailing marker, alongside existing Lua URIs. Its
legacy decoding follows the staged percent decoding and form-query convention
used by denops std v7. Real GinEdit fixtures verify immutable revision reads and
reloads, plus index writes without worktree changes. The index fixture includes
escaped semicolon/percent/hash characters in the repository name and a fragment
with spaces, plus/hash signs, a quote, Unicode and a literal trailing dollar.
This establishes GinEdit interoperability for these cases; other command URI
payloads and exhaustive encoding/malformed-input parity remain under audit.

Legacy GinDiff coverage now verifies repeated short/long flag values, ordered
form-query parameters, space-containing prefixes and JSON path fragments against
real Git output. Reloads retain those settings, fold labels resolve the actual
path and a cached new-side jump opens the index contents.

Legacy GinBuffer fragments have a command-specific trailing dollar marker and
use literal space splitting. The shared URI result now identifies legacy data
so GinBuffer's edit/read paths can apply that convention without changing Lua
argument escaping or stripping a dollar from GinEdit filenames. A real Git
fixture reads a tracked filename containing a backslash and final dollar,
reloads it, and inserts its contents with `:read` while preserving destination
buffer options. Other command payload formats remain under audit.

Legacy GinLog and GinReflog now restore flags and their commitish/ref selectors
from URI parameters. GinLog's fragment is interpreted as a path array rather
than Lua's argv array; filename expansion follows that same representation.
Both view reads and `:read` use the restored arguments, while view decoration
defaults retain upstream override ordering. Fixtures detach HEAD at a different
commit, then verify the stored branch/path selection, full-hash formatting and
limit, reloads, selected-commit show actions and insertion without changing the
destination filetype. Other listing URI payloads and custom parsers remain open.

Legacy GinStatus now reads its dollar-terminated JSON pathspec fragment and
formats repeated parameter values in their saved order. Previously repeated
flags raised a table-concatenation error and the fragment marker prevented JSON
decoding. A real repository fixture opens a filtered status URI from a
subdirectory, reloads it and stages the selected dollar-suffixed path. The
resulting index contains only that path, the refreshed view retains its filter
and an unrelated untracked file remains untouched.

Legacy GinTag now restores flags from URI parameters and splits its
dollar-terminated pattern list according to the pinned format. Both display and
insertion paths use those settings, with structured ref metadata retained for
actions. A real Git fixture filters annotated tags using multiple patterns,
applies a custom display format, reloads and inserts the view, then deletes the
selected tag. The unrelated lightweight tag remains and the refreshed filtered
view is empty. Custom tag parser overrides remain a separate open requirement.

Legacy GinStash now restores ordered and repeated flags from URI parameters for
both view reads and `:read`. Previously those flags were ignored because only
Lua's argv fragment was consulted. A real Git fixture selects the older stash
using skip/count flags and a custom format, verifies reload and insertion, then
applies the visible row with its index. Its original `stash@{1}` reference is
retained: the working file and index receive the older content, and both stash
object IDs remain unchanged. Custom stash parser overrides remain outstanding.

Legacy GinBranch now restores ordered flag parameters and removes the pattern
list's trailing marker before splitting it. Previously it ignored display flags
and used the marker as part of the final branch pattern. A real repository
fixture applies a custom format and multiple patterns, verifies reloads, then
switches the selected branch. The refreshed view retains its filter and marks
the selected ref as current; both original branches remain present.

Legacy GinBlame paths now normalize backslash separators before reading and
saving history, matching the pinned reader. A real Git fixture restores a
revision different from HEAD using a path with spaces, plus, Japanese text,
and a literal dollar; verifies emojified details and attribution; reloads both
file and navigation panes without adding windows; and follows attribution then
returns through history without changing HEAD or the working tree. Native Lua
URI filenames retain literal backslashes.

Navigation reload also resolves an existing file buffer through the upstream
`gin_blame_file_bufname` variable when Lua's buffer-number link is absent. Legacy
file reads retain their paired URI names so existing navigation/detail panes
are reused. A real repository fixture loads three upstream-named buffers,
reloads from navigation using only the upstream file reference, verifies
revision content/attribution/detail and fixed windows, then reloads the file.
A second fixture starts with no file buffer and an empty right-hand window.
Navigation reload creates the referenced file there, explicitly reads its blame
content despite non-nested BufReadCmd handling, reuses the original navigation
and detail buffers, and restores fixed-window behavior and navigation focus.
Reconciling divergent navigation/file URI parameters remains unaudited.

GinStatus command flag parsing now retains distinct short/long names, repeated
values and first-occurrence name ordering. The default untracked-files name
stays first, as in the pinned object merge, with explicit values replacing the
default. A real Git fixture checks mixed -u/--untracked-files modes on open and
reload and confirms that an invalid earlier --renames value still reaches Git
instead of being silently discarded by a later occurrence. This verifies the
status command path in addition to the existing legacy URI flag tests.

GinBranch command arguments now group repeated Git flags by first-seen name
before storing them in the native URI, matching the pinned flag-object order.
A real Git fixture alternates --ignore-case and --no-ignore-case around an
uppercase pattern, checks both resulting selections after reload, then switches
the selected branch and verifies the refreshed current marker. Other native
listing commands still require the same command-to-URI ordering audit.

GinTag now uses the same first-seen-name grouping when saving native command
flags. A real Git fixture alternates case-sensitivity flags around an uppercase
tag pattern, verifies the resulting selection on initial read and reload,
inserts the filtered output into an ordinary Lua buffer without changing its
filetype, then deletes only the selected annotated tag while preserving the
lightweight tag. Log/reflog/stash native flag ordering remains under audit.

GinStash command input now rejects positional arguments before opening a buffer
and groups flags by first-seen name before saving its native URI. This follows
the pinned stash command's parse/validation path. A real repository fixture
mixes repeated -n and --max-count options, verifies both stash rows on open and
reload, rejects a revision and arguments after -- without replacing the view,
then applies the older stash with its index while preserving both stash objects.

GinLog/GinReflog command input now separates flag arguments from the revision
before grouping repeated flag names. GinLog validates at most one revision and
retains the -- path boundary; GinReflog validates at most one positional ref.
Real Git fixtures interleave repeated -n/--max-count flags with an explicit ref,
verify both selected commits on open and reload, reject extra revisions before
replacing the view, and insert the same rows into an ordinary Lua buffer. A
GinLog path beginning with -- remains a literal pathspec after the separator.
Display-default precedence and malformed flag syntax still need separate audit.

Native GinLog/GinReflog display reads now move explicit decorate flags to the
position of the pinned decorate default before other flag names. This matches
the existing legacy-URI reader's default merge precedence. Real Git fixtures
verify that --no-decorate followed by --decorate=full suppresses decorations in
the displayed and reloaded view, while :read retains the original flag order
and inserts full ref decorations. A literal --decorate=full pathspec after --
remains a path. Malformed flag syntax and other default merges remain under audit.

The shared native flag-grouping path now formats parsed names and values through
the same serializer as legacy URI reads. One-character long names become short
flags (for example --n=2 becomes -n2), and empty long values omit the equals sign.
Real Git log/reflog fixtures mix --n=2 with -n1 and use --no-decorate=, checking
selected output on open, reload and insertion. Previously the empty boolean
value reached Git unchanged and failed. Malformed flag-name parsing remains
outside this normalization coverage.

Flag-name recognition is now shared by Status, Branch, Tag, Log/Reflog, Stash
and Diff command handlers and by native flag grouping. It follows the pinned
ASCII short/long name patterns and prefix matching, with JavaScript dot's line
terminators for captured values. A real status fixture distinguishes literal
`-`/`-!` paths from flags, exercises a suffix outside the recognized long-name
prefix and a newline-terminated value, and verifies identical URI reloads with
no index changes. This replaces broader leading-dash checks; it does not prove
exhaustive malformed-input or numeric-key object-order parity.

Numeric flag keys now follow JavaScript object enumeration in grouped native
arguments and flag-bearing URI readers: canonical array-index names sort
numerically before other names, whose insertion order is retained. This covers
the pinned parser/formatter's otherwise surprising -2 -1 limit precedence.
Real log and reflog fixtures verify two selected commits through native command
URIs, legacy numeric-parameter URIs, reloads and :read insertion. The shared
ordering excludes leading-zero names and the non-index value 4294967295.


The four custom parser globals now reject non-string, non-null values during
candidate gathering with the pinned setting-specific error. Real Git fixtures
exercise log/reflog yank, tag deletion and stash dropping with number, boolean
and table settings; rejection leaves refs, working/index state and the register
unchanged. This implements the type-validation boundary only. String-valued
JavaScript regex matching is still unimplemented and remains a migration gap.

A backend investigation for custom parser regexes is recorded in
[the proposed regex ADR](docs/ADR/20261014-000000-preserve-custom-parser-regex-semantics.md).
The tested jsregexp revision handles the sampled ASCII lookahead/backreference
cases, but automatically enabling Unicode for a non-BMP pattern disagrees with
the pinned no-flags constructor. It has not been added as a dependency. Backend
selection and custom matching remain incomplete; this finding prevents treating
an unmodified ECMAScript-labelled binding as sufficient parity evidence.

The optional [regex backend audit](tests/audit/README.md) now contains 29
Node-generated no-flags JavaScript cases, compared through mini.nvim with each
candidate invocation isolated in a timed child process. The tested jsregexp
revision fails six cases, including a SIGSEGV on an unmatched group with a
non-ASCII input. Other differences cover absent captures, Unicode, split
surrogates and NUL. These are candidate rejection results, not passing migration
tests; the backend and action integration remain unimplemented.

Navigation-pane reloads now select the revision from the navigation URI rather
than the paired file buffer's URI, matching the pinned editNav execution source.
A real two-commit fixture with divergent legacy names verifies refreshed file
content, attribution and commit details without duplicate windows or renaming
the paired file buffer. This does not establish complete parity for divergent
stored file fragments, hidden paired buffers or all option combinations.

Blame file/navigation buffers now publish the pinned name-based links
(`gin_blame_nav_bufname`, `gin_blame_file_bufname`, `gin_blame_detail_bufname`)
and `gin_blame_file_fragment`. Re-reading after history navigation refreshes
these values. A real Git test verifies the links at initial display and after
history transitions, then removes Lua's numeric file link and reloads through
the stored name without adding windows.

Navigation reloads now read `gin_blame_file_fragment` instead of trusting the
URI fragment, and resolve the paired file through `gin_blame_file_bufname`.
Missing or empty values produce the pinned context-specific errors even when a
Lua numeric link exists. The new fixtures cover a stale URI naming a nonexistent
file while the stored path remains valid, plus rejection without changing the
file content or layout when required context is absent. Differing fragments
rebuild paired names in the native URI format; unchanged legacy names retain
the existing reload path. Hidden paired-buffer recovery remains unaudited.

Blame panes now append mapping/window cleanup to `undo_ftplugin`, preserving
any language-specific cleanup. A real buffer test changes each pane to `text`
and verifies removal of the three default keys and three Plug mappings, plus
restoration of `winfixbuf`; repeated reloads do not grow the undo string.
This implements the pinned ftplugins' cleanup intent with one deliberate fix:
their spaces immediately before command separators become part of `:nunmap`
keys in Neovim and prevent removal. The Lua-generated cleanup omits those
spaces. This is a corrected lifecycle behavior, not exact reproduction of that
upstream defect.

Status/log/reflog/tag/stash Enter mappings now append the pinned `zv` suffix,
so the destination line is exposed when it lies inside a closed fold. Ten
mini.nvim cases open real Git-backed lists, substitute a controlled action
which moves into a closed fold, and send normal/Visual Enter through the actual
mapping chain. They verify that the fold opens after dispatch. This isolates
the mapping suffix behavior; it is not additional coverage of every underlying
edit/show action or of all mapping modes and flags.

The six list views' default mappings now match the pinned ftplugins across
Normal, Visual, Select and operator-pending modes, including RHS, remapping,
`nowait` and `silent` flags. Tests source each locked upstream ftplugin into an
isolated buffer and compare its mappings with a real Lua-backed list. The fixes
restore missing Select/operator-pending modes and yank `nowait`, and restrict
status help to Normal mode. Action Plug definitions and aliases cover the same
modes; actual Select/operator-pending key sequences verify one callback with
the expected range and no unintended text edit. This does not complete the
separate audit of user overrides, disabled defaults or non-list mappings.

List default-key installation now follows a per-buffer filetype lifecycle.
Reloading content retains user overrides and explicit key removals, while
leaving and returning to the list filetype initializes defaults again. This
matches the pinned list ftplugins' one-time setup guard instead of replacing
keys on every read. Six real-list tests cover override, removal and filetype
transition; the upstream mapping comparison now also covers disabled defaults
before and after reload. Plug action redefinition and arbitrary FileType-hook
ordering remain separate compatibility concerns.

List default mappings are now installed by the actual ftplugins, before later
user FileType hooks, instead of at the end of each view's read function. Their
shared definitions retain the already-tested upstream modes and flags. Six
fixtures verify initial FileType-hook overrides and their retention on reload;
six more verify that disabling filetype plugins suppresses default keys while
leaving explicitly callable Plug actions available. This covers ordinary
post-ftplugin customization, not every possible autocmd registration order.

Diff and GinBuffer jump defaults now come from their ftplugins, preserving
later FileType-hook overrides and honoring `filetype plugin off`. The missing
GinBuffer ftplugin is present, and both use the pinned `zv` mapping suffix.
Plug registration remains in diff-jump initialization. Tests compare enabled
and disabled default-key tables against the locked ftplugins and verify
customization through initial display and reload. Patch/chaperon source checks
confirm their explicit Normal/Visual mode lists; their full mapping lifecycle
and diff-jump Plug modes remain separate audit items.

Diff-jump Plug mappings now cover Normal, Visual, Select and operator-pending
modes. The pinned initializer omits a mode; denops std's
[mapping implementation](https://github.com/vim-denops/deno-denops-std/blob/v7.0.0/mapping/mod.ts)
therefore emits `noremap`, rather than `nnoremap`. Twelve real Git tests invoke
old/new/smart Plug keys from all four modes and verify destination text/cursor,
unmodified buffers and unchanged Git status. Nine non-Normal cases failed
before the mode fix. The ordinary Enter defaults remain Normal-only.

The regex audit now reads its JSON fixture in binary mode. Text-mode
`readfile()` removed U+FEFF from an input string, creating a false whitespace
mismatch for jsregexp. With input preserved, that candidate passes 23/29 cases
and fails six, including the previously reproduced SIGSEGV.

A test-only pure Lua regex candidate now passes the initial 29-case JavaScript
oracle. It includes an AST compiler, UTF-16 matching, ordered backtracking,
numbered/named captures, lookaround and backreferences for the exercised grammar.
Known legacy-syntax and capture-name gaps are documented in the audit README;
resource limits and broader differential tests remain required. No runtime
action uses it yet, and custom parser globals remain a production migration gap.

The test-only regex candidate now resolves decimal escapes using the total
capture count, including forward groups, and falls back to legacy octal or
identity escapes as JavaScript does without flags. Class escapes and trailing
digits retain their own parsing and quantifier boundaries. Twenty-two added
Node-oracle cases bring the candidate corpus to 51; this remains bounded
experimental coverage, with no production action integration.

The experimental regex compiler also accepts no-flags class ranges involving
class escapes: `[\d-a]` includes digits, a literal hyphen and `a`. Thirteen
Node-oracle cases cover endpoint combinations, complements, negated classes,
subsequent hyphens, ordinary ranges and reversed-range errors. The 64-case
corpus passes without changing production action parsers.

Incomplete control escapes in the test-only compiler now preserve the literal
backslash and leave `c` to be parsed separately. Fourteen Node-oracle cases
cover literal matching, quantifier binding, following capture groups, class
unions and negation, and existing valid alphabetic controls. The corpus now
contains 78 cases. Class digit/underscore controls and capture-name syntax still
need work before production integration.

Class control escapes now accept decimal digits and underscore, with the
character code reduced modulo 32. Nine added Node-oracle cases cover those
controls, negation, range ordering, following digits and the distinct outside-
class fallback. All 87 candidate cases pass; this does not yet integrate the
candidate into production parsers.

The experimental compiler now distinguishes `\k` identity escapes from named
backreferences based on named captures anywhere in the pattern. Seventeen new
Node-oracle cases cover forward references, missing/empty names, class errors
with named groups, and literal fallback without them. The capture pre-scan also
excludes ordinary `<` text, lookbehind and escaped/class parentheses from named
group detection. The candidate passes 104 cases and remains test-only.

The test-only regex candidate now reads Unicode and escaped capture names,
including non-BMP letters, combining continuations and escaped surrogate pairs.
A reproducible Unicode 17.0 identifier table validates initial and continuation
characters; literal and escaped forms share keys without normalization. Thirty-
four added Node-oracle cases bring the corpus to 138. An escaped `>` name
terminator follows observed Node/Deno V8 behavior, with explicit tests. Duplicate
name rules, inline modifiers, resource/encoding limits and real action
integration still require work.

The regex candidate now accepts duplicate names on separate alternatives and
rejects duplicates whose declarations can occur along the same syntactic path.
Named references retain all associated capture numbers and read the participating
capture. Twenty-one Node-oracle cases cover alternatives, repeated capture
clearing, backtracking, lookaround and invalid duplicate declarations, bringing
the corpus to 159. This remains test-only pending the remaining syntax, resource
and integration work.
