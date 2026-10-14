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

## Configuration audit: custom parser overrides

The pinned command implementations expose four custom candidate parsers beyond
the globals listed in doc/gin.txt:

| Setting | Pinned source | Lua status |
| --- | --- | --- |
| `g:gin_log_parse_pattern` | `command/log/edit.ts`, `gatherCandidates` | Custom matching implemented with the Lua ECMAScript matcher; capture 1 selects the commit. |
| `g:gin_reflog_parse_pattern` | `command/reflog/edit.ts`, `gatherCandidates` | Custom matching implemented; capture 1 selects the commit. |
| `g:gin_tag_parse_pattern` | `command/tag/edit.ts`, `gatherCandidates` | Custom matching implemented from display text; structured metadata remains the unset-setting path. |
| `g:gin_stash_parse_pattern` | `command/stash/edit.ts`, `gatherCandidates` | Custom matching implemented from display text; structured metadata remains the unset-setting path. |

Each upstream override is validated as a string and passed to JavaScript
`new RegExp`. Supporting arbitrary display formats through structured metadata
does not implement these overrides: they can change which rows match and which
captured identifiers become action targets. Lua/Vim regex syntax must not be
silently substituted and described as compatible. The pinned branch parser has
fixed expressions and no corresponding global override, so earlier mentions of
branch custom parse-pattern settings are not an outstanding public setting.

Recent file-action fixes apply persistent arguments through the command handlers
used upstream. Diff jumps deliberately keep the internal executor route. These
dispatch checks do not close the broader API/URI compatibility audit. The completion checklist above remains unchanged.

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
inventory does not establish full compatibility for those queries. Keyboard
interaction is now tested for Gin ++wait commits/rebase and GinBuffer
commit. Other synchronous editing workflows, custom indicator APIs and the wider
command/URI contracts remain open audit items.

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
stages files named `++unknown` and `++worktree=elsewhere`, checking the
exact NUL-delimited index paths. Filename placeholder expansion remains active
after the separator, as upstream normalizes arguments before parsing options.
The earlier claim that this also preserves bare `++wait` in `:Gin` was incorrect:
its Vimscript wrapper strips that token before the shared parser runs (see below).

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

The experimental matcher supports scoped `i`, `m` and `s` modifier groups,
including nested removal and restoration on group exit. Literal, class and
backreference comparison uses a reproducible Unicode 17.0 non-Unicode
canonicalization table, while multiline anchors and dot-all apply locally.
Forty-seven added Node-oracle cases bring the corpus to 206. Broad differential
validation, resource/encoding limits and production integration remain open.

A deterministic optional Node/mini.nvim differential audit now compares 1,248
short patterns across 22,470 cases. Its first run found three orphan braced
quantifiers accepted as literals by the candidate. The compiler now rejects
complete quantifiers without an atom while retaining malformed/escaped/class
braces as literals. Eleven permanent oracle cases bring the normal corpus to
217, and all generated comparisons pass. The audit checks process termination
and a complete result report; it does not establish resource limits or full
compatibility, and no production parser uses the candidate yet.

Long-input testing reproduced a Lua call-stack overflow in the regex candidate
whose threshold depended on JIT history. Its matcher now uses explicit task and
choice stacks for ordinary traversal and repetition. Six 65,536-byte tests pass
with JIT disabled, covering greedy/lazy repetition, backtracking, capture
clearing, alternatives and lookbehind, and all 22,470 generated comparisons still
match Node. Pattern/lookaround nesting, heap usage and exponential backtracking
remain separate resource concerns before production adoption.

The regex candidate now exposes `match_strings` to convert selected UTF-16
captures to UTF-8 for parser integration. It preserves empty strings, unmatched
captures, NUL and non-BMP characters, and rejects selected lone surrogates
instead of replacing them. Unused captures need not be converted. Five tests
cover this boundary; the pinned parser field mappings and nonempty-line/custom
no-fallback behavior were rechecked. Actual custom action parsing is still
unimplemented and backend adoption remains proposed.

The four parser overrides are now connected to real actions through
`gin.candidate` and the pure Lua `gin.regex` backend. Custom matching uses
nonempty display lines, preserves duplicate candidates, and never falls back
after errors or no-match. Selected capture conversion, stash decimal-prefix
indices, missing-capture yank slots and explicit required-field checks follow
the pinned parser/action boundaries. Real Git tests verify custom tag deletion
and stash selection, plus unchanged refs/worktree after missing captures,
invalid patterns or no-match. The backend and generated Unicode tables now ship
under `lua/gin`; no Node, Deno or native extension is required at runtime.
Regex resource/encoding extremes and full migration parity remain under audit.

Non-numeric or overflowing custom stash indices use `vim.NIL` in the editor-
facing candidate so echo produces JSON null, matching upstream JSON.stringify
instead of failing on Lua NaN/Infinity.

Custom candidates now retain JSON object identity when all captured fields are
missing, so echo emits `{}` rather than `[]`. A new 44-case oracle directly
executes the four locked upstream parsers and checks their editor-facing JSON
against Lua results. It includes missing/empty captures, blank/duplicate rows,
Unicode, NUL's getbufline conversion and invalid/overflowing stash indices.
The generator rejects a mismatched upstream HEAD or modified parser sources.

Navigation reload now also restores a paired blame file that still exists but
has no window, reusing the missing-buffer recovery path. A real Git/Neovim test
retains the file with `bufhidden=hide`, closes its pane, commits new content and
reloads the navigation pane. It verifies the same file buffer, refreshed content
and attribution/detail, restored three-pane layout and window pinning. This is
a Lua recovery regression check, not an upstream runtime parity claim.

Custom indicator backends now receive whitespace-only Git output as a single
empty line, as the pinned `IndicatorStream` does after trimming. The regression
uses a real Git alias and checks raw captured output plus open/write/close
notifications; EOF does not add a write notification. This check does not cover
all chunk-boundary or decoder differences from the upstream TextDecoder.

Custom indicator output also distinguishes a completed ANSI-only sequence from
an incomplete decoder fragment. Complete sequences notify the backend with an
empty line after stripping, while partial fragments wait for completion and EOF
does not produce an extra notification. A deterministic mini.test exercises
every byte split of an SGR sequence. Incremental decoding remains intentional:
the pinned TextDecoder decodes each input chunk independently, so this is not a
claim of identical notifications for arbitrary upstream chunk boundaries.

All public Ex command declarations are now compared with the locked plugin by
loading its Vimscript in a separate Neovim and inspecting command metadata.
The test checks the complete Gin command set, argument counts, bang/bar support,
range/count defaults, address/register flags and completion metadata. The locked
plugin defines no completion providers. This found and corrected two declaration
differences: GinBuffer does not accept bang, and GinBrowse defaults its range to
zero. This audit covers command declarations, not the command handlers' complete
behavior or the Denops transport.

GinBrowse's zero address now follows the pinned wrapper's `<count>` check:
`:0GinBrowse` omits the line range instead of generating a `#L0` URL. A real
repository test checks the yanked URL through the Ex command; the existing
positive-range test continues to exercise line fragments. The command uses the
last address to distinguish a zero range, matching the upstream wrapper.

GinCd, GinLcd and GinTcd now match the pinned wrapper's failure behavior: errors
from repository resolution or the directory command display `[gin] no git
repository found` with WarningMsg rather than escaping as Lua callback errors.
A repository-free integration case invokes all three commands and verifies the
warning, unchanged directory and unchanged directory scope. Existing success
coverage verifies buffer-based repository selection and window-local scope.

The plugin now registers the pinned no-op User handlers for GinCommandPost and
GinComponentPost at startup. This makes `exists('#User#...')` report the public
events even before a consumer subscribes. An isolated Neovim startup test checks
both declarations and dispatches both events without loading a repository or
component. Source comparison also found all pinned plugin-level URI BufReadCmd
and FileReadCmd event/pattern pairs represented in the Lua plugin; handler
semantics remain covered separately rather than inferred from registration.

The main loaded marker now uses presence semantics like upstream's
`exists('g:loaded_gin')`: an existing `v:false` value must prevent initialization
instead of being overwritten. A fresh Neovim test verifies the marker is retained
and no Gin command or GinCommandPost placeholder is registered. The upstream
plugin has additional per-feature loaded markers; their independent disable
semantics are still an open startup compatibility item in the monolithic Lua
plugin and are not established by this main-marker regression check.

Startup now uses one Lua plugin file per locked upstream plugin. All fourteen
loaded markers independently use presence checks. Disabling `loaded_gin` only
skips Gin/GinBuffer and their events/URI handlers; disabling a feature skips its
own commands and handlers while the other features load normally. The previous
monolithic-startup limitation is resolved. Fresh Neovim cases cover each marker
with false and 1, retained marker values, enabled commands and BufReadCmd routes,
absence of disabled read/write routes, public event registration and idempotent
re-sourcing. Normal command declarations remain compared against upstream.

Syntax and existing ftplugin entrypoints now also test loaded-marker presence,
matching the pinned `exists('b:current_syntax')` and `exists('b:did_ftplugin')`
guards. A false marker must not clear existing syntax or install mappings/change
options. A runtime-file matrix exercises all four Lua syntax files and all eight
existing Lua ftplugins, preserving sentinel syntax, normal mappings, display
options and marker values. This does not establish parity for absent ftplugins
or all syntax matches; blame ftplugin initialization still needs separate audit.

Both blame filetypes now have Lua ftplugin entrypoints. Setting gin-blame or
gin-blame-nav directly installs navigation keys, Plug callbacks, winfixbuf and
undo settings without requiring GinBlame to read a repository first. Shared
mapping setup is also used by the existing blame read path, retaining its
compound-filetype support. A FileType lifecycle test checks both entrypoints
and cleanup; the runtime guard matrix automatically includes both new files.
The read path still reinstalls mappings, so user overrides across blame reloads
and plugin-disabled initialization remain separate lifecycle audit items.

Blame content refresh now preserves remapped or removed navigation keys for the
same filetype. Buffer replacement avoids redundantly setting an unchanged
filetype, and blame mapping initialization is guarded until undo_ftplugin resets
its marker. Both navigation and compound file panes are covered with real Git
content, custom Enter/Plug mappings, removed older-history keys and FileType
exit/re-entry. This is distinct from `:edit`, where Neovim itself reruns the
ftplugin lifecycle and may restore defaults. The test fails against the previous
commit and passes with the change; plugin-disabled setup remains under audit.

Opening GinBlame with `filetype plugin off` now leaves navigation mappings and
winfixbuf unset, matching the upstream separation between view construction and
ftplugin setup. The reader's compound-filetype fallback runs only while Neovim's
ftplugin loader is enabled. A real-repository test checks both panes, all six
navigation mappings, window pinning, synchronized scrolling and rendered content.
Existing buffers configured before disabling ftplugins retain their prior
settings, as disabling the loader does not itself undo loaded ftplugins.

The gin-diff ftplugin now schedules foldlevel=1 in the window where it was
initialized, matching the locked ftplugin's deferred window-local default.
Previously only explicit difffold setup applied that level. A two-window test
changes focus before scheduled execution and checks that only the original
window's folds are opened to level one. Closed windows are ignored safely.

Blame's default Enter/older/newer mappings now match the pinned nonsilent nmap
attributes; the underlying Plug callbacks remain silent. A source-based mapping
comparison covers both blame ftplugins with defaults enabled and disabled,
including RHS, mode, remapping, nowait and silent flags. Together with the
existing list and diff/buffer comparisons this covers default mapping tables
across all ten ftplugins, without claiming complete callback behavior parity.

Legacy GinLog expansion now falls back to its literal path fragment when JSON
parsing fails, following the locked util/expand.ts behavior. Previously the
outer error handler returned the original URI. A public Vimscript API test and
command-placeholder assertion cover a path with spaces and Japanese text. Native
GinLog argv fragments keep their existing separator-based interpretation; this
change does not reinterpret native malformed fragments as filesystem paths.

Legacy GinEdit, GinDiff and GinLog now share the locked expander's JSON fragment
selection: array first elements, empty/falsy selections, string first characters,
and literal-fragment fallback when indexing or joining has the wrong type.
Legacy joins retain the repository prefix even for a leading slash, matching
std/path.join rather than treating the fragment as an absolute override. Fifteen
fragment cases across the three schemes are checked through gin#util#expand;
the expected selections and joins were also executed in Deno with upstream's
std/path dependency. Native URI interpretations remain separate. Unpaired
UTF-16 string selections cannot be represented safely and leave the URI intact;
full transport/encoding-edge parity is not claimed.

File URI expansion no longer expands environment variables while normalizing a
resolved path. Repository roots and file names containing literal `$NAME` must
remain literal, as in upstream's path join. A controlled environment-variable
regression covers GinEdit/GinDiff/GinLog in both native and legacy forms through
the public Vimscript API, and restores the environment after the test. Ordinary
filename-expression expansion still happens before URI interpretation.

URI path normalization also protects leading literal tilde roots from home
expansion. A removable `./` prefix allows the existing normalizer to simplify
dot segments without interpreting the URI root as a home-directory expression,
including on Neovim 0.10. Eighteen POSIX cases cover three root forms, all three
file schemes and native/legacy URI forms, retaining literal backslashes in the
filename. Windows backslash semantics are intentionally outside this POSIX test.

Component discovery now removes only Git's trailing newline from the worktree
path, preserving whitespace that belongs to the directory name. The previous
trim changed both the displayed worktree and the cwd used for branch/traffic
queries. A real repository renamed with a trailing space verifies full/name
components and the existing upstream/ahead/behind values; a valid empty directory
at the trimmed path makes the regression fail deterministically without a spawn
error. This follows the pinned finder's preservation of the first output line.

Component Git spawn exceptions are now caught at the refresh boundary, retaining
the last published values. As in the pinned component failure handler, diagnostics
are emitted only with verbose enabled. Fault injection covers discovery, branch
and traffic launch failures (including launches from scheduled callbacks), then
restores Git execution and verifies a subsequent real branch change refreshes
successfully. This does not change how ordinary nonzero Git exits are handled.

The public diff foldtext function now extracts paths only from matching `--- `
and `+++ ` headers. Manually folding a whole diff (including its `diff --git` and
`index` lines) no longer invents a rename from those metadata lines. Three cases
cover both missing headers and either missing header; their expected strings
were also verified by executing the pinned upstream foldtext function in an
isolated Neovim. Existing custom-prefix and quoted-path decoding is preserved.

An explicit empty worktree argument now follows the default current-buffer/cwd
search, matching the truthy `options.worktree` selection in the pinned
`git/worktree.ts`. A mini.test case exercises both Lua and Vimscript public APIs,
first with a file in another repository and then with an unnamed buffer whose
cwd supplies the repository. Nonempty invalid paths still fail without fallback.

Explicit worktree expressions now pass through the Gin-aware filename expander
before repository discovery, as in the pinned resolver. An implicit file-view
context still uses the view's root; an explicit `%` can select a nested repository
containing the expanded file. A real nested Git repository exercises both public
APIs across native and legacy GinEdit/GinDiff/GinLog URI formats. This shared
resolver also handles explicit worktree options supplied by command handlers.

`:Gin` now removes every exact `++wait` token before ordinary option parsing,
matching the pinned `plugin/gin.vim` wrapper. Repetition enables waiting without
a duplicate-option error, including occurrences after `--`. A real Git fixture
checks that only the requested ordinary file is staged, leaving a file named
`++wait` untouched; three placements were also checked against the pinned wrapper
with a stubbed Denops request boundary. Other duplicate options still fail.
The previous tests and help incorrectly generalized the shared option parser's
rules to this wrapper-level token and have been corrected.

Shared command argument normalization now precedes option and separator
recognition, following the pinned handlers' `parseOpts(await normCmdArgs(...))`
ordering. A real Git test opens a file named `--` and uses `%:t` as the separator
when staging `++unknown`; the resulting index contains exactly that literal
path. Previously the separator appeared only after classification, and the next
argument was incorrectly rejected as an unknown Gin option. The separate bare
`:Gin ++wait` filtering still happens before filename expansion, as upstream.

Nested action calls now resolve Visual and Select mappings rather than always
looking up the Normal mapping, preserving mode-specific user overrides. Actual
key-input tests check the selected override, captured range and unchanged buffer
content. A separate runtime check of the pinned core's `execute`/`feedkeys`
expression confirms Visual/Select dispatch and Normal dispatch when called from
operator-pending mode. The test sends Escape only after dispatch, since queued
keys run before the upstream's appended action keys. Existing Normal callback,
expression-mapping, alias and range-restoration tests remain in place.

Accepting an empty action choice now records the empty string, clearing the
previous repeat action. Cancellation still leaves the record untouched. The
pinned action core only skips null input, and denops std v7's Neovim input helper
preserves an accepted empty string while returning null for cancellation. A
regression test proves that repeat no longer re-executes the previous callback
after an empty choice. An unmapped empty action is a no-op, while a user-defined
empty-name mapping can still be dispatched.

`tests/test_editor_interaction.lua` now exercises asynchronous `:Gin commit` in
an isolated child Neovim using `MiniTest.new_child_neovim()` and keyboard input.
It types the command, edits COMMIT_EDITMSG in Insert mode, then either types
`:Apply` or `:wq` followed by `yes` at the confirmation prompt. Both cases wait
for GinCommandPost and independently inspect the real commit message and file
contents. No RPC buffer edit or RPC Apply call substitutes for those interactions.
This closes that specific asynchronous keyboard workflow gap. A separate bounded
probe of `:Gin ++wait commit` reached the proxy buffer but left the typed message
and Apply command queued: after 300 ms the buffer's first line was still empty
and no completion event had fired. Draining those keys and editing/applying via
RPC allowed the real commit to finish. Thus scheduled API edits are insufficient
evidence of usable keyboard interaction during synchronous waits; that remaining
limitation is reproduced, not resolved by these asynchronous tests.

The child-Neovim keyboard tests also cover typing a draft and cancelling with
`:Cancel` or `:q` followed by `no`. They observe the real commit process exit,
verify that no commit exists, and check both index and working-file contents.
Only commit-exit observation wraps a callback; all editing and cancellation use
normal input. This extends the asynchronous workflow evidence to rejection.

A separate attempt to compare synchronous keyboard handling with pinned vim-gin
and installed denops.vim `e82c5a94ca1154b05c9d74d6f6f58c9991b1424f` stalled during
reference startup/RPC access before reaching the input observation. Those probe
processes were terminated. Its source-level use of synchronous RPC alone does
not prove runtime parity, so the Lua synchronous-input limitation remains open.

`tests/test_askpass_interaction.lua` exercises real Neovim `inputsecret()` prompts
in a child process, with synthetic credentials and no network. Prompt observation
wraps the real function without replacing its return value. Typed username and
password responses reach Git credential fill in both asynchronous and synchronous
progress execution. Ctrl-C at the username prompt returns an empty string and
Git proceeds to the password prompt; a separate Vimscript/RPC inputsecret probe
confirmed the same native result. The pinned askpass handler forwards that result
unchanged. These four keyboard cases distinguish native empty responses from
the older tests' injected input exceptions; they do not claim Ctrl-C cancels Git.

Null editor/askpass opt-out settings now retain the enabled defaults. The pinned
proxy listener evaluates each value with `?? false`; Lua previously treated
`vim.NIL` as truthy and disabled the corresponding proxy. A regression case sets
both globals to `v:null` and checks that the editor command and executable
askpass launcher are provided. Existing independent opt-out tests remain active.

The keyboard-driven editor tests now cover every supported proxy opener:
`edit`, `split`, `vsplit`, `tabedit` and `pedit`. They check tab/window counts,
split orientation, retained focus for preview opening, and the preview-window
flag before typing and applying the commit message. Preview focus is entered
with `<C-w>P`; no RPC buffer edits replace keyboard editing. Each case verifies
the resulting Git commit and file contents. This closes the supported-opener
workflow check without changing the remaining synchronous-input limitation.

A keyboard-driven interactive rebase test now changes two todo entries from
`pick` to `reword`, applies the todo, and edits both successive COMMIT_EDITMSG
requests through normal input. It verifies separate request IDs, gitrebase and
gitcommit filetypes, both rewritten messages and commit IDs, the unchanged base
ancestor and file contents at each rewritten commit, and removal of rebase state.
This covers repeated editor requests for the same message path during one
asynchronous Git operation; it does not close synchronous keyboard handling.

Proxy editor buffers now open with `silent`, matching the pinned proxy's
`buffer.open(..., { mods: "silent" })`. A regression test removes the `F`
shortmess flag and captures stdout/stderr from an isolated headless Neovim as
the scheduled editor request opens: the file-read notice appeared before the
fix and is suppressed afterward. The
request still initializes and can be cancelled. This concerns emitted messages;
Neovim may still update `v:statusmsg` during a silent read.

Bare `++option` values now use an empty string, matching denops std v7's
`parsePattern` result consumed by the pinned handlers. Previously Lua stored
`true`; a bare `++worktree` was consequently expanded as `v:true` and failed
repository discovery. A real Git regression test stages a file through
`Gin ++wait ++worktree add -- file` and checks its index contents. The separate
Gin wait-token handling remains boolean and runs before the shared parser.

Gin option names now follow the pinned denops std v7 `[a-zA-Z0-9-]+` prefix
grammar. Arguments such as `++=file`, `++_file` and `++日本語` have no matching
option name and remain Git arguments, even before `--`; the former parser
incorrectly rejected them as unknown options. A real Git fixture stages those
paths together with `++` and checks the exact NUL-delimited index listing.
Recognized name prefixes still undergo the usual allowed-option validation.

The final Gin command display now removes the leading Unicode byte order mark
for UTF-8 and UTF-16 output, matching the pinned command's TextDecoder. A real
Git fixture covers default UTF-8 and explicit UTF-8/UTF-16LE/UTF-16BE encodings,
keeps an interior U+FEFF character, and checks that returned stdout retains the
original bytes. This addresses final display, not incremental indicator decoding
or the complete set of TextDecoder encoding aliases.

Shared Gin option parsing now stops values at LF, CR, U+2028 and U+2029,
matching the non-dotAll expression used by the pinned denops argument parser.
A real Git test passes each terminator after a valid explicit worktree and
checks staged contents, rather than allowing the ignored suffix to become part
of the repository path. This truncation applies only to recognized options;
ordinary Git arguments and arguments following `--` retain their contents.

Progress indicators now use the ECMAScript whitespace set when trimming decoded
chunks, matching the pinned IndicatorStream's String.trim(). Tests exercise all
25 whitespace/line-terminator characters, preserve interior whitespace and
non-whitespace U+0085/U+180E/U+200B, and verify Unicode-only chunks still reach
custom backends as an empty line. Raw process output is unaffected. This does
not establish complete TextDecoder parity for malformed or split byte sequences.

Undefined action names now fall through to Neovim's Plug dispatch, matching the
pinned core action call, instead of raising a Lua-only unknown-action error.
The regression test accepts an undefined choice, checks that it is remembered,
repeats it, and verifies unchanged buffer contents and restored action range.
A native execution of the pinned feedkeys expression also leaves the buffer
unchanged. Existing callback and mapped-alias dispatch tests remain in place.

The repeat action now treats false, zero, null and an empty saved name as
"Nothing to repeat", matching the pinned core's falsy-value check. Other
non-string values are rejected before dispatch with a buffer-variable type
error. Tests verify that numeric zero cannot dispatch the action named "0",
while the string "0" remains a valid repeat target, and cover boolean/list
validation as well as null handling.

Branch move validation now covers an existing destination with a different
commit: ordinary move must fail without changing either ref, while move:force
replaces the destination with the selected source commit and removes the old
source ref. The test also checks the current branch, working file and index
remain unchanged. Temporarily omitting --force caused this new case alone to
fail; the original implementation was restored before the full suite.

Branch new/move and worktree creation prompts now report Cancelled with the
ErrorMsg highlight when dismissed or accepted empty, matching the pinned
actions' helper.echoerr calls. The regression matrix covers all eight action
variants, both worktree input stages, and both cancellation forms. Each case
checks that refs, worktree registration, working-tree/index status and cwd
remain unchanged. This covers cancellation feedback rather than the full
Denops helper message scheduling and silent-state behavior.

Orphan worktree prompts now retain slash-separated branch names in the default
path, matching worktree_new.ts: feature/orphan defaults to
.worktrees/feature/orphan. Ordinary worktree creation continues to replace
slashes with underscores. A real Git test accepts the offered defaults in both
paths and checks cwd, symbolic HEAD, regular branch ancestry and contents,
and the orphan's empty index and absent tracked file.

Log and Reflog tag actions now display Cancelled with normal highlighting when
the name prompt is dismissed or accepted empty, matching tag.ts's helper.echo
usage. The matrix covers the tag alias, lightweight, annotated and signed
variants including force forms in both views (28 combinations). It checks that
existing refs, staged changes and unstaged changes survive cancellation.

Cancelling the command prompt for rebase:x or rebase:i:x now reports Cancelled
with ErrorMsg, matching the pinned rebase action. A matrix exercises both
actions in Branch, Log and Reflog with dismissal and empty input. It verifies
unchanged refs, staged/unstaged diffs and absence of both rebase state
directories, covering cancellation before synchronous or interactive execution.

Branch's action registration surface is now checked against an executable
pinned-source oracle: all 44 action names and alias targets match the Lua
buffer. scripts/action-oracle.mjs executes the pinned Branch/action initializers
with editor registration stubs; mini.nvim checks the resulting JSON against
real buffer mappings. This closes the Branch name/alias inventory check only;
callback semantics and other view inventories remain separate requirements.

The registration oracle now covers Branch, Status, Log, Reflog, Tag and Stash
(308 registrations). It exposed Status reset as an incorrect unstage alias.
Reset now independently runs git reset --quiet on selected candidate paths,
matching reset_file.ts. A staged-rename regression verifies that resetting
the destination retains the staged source deletion and leaves the destination
untracked with its content intact. Existing unstage tests continue to cover
restoring both sides of a rename. All six name/alias inventories now match.

The six-view registration audit now also captures mapping options and checks
all 308 actions/aliases in Normal, Visual, Select and Operator-pending modes.
Buffer locality and noremap/silent/expr/nowait/script attributes match; no
action mappings appear in Insert, Command-line, Terminal or Lang-Arg modes.
Making aliases silent temporarily caused all six view checks to fail, proving
the attribute comparison detects that regression. The implementation was
restored before full validation; this step changes only audit tooling/tests.

Status stage:intent-to-add now registers unknown paths before processing
deletions and other paths, matching the pinned stage action's command order.
A required clean filter deliberately fails for a modified tracked file; the
regression checks that the new file already has an empty index entry, the
tracked index content is unchanged, and both working files survive. Unstage's
intent-to-add conversion still follows reset. This verifies partial Git state;
completion-event handling after a later command failure remains a separate audit.

Status's multi-command staging actions now schedule GinCommandPost after each
successful Git command, as the pinned command dispatcher does. A later failure
no longer loses the update from an earlier intent-to-add operation. The existing
clean-filter failure fixture now drains pending events and checks that the
visible new-file row changes from untracked to intent-to-add. Failed commands
still propagate their errors; the shared post-event debounce remains in use.

Status staging now captures eventignore=all before each Git operation and
omits the completion timer for suppressed operations, matching the pinned
command handler. The regression restores eventignore immediately after staging
and drains callbacks: no delayed event appears, while the index contains the
staged data. A subsequent ordinary stage emits one event and updates the index,
showing that suppression does not leak into later operations.

Synchronous file, Branch, Tag, Stash, Log and Reflog actions now use a shared
command.run wrapper that captures eventignore=all before Git and carries it
into final output/completion handling. This removes the unqualified finish
calls that could emit a delayed event after eventignore was restored. Twelve
real-Git cases cover normal and suppressed completion across six views, with
index/ref/stash assertions in addition to event counts. The specialized Status
staging path retains its previously verified per-operation suppression.

Branch deletion now sends successful linked-worktree removal through the
shared command completion path. If the subsequent branch deletion rejects an
unmerged branch, the view still refreshes to remove the obsolete worktree path.
The regression uses a real clean linked worktree with an unmerged commit and
checks worktree removal, retained branch SHA, unchanged main worktree/index,
and updated candidate metadata after the deferred completion event.

The GinEdit index-write handler now preserves eventignore=all from entry and
does not schedule a suppressed GinCommandPost after writing. Tests call the
handler directly because all also suppresses BufWriteCmd, restore eventignore
before draining, and compare normal versus suppressed completion. Both cases
verify updated index content, an unchanged working file and a cleared modified
flag. Existing write/filter/failure tests continue to exercise the write path.

Index-write validation now includes a throwing BufWritePost command. On the
current Neovim path, the hook error reaches the caller while the completed
index write still produces GinCommandPost. The regression checks the exact
saved index content, unchanged working file, cleared modified flag and one
completion event. No production change was needed for this case.

Progress indicators now replace malformed UTF-8 with U+FFFD, including lone
continuation bytes, invalid leads, overlong encodings, surrogate encodings,
values above U+10FFFF and truncated sequences. Invalid continuations are
reprocessed so a following ASCII character or valid sequence is not lost.
The indicator regression tries every split of seven malformed byte fixtures;
a real Git alias also verifies that a custom indicator receives replacement
text while captured stdout retains the original bytes. An independent local
Node TextDecoder probe matched 24,126 split/flush comparisons over single-byte,
boundary and deterministically generated inputs (excluding ESC to isolate the
UTF-8 decoder from the CSI filter).

This closes malformed-byte handling for the default progress decoder, not all
TextDecoder behavior. In particular, the pinned indicator_stream.ts decodes
each chunk without streaming; the Lua implementation deliberately retains its
existing incomplete-sequence buffering across chunks. Chunk-level notification
parity, BOM handling and non-default encoding behavior are not established by
these tests.

## Component API audit

The pinned `autoload/gin/component/{branch,traffic,worktree}.vim` files expose
six getters. Their implementations in `denops/gin/component/*.ts` return the
following strings; `tests/test_component.lua` now exercises all tracking states
with real Git refs, in addition to the legacy statusline expression test.

| Public getter pair | Verified values |
| --- | --- |
| branch ascii / unicode | Branch alone, branch plus upstream with the corresponding arrow, detached empty string, unborn branch name |
| traffic ascii / unicode | Diverged, ahead-only, behind-only and synchronized histories; empty without an upstream |
| worktree full / name | Canonical repository path and basename, including trailing spaces |

The new BufEnter regression opens a file in a second repository while retaining
the first repository as cwd, checks all three components, then returns to an
unnamed buffer and checks cwd fallback. Removing only the BufEnter subscription
makes this test fail while the other component cases still pass. Existing
fixtures cover DirChanged, GinCommandPost, symlink resolution, Gin URI anchors,
spawn failure recovery and stale asynchronous responses.

The component checklist remains open because error and cache behavior differ
from the pinned `autoload/gin/internal/component.vim`: upstream initializes
and updates each getter independently, uses TTL caches, and retains the previous
value when a request fails (reporting errors when verbose is enabled). Lua
publishes one combined snapshot, initializes immediately, also refreshes on
DirChanged, clears values outside repositories and rejects outdated results.
Discovery spawn exceptions retain the snapshot. Failed branch and traffic
queries, including spawn exceptions, retain the previously published values for
the failed component and report a diagnostic only when verbose is enabled.
A failed branch query still allows
traffic to update, and failed traffic does not suppress a successful branch
update. Eight controlled-failure cases use a real renamed branch and new commit,
verify retained versus refreshed fields for both nonzero exits and spawn errors
with verbose both off and on, and check recovery after restoring successful Git
responses. Branch lookup tries its fallback after an initial spawn exception,
matching the pinned getBranches try/catch; a separate regression verifies that
successful fallback still updates traffic from the real tracking history.
A fallback branch without usable tracking information still clears traffic, as
covered by existing tests. Exact cache/notification timing remains different or
unverified. Denops startup events do not apply to the Lua runtime; no Denops
dependency is introduced by the legacy getters.

Component event validation now observes the values read inside GinComponentPost.
An unchanged real-Git refresh completes its final query before the test starts
an observation barrier beyond the 100 ms notification delay, and emits no event.
A subsequent real commit followed by GinCommandPost produces a component event
whose handler sees the updated ahead count, branch and worktree together.
Removing the unchanged-value guard makes this new regression fail, with the
other component cases still passing. This verifies change-only notification and
publication before callbacks; it does not establish upstream TTL-cache parity
or behavior of overlapping notification timers under every scheduling order.

## Public autoload API inventory

The pinned `autoload/gin` tree defines 13 non-internal public functions. The
following table accounts for every declaration, its Lua destination and existing
behavioral evidence. `tests/test_public_api.lua` discovers the pinned declarations
and compares required/variadic arity with the functions actually loaded into
Neovim. Temporarily adding a required argument to the echo write wrapper makes
that audit fail. This is a declaration-compatibility check, not a substitute for
the behavior tests listed below; `gin#internal#*` and script-local functions are
excluded from this public API inventory.

| Public function | Lua destination | Behavioral tests |
| --- | --- | --- |
| `gin#util#reload(...)` | `gin.util.reload` | `test_util_reload.lua`: current, explicit, hidden, modified and wiped buffers |
| `gin#util#expand(expr)` | `gin.util.expand` | `test_util.lua`: filename modifiers, Gin URIs and literal path contents |
| `gin#util#worktree(...)` | `gin.util.worktree` | `test_worktree.lua`: explicit and current context, errors, links and worktrees |
| `gin#difffold#foldtext()` | `gin.difffold.text` | `test_diff.lua`: real folds, prefixes and header parsing |
| `gin#component#branch#ascii()` | `gin.component.branch.ascii` | `test_component.lua`: tracking, detached/unborn branches, refresh and errors |
| `gin#component#branch#unicode()` | `gin.component.branch.unicode` | `test_component.lua`: Unicode upstream arrow and legacy wrappers |
| `gin#component#traffic#ascii()` | `gin.component.traffic.ascii` | `test_component.lua`: diverged, one-sided, synchronized and error states |
| `gin#component#traffic#unicode()` | `gin.component.traffic.unicode` | `test_component.lua`: both arrows and one-sided counts |
| `gin#component#worktree#full()` | `gin.component.worktree.full` | `test_component.lua`, `test_worktree.lua`: repository context and canonical paths |
| `gin#component#worktree#name()` | `gin.component.worktree.name` | `test_component.lua`: basename and trailing spaces |
| `gin#indicator#echo#open(id)` | `gin.indicator.echo.open` | `test_indicator.lua`: legacy/native lifecycle and shared display settings |
| `gin#indicator#echo#write(id, chunk)` | `gin.indicator.echo.write` | `test_indicator.lua`: synchronous line arrays and unopened handles |
| `gin#indicator#echo#close(id)` | `gin.indicator.echo.close` | `test_indicator.lua`: restoration after the last active indicator closes |

All 13 declarations have a Lua-backed entrypoint and behavioral coverage in the
listed scopes. This inventory does not close the broader command, configuration,
URI or exact asynchronous cache compatibility audits.

## Chaperon supplement configuration validation

Pinned `command/chaperon/command.ts` validates
`g:gin_chaperon_supplement_disable` and `g:gin_chaperon_supplement_height` as
numbers before resolving or opening the conflict layout. Lua now performs the
same type checks at entry to `chaperon.open`, with defaults 0 and 10. Values are
captured once and the validated height is passed to every supplement window.
Eight real-conflict regressions reject strings, booleans, null and tables for
both settings before changing the current buffer/window, window list, buffer
contents, modified/diff flags, working file or index stages. Height is validated
even when supplements are disabled, as in the pinned code. Existing supplement
fixtures verify the normal three supporting views and a configured height.
This does not establish complete configuration parity. Mapping-disable setting
types are covered below; other command-specific options remain under audit.

## Patch and Chaperon mapping setting types

The pinned implementation and help disagree on
`gin_patch_disable_default_mappings` and
`gin_chaperon_disable_default_mappings`: both command implementations assert
`is.Boolean` with a false default, while the corresponding help entries document
a default of 0. The Lua port retains its existing boolean/numeric flag support,
including the documented 0/1 convention. This is an explicit compatibility
extension over the pinned
runtime assertion; it is not exact type-validation parity.

Both layouts now reject strings, null and tables before opening or modifying
panes. The shared mapping helper validates and captures the setting once per
open. Six invalid-setting regressions preserve buffer/window state, working
files and index entries. Eight valid-setting cases cover false, true, 0 and 1
for both commands, checking the default key and executing the retained Plug
action through real partial staging or conflict resolution. Existing numeric
flags remain supported and the help now states the accepted setting types.

## Browse alias dictionary validation

`command/browse/command.ts` validates the complete `gin_browse_aliases` setting
with `is.RecordOf(is.String)`. The cached unknownutil 4.3.0 predicate explicitly
excludes null and arrays, then checks every own property value. Lua now validates
a dictionary of strings before remote discovery, including entries for hosts
that are not selected. Missing settings default to an empty dictionary; explicit
Lua empty dictionaries use `vim.empty_dict()`, while lists are rejected.
Nine invalid-setting regressions verify that no URL is opened and the requested
register remains unchanged. Normal fixtures cover an explicit empty dictionary
and custom domains aliased to all three supported providers, preserving the
custom hostname and checking encoded paths, immutable refs and line ranges.

## Default and persistent argument setting audit

The pinned command entrypoints contain 12 calls to `fillCmdArgs`, covering 11
setting families (22 globals): branch, browse, chaperon, diff, edit, log, reflog,
patch, stash, status and tag. GinBlame and GinEdit both use the edit family.
`tests/test_argument_config.lua` extracts this binding directly from each pinned
`command/*/main.ts`, checks the inventory count and shared edit binding, then
invokes every corresponding Neovim command with an invalid default or persistent
setting. All 24 cases reject the setting before parsing explicit command options
or changing the current window/buffer. Skipping default-setting validation when
explicit arguments are present makes all 12 default-setting cases fail.

Existing Status fixtures exercise default replacement, persistent prepending,
worktree selection and nonmutation of configured arrays; Blame also exercises
the shared edit defaults and persistent settings. Destination-command tests
cover configured edit/diff/log/patch/chaperon/browse actions. This audit verifies
all setting-name bindings and validation entry paths; it does not establish
every command-specific interaction between valid persistent arguments and flags.

## Fold prefix configuration audit

A real Git fixture now produces added, deleted, modified and renamed-with-edits
files in one diff. For each fold, `test_diff.lua` compares the Lua fold text with
the pinned `autoload/gin/difffold.vim` function executed in a separate Neovim
process, and also checks explicit expected paths and added/deleted line counts.
The configurations cover partial overrides with ASCII fallback, the Nerd Font
preset, an empty-string prefix and numeric zero. The configured dictionary must
remain unchanged. Child errors, timeouts and malformed output fail the test.
This verifies fold text for these configurations and real diff statuses, without
claiming complete folding-layout or arbitrary configuration-value parity.

## Syntax highlight definition audit

`test_syntax.lua` now extracts all 16 Gin highlight groups declared by the four
pinned syntax files and compares their Neovim attributes with the Lua syntax
files in independent fresh processes. Links, GUI colors, terminal colors and
style attributes match. The comparison removes only the default-installation
flag and an empty terminal-style table: Lua intentionally retains theme overrides
for blame, with existing reload tests covering that behavior. Changing the Stash
branch link from Identifier to Special makes this new audit fail while the other
syntax tests continue passing. Child failures and timeouts are fatal.

This closes the default-attribute inventory for the four syntax files. It does
not claim identical matching at every byte position: the previously documented
Stash branch/Reflog action fixes and custom-theme preservation remain deliberate
differences from the pinned syntax implementation.

## Filetype display option audit

`test_ftplugin.lua` inventories all ten pinned `ftplugin/gin-*.vim` files and
compares their display settings with the Lua files in separate fresh Neovim
processes. Each file is loaded with both boolean initial values; the comparison
covers list, spell, wrap, foldenable, cursorline, modeline, buflisted, winfixbuf,
foldlevel, commentstring, comments, formatoptions and the initialization marker.
The diff fold level is observed after its deferred initialization. Child errors
and timeouts fail the test. A temporary GinBuffer modeline change makes the new
audit fail, demonstrating that untouched options are part of the contract too.

This verifies initial display settings on the tested Neovim runtimes, not the
full filetype lifecycle or mapping behavior. Existing tests separately exercise
mapping installation and cleanup. Lua additionally restores list display options
through `b:undo_ftplugin`; the pinned list ftplugins do not supply that cleanup.
The gitcommit/gitrebase ftplugin subdirectories are outside this inventory.

## Commit and rebase alias lifecycle

The gitcommit/gitrebase extensions now initialize the Neovim runtime ftplugin
before appending Gin's alias cleanup. Previously, normal filetype loading could
replace `b:undo_ftplugin` after Gin appended it, leaving `:Accept` and `:Cancel`
installed when the buffer changed filetype. This repairs the Lua cleanup
extension; the pinned Vimscript aliases have no cleanup of their own.

`test_editor_aliases.lua` covers both filetypes, enabled/disabled aliases, an
existing global Accept and an existing buffer-local Cancel. It checks command
definitions and scope, repeat sourcing, removal of Gin-owned aliases on a
filetype change, and preservation of the existing user commands. Six enabled
cases failed before the initialization-order fix; all twelve pass afterward.
Existing real Git editor tests separately cover accepting and cancelling proxy
requests. This does not close the remaining proxy interaction audit.

## Blame relative-time display boundaries

A real Git history with thirty independently attributed lines now exercises the
navigation pane's relative-time labels against a fixed local clock. The cases
cover both time directions at the minute/hour/day/week/month/year thresholds,
singular/plural labels, and calendar month/year anniversaries. The test reads
the resulting GinBlame navigation rows rather than a helper's return value.

The pinned relativeTime function also confirms the intentionally asymmetric
364-day-plus boundary for the chosen January 2025 clock: `11 months ago` but
`in 12 months`. Month and year values use calendar dates once their elapsed-time
threshold is reached. Changing the Lua minute threshold from `<` to `<=` makes
the new test fail. These fixtures cover normal Git timestamps, not arbitrary
invalid date values or all timezone transitions.

## Blame history index compatibility

Blame now stores `b:gin_blame_history_index` using the pinned implementation's
zero-based convention, with `-1` and an empty history before the first selection.
Both attribution and source panes receive the same state. Internal Lua list
access remains one-based and converts at the buffer-variable boundary. Previously
Lua saved one-based positions and left the initial variables absent.

A real Git fixture checks initial state, two selections, older/newer navigation
from the source pane, and the oldest-history boundary while comparing both panes'
indices and history entries. Existing history tests still verify renamed paths,
cursor restoration, forward-history truncation and failed-parent preservation;
the latter now expects the upstream zero-based index. This addresses the history
index contract without claiming all Blame buffer-variable shapes are identical.

## Blame history after hidden-pane restoration

Two real Git fixtures now retain either the source or navigation buffer with
`bufhidden=hide`, close its window, then reload the surviving pane. A history
containing a rename and a parent selection is positioned before its newest
entry. The restored panes must retain identical entries and indices; navigating
forward from the restored pane must recover the earlier filename, parent
revision and exact physical cursor line in both panes, without changing Git
state. Resetting an existing navigation pane's history index while reopening it
makes the new navigation-restoration case fail.

These tests exercise restoration of loaded hidden buffers. The normal unload
policy still closes the companion buffers, as covered separately; they do not
claim history persistence after buffers are wiped or across Neovim sessions.

## Blame continuation group sizes

The Lua parser now remembers each commit's latest explicit porcelain group size
and applies it when continuation headers omit the count, matching the pinned
parser's `numLinesInGroup` values. A real six-line history with an edit in the
middle produces groups of two, one and three lines, including two differently
sized groups attributed to the same commit. Both panes must expose
`{2, 2, 1, 3, 3, 3}`; before the fix they exposed `{2, 1, 1, 3, 1, 1}`.

The broader result-shape audit remains open: Lua's `commits` entries currently
contain raw porcelain metadata (for example a string author and separate
`author-time`), whereas the pinned parser constructs nested author/committer
objects, booleans and structured previous-commit metadata. The exact date
representation crossing Denops into buffer variables also needs verification.
Per-line metadata remains necessary for the Lua rename-following behavior and
must not be lost while resolving these representation differences.

## Blame structured commit metadata

`gin_blame_result.commits` now exposes nested author/committer records (name,
email without angle brackets, time and timezone), a boolean boundary flag,
summary, filename and optional `{sha, filename}` previous-commit information.
The first metadata occurrence for each commit is retained, matching the pinned
parser. Each line still retains its own raw `metadata` for rename-following and
relative-time rendering; normalizing the shared record does not replace it.

Date serialization was checked through the installed Denops transport dependency
`@lambdalisue/messagepack@1.0.2` (cached msgpackr 1.12.1), sending a real
`nvim_call_function('setbufvar', [1, ..., {time: new Date(...)}])` request to an
embedded Neovim and reading it with getbufvar. MessagePack Date extensions become
`v:null` at this boundary, not ISO strings or epoch numbers. Lua consequently
uses `vim.NIL` for the shared person's time field and keeps the raw epoch on each
line. The probe also confirmed past/future timestamp variants on Neovim 0.10.
This verifies that transport version; arbitrary Denops transport versions remain
outside the evidence.

A real Git fixture compares the complete shared records for boundary and normal
commits in both panes, including timezone and previous revision/path. It failed
on the old flat author string before the fix. Existing encoded-author and rename
fixtures continue exercising per-line metadata. This resolves the shared record
shape difference noted above; Lua's additional per-line metadata remains an
extension, and complete result parity is not claimed for malformed porcelain.

## Blame dictionary types and empty files

Blame's commit dictionary and its physical-line/source-line lookup dictionaries
now remain Vim dictionaries, including when empty. The old Lua tables serialized
as lists; nonempty lookup tables also used numeric Lua indices and introduced
list slots for divider lines. The pinned implementation uses record keys, so the
Lua buffer dictionaries now use decimal string keys and omit divider entries.
Detail lookup, commit selection and cursor restoration convert their numeric
line numbers at this boundary. Lua consumers of these buffer variables should
likewise use string keys; Vimscript dictionary indexing accepts line numbers.

Two real Git fixtures assert `v:t_dict` for all three dictionaries and `v:t_list`
for result lines in both panes. The populated case checks the exact physical keys
and reverse mapping; the committed empty-file case checks empty dictionaries,
an empty line array and blank displayed buffers. Both tests failed with list
rather than dictionary types before the fix. Existing navigation, detail,
encoding, rename and pane-restoration tests run against the corrected keys.

## Blame buffer-variable inventory

The pinned Blame TypeScript files reference thirteen distinct `gin_blame_*`
buffer-variable names. All now have Lua counterparts:

| Variables (with `gin_blame_` prefix) | Evidence / scope |
| --- | --- |
| `file_bufname`, `nav_bufname`, `detail_bufname`, `file_fragment` | Existing link/reload/legacy-path tests cover names and paths through navigation. |
| `paired_bufnr_file`, `paired_bufnr_nav`, `paired_bufnr_detail` | Each of the three panes now exposes the other two pane numbers under the pinned names. The link test checks all six edges after opening, selecting, moving backward and reloading, including repair of a removed link. |
| `result`, `line_map`, `file_line_to_physical` | Structured metadata, group-size, dictionary-type and navigation tests cover the implemented data contracts. Per-line raw metadata remains a Lua extension. |
| `history`, `history_index` | Both panes retain history entries and zero-based positions; initial index is -1. Navigation and hidden-pane restoration are tested. |
| `detail_last_commit` | Existing detail tests cover commit changes, dividers and failed queries. |

Previously, the three `paired_bufnr_*` names were missing even though Lua's own
`file_bufnr`/`nav_bufnr`/`detail_bufnr` links worked. Those existing Lua links remain
available. The new aliases are assigned from the same pane IDs on every read;
they do not add another cleanup callback or alter the companion-buffer unload
policy. This closes the thirteen-name presence inventory, not every possible
lifecycle transition or the full Blame migration checklist.

## Null default-mapping flags

The pinned list, buffer, diff and blame ftplugins use Vimscript truthiness for
`gin_*_disable_default_mappings`; `!v:null` is true. Lua previously treated
`vim.NIL` as truthy and consequently omitted the default keys. The shared list/
jump installer and both blame default-key branches now treat null as enabled,
like an unset flag or zero. Plug action definitions remain available independently.

Ten filetype fixtures set the corresponding flag to `vim.NIL` and verify the
buffer-local Enter mapping; blame and blame-nav also verify older/newer keys.
All ten failed before the change and pass afterward. Existing tests continue to
cover disabled defaults and user mapping preservation. This change addresses
null specifically and does not claim complete Vimscript coercion compatibility
for arbitrary strings, lists or dictionaries passed as flag values.

## Null editor-proxy flags

The editor's `gin_proxy_apply_without_confirm` check now treats `vim.NIL` as
false, matching the pinned Vimscript condition. Previously a null setting skipped
confirmation and applied the edited commit message. The real Git cancellation
test now covers unset, false, zero and null settings: each prompts once, rejects
the commit on `no`, clears the editor message and preserves the staged content.
The existing numeric-one test continues to cover intentional automatic applying.

`gin_proxy_disable_accept_and_cancel_aliases` likewise treats null as false.
The alias lifecycle matrix adds null for gitcommit/gitrebase with no preexisting
command, a global Accept or a buffer-local Cancel, checking installation, user
command preservation, repeat sourcing and cleanup. Before these fixes, the null
confirmation case committed successfully and all six null alias cases failed.
This closes these null-value differences without claiming arbitrary Vimscript
coercion semantics for other setting types.

## Vimscript coercion for editor confirmation and aliases

The two flags implemented in pinned Vimscript (`gin_proxy_apply_without_confirm`
and `gin_proxy_disable_accept_and_cancel_aliases`) now use Neovim's native
Vimscript condition conversion through `gin.util.vimscript_flag`. The setting
name is quoted with `string()` and supplied to `get(g:, ..., 0)`; setting values
are never interpolated as code. This avoids duplicating Vimscript's numeric
string conversion and its errors for unsupported condition types in Lua.
Denops-validated editor/askpass flags are not routed through this helper.

Real Git cancellation cases now include string zero, empty string and a
nonnumeric string (`"true"`): all must prompt and reject on `no`, rather than
silently commit. The alias matrix adds string zero/one, nonnumeric and empty
strings for both filetypes and all existing-command cases. Before the change,
three confirmation cases and eighteen alias cases failed. Existing numeric-one
application and alias-disable cases still verify the true branch. This extends
the preceding null fix to the actual native conversion rule for these two flags.

## Native condition conversion for ftplugin mapping flags

The list, buffer, diff and blame mapping installers now use the same native
Vimscript flag reader as the editor aliases. This extends the earlier null fix:
string zero, empty strings and nonnumeric strings keep defaults enabled, while
numeric strings such as `"1"` and `"0x1"` disable them. The pinned ftplugins use
`!get(g:, ...)`, so Lua truthiness is not an equivalent condition.

The ten-filetype matrix now covers six representative values and checks both
mapping installation and omission; blame also checks its older/newer keys.
Thirty cases failed before this change, all for false-valued strings. Existing
reload and user-mapping preservation tests continue to exercise the installation
lifecycle. Denops-validated Patch/Chaperon flags retain their separately documented
boolean/numeric contract and are not passed through Vimscript coercion.

## Editor and askpass opt-out validation

`gin_proxy_disable_editor` and `gin_proxy_disable_askpass` now reject strings,
lists and dictionaries before starting Git. Both settings are checked before
creating the RPC server or askpass launcher. Previously these truthy Lua values
silently disabled the proxy. Null and unset settings retain the enabled default.

The pinned Denops source validates booleans, while its help documents numeric
zero defaults. Lua deliberately retains the existing boolean/numeric contract
(including the documented 0/1 settings), as with the previously documented
Patch/Chaperon mapping flags. This is distinct from native Vimscript conversion
used by confirmation and alias flags; string `"0"` is not accepted here.

Six real-command tests supply invalid values with the other proxy already
disabled, require the named setting error, and verify a Git alias never writes
its spawn marker. They failed before validation was added. Boolean enable/disable
coverage complements the existing independent numeric opt-outs and null-default
tests, while the credential and editor integration tests still exercise the
actual proxy launchers.

## Editor opener failure handling

An explicitly false `gin_proxy_editor_opener` no longer falls back to `tabedit`.
Only an unset value gets the default; non-string values produce a named setting
error inside the request handler, which returns failure to the Git editor client.
Unsupported opener strings continue to use the existing opener validation.

Five real Git commit cases cover false, zero, null, a list and an unsupported
string. Each must finish with a nonzero Git status, expose the opener error on
stderr, leave all windows/tabs intact and preserve the staged content. Before
the fix false opened an editor and left Git waiting; the other invalid types
already failed but lacked the named type diagnostic. Test cleanup cancels an
unexpectedly opened editor before reporting failure. Existing keyboard-driven
fixtures still cover every supported opener and successful apply/cancel flows.

## Editor opening failure with unsaved work

A real Git commit test now uses the valid `edit` opener while the current file
has unsaved changes and `hidden` is off. Opening the commit editor must fail with
E37, release Git with a nonzero status, retain the original current buffer and
window/tab IDs, and preserve both unsaved text and its modified flag. The working
file and index must still contain the staged original content. This complements
the invalid-opener tests by exercising a failure from Neovim's editing operation.

The existing implementation passes without modification. Temporarily forcing
`bang=true` for editor opening makes this new test fail while the other editor
tests pass. The fixture cancels any unexpectedly opened editor before reporting
the failed expectation, so a regression does not leave Git waiting indefinitely.

## Proxy child listener environment

The editor command and askpass shell launcher now clear `NVIM_LISTEN_ADDRESS`
only for the proxy Neovim they execute. The separately named
`GIN_EDITOR_ADDRESS` still identifies the parent RPC server. If an explicit Git
process environment retains the parent's legacy listener address, an unmodified
proxy child attempts to bind that occupied socket and fails before running its
client script. The ordinary Neovim process launcher sanitizes simple inherited
values, so the regression fixtures explicitly pass the value in the Git process
options; ordinary inherited-environment tests alone did not reproduce this issue.

The real commit and credential fixtures now run both with the usual environment
and with an explicitly retained, live parent listener address. Both explicit
cases failed before the launcher change. Afterward the commit records the edited
message and the credential command obtains both prompted values; the parent
Neovim's environment value remains unchanged. This covers the existing POSIX
shell launchers and does not establish additional platform support.

## Proxy listener recovery

`editor.environment()` now checks whether its cached RPC address is still in
Neovim's live server list and starts a replacement listener if it has stopped.
Previously the stopped address remained cached, making subsequent proxy clients
fail with connection refused until the Lua module was reloaded. A healthy
listener is still reused, and both-disabled proxy settings still return before
creating a listener.

A real Git alias invokes the askpass launcher after the test stops only Gin's
own listener. It must receive the prompted value through the replacement server;
the returned address must be live and stable on repeated environment reads.
The fixture restores the old listener on failure so a failing regression does
not contaminate later proxy tests. This verifies recovery before a new operation,
not migration of an already-running client whose connection was interrupted.

## Keyboard editing during synchronous waits

`vim.wait` serviced proxy RPCs but left ordinary editing keys queued, so a
keyboard-driven `Gin ++wait commit` opened its editor and then stalled. The wait
loops now process input while a fully initialized Git editor request is pending.
The consumed key is put back at the front of the queue to preserve input order;
requests are tracked independently of the current window so preview editors can
be entered with normal window navigation.

The interaction suite runs commit Apply through all five openers, confirmed wq,
Cancel, rejected quit, and two consecutive rewords both asynchronously and with
++wait. It checks the actual Git history, file content and index, not just editor
visibility. A separate case commits through synchronous GinBuffer. All 19 cases
pass on Neovim 0.10. Nested commands and other synchronous mutation workflows are
not covered by this evidence; the overall migration checklist remains open.


## Branch views during rebase and bisect

Two real-repository cases cover the previously unaudited operation labels: a
rebase stopped by a content conflict and bisect stopped at an intermediate
commit. GinBranch output must exactly equal native `git branch --list -vv` with
no color, no verbosity, and a custom abbreviation length, both on first read and
reload. The active row must retain the operation label; yank:commit must select
the actual detached HEAD. Reading and selecting must preserve index/worktree
status, and abort/reset must restore the original main branch, commit and file.

Both cases pass without changing the implementation. Replacing the operation
labels with plain HEAD makes both fail on the displayed output. This closes the
rebase/bisect display and commit-selection evidence gap; it does not validate
mutating branch actions against detached operation rows.

## Branch echo candidate records

The branch echo action previously exposed executor metadata, losing the pinned
parser's record, active flag, upstream, message and symbolic-reference origin.
It now gathers a display-facing record separately from the refs used by mutating
and navigation actions. Alias records omit commit/message; remote targets in an
all-branches view retain their displayed `remotes/` prefix. Current local branches
omit a worktree location, as native branch output does.

A real repository with an upstream, a linked worktree, a remote ref and its HEAD
alias checks the complete JSON objects in default and all-branches views, with
and without explicit color suppression, before and after reload. The four
all-branches expectations were independently passed through the pinned TypeScript
branch parser and matched exactly. Existing structured selection for custom
formats remains an extension; this fixture does not claim parser equivalence for
arbitrary format/encoding options or remote-only listings.
