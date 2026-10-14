# Migration scope

Reference: vim-gin `24cce091cfa32c013bc53cf4ff8f721d6690cf24`.
The haiku55 trial is not used as implementation input.

The following scope comes from the pinned plugin, autoload, ftplugin, and
Denops source trees. A checked item means implemented and tested for its stated
scope, not proof of complete upstream parity.

- [x] Pin upstream and mini.nvim; headless mini.test harness.
- [x] Git process execution and worktree discovery (files, subdirectories, symlinks, linked worktrees).
- [x] Gin: arbitrary commands, argument expansion, modifiers, wait, postprocessors, indicators, events (functional audit and subsequent boundary fixes below).
- [x] GinBuffer: command output buffers, URI reads, reload and decorations (functional scope audited below).
- [x] GinStatus: status display, path selection and all status actions (functional scope audited below).
- [x] GinBranch, GinTag: parsed views and ref actions (functional scope audited below).
- [x] GinLog, GinReflog: parsed views, navigation and commit actions (functional scope audited below).
- [x] GinStash: parsed view and stash actions (functional scope audited below).
- [x] GinEdit: revision and index buffers with write-back; working files via edit actions (functional scope audited below).
- [x] GinDiff: revision selection, read and unified-diff navigation/folding (functional scope audited below).
- [x] GinPatch: staging/unstaging partial changes (functional scope audited below).
- [x] GinChaperon: conflict panes and resolution (functional scope audited below).
- [x] GinBlame: blame navigation, history and detail (functional scope audited below).
- [x] GinBrowse: remote URL generation and opening (functional scope audited below).
- [x] GinCd, GinLcd, GinTcd and worktree context.
- [x] Shared actions: choice, repeat, help, range handling and Plug mappings (functional scope audited below).
- [x] Editor/askpass proxies, commit/rebase integration (functional scope audited below).
- [x] Branch/traffic/worktree components and component events (functional scope audited below).
- [x] Help, syntax, highlights, options and default mappings in Lua (including compound FileType after-ftplugin lifecycle).
- [x] Full command/action audit against the pinned source and real Git-state integration tests (public-surface inventory and per-view functional ledgers below).
- [ ] Resolve the pinned writer BOM/end-of-line policy difference and apply/document the chosen contract before declaring the migration complete.

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

Gin and GinBuffer remain unchecked above because their full option and UI scope
is still incomplete. GinStatus's functional audit is recorded below. No full
upstream parity claim is made.
URI arguments use whitespace/backslash escaping to preserve argv boundaries
when reloaded; exact upstream URI interoperability still needs an audit.
Unstaging a rename resets both destination and original paths, so the whole
rename leaves the index. This differs from upstream's destination-only reset.

Shared choice/repeat/help/alias dispatch and file edit/yank actions are now
implemented. Their complete mapping and customization compatibility still needs
an audit. GinEdit supports revision and index reads, addressed reads and index
writes; its functional audit and tested encoding boundaries are recorded below.
Full upstream option parity remains open. Index writes use hash-object/update-index
with the existing file mode and clean filters, avoiding temporary replacement
of working files.

GinDiff now displays working-tree, cached and revision comparisons and backs the
status diff actions. Jumps resolve working/index/revision targets, including the
merge base for three-dot comparisons. File folds show status and change counts.
Addressed reads support encoding/fileformat overrides; command buffers also retain encoding/fileformat options on reload.
Buffer/diff processors transform successful Git output and survive reloads/reads.
The functional navigation/folding audit and its combined-diff boundary are
recorded below. GinPatch provides three/two-pane diff editing
with index write-back and status actions. Its functional completion audit and
Visual-range compatibility boundary are recorded below.

GinChaperon provides conflict panes, directional resolution mappings, supporting
commit logs and status actions. Opening the view edits only the buffer; writing
and staging remain separate steps. Its functional completion audit is recorded
below; full shared option compatibility remains in the command audit.
When there is no in-progress operation head,
its dependent supplemental logs are omitted instead of running an invalid log
command as upstream does.

Next work: remaining buffer/diff options and parsed views with direct
Git-state tests. Audit every pinned command, option, mapping, event and component
before marking the migration complete.

GinBranch now displays structured ref metadata and supports switch/delete/yank
actions, plus branch/worktree creation and moves. Interactive rebase and merge
editor integration have real Git tests below. The ref-view functional audit is recorded below; complete option/display
compatibility remains on the broader checklist. Branch views refresh after
GinCommandPost while preserving the current view.

Worktree creation supplies `-b` when the requested branch differs from the
selected starting ref; the pinned implementation omits it and fails that case.

Branch merge actions support ff/no-ff/ff-only. Later tests exercise message
editing through the editor proxy as well as cancellation and ff-only rejection.

GinTag now provides listing, show/delete/switch/yank actions and command-driven
refresh. Custom formats, parsing, decoding and emoji handling have dedicated
regressions below. Browse/echo consumers and show variants are included in the
ref-view functional audit below.

GinLog now displays history with revision/path filters, show/yank actions and
command-driven refresh. The history functional audit below covers commit
actions, candidate parsing and display; full option compatibility remains open.

GinLog cherry-pick/revert actions include parent-one/parent-two variants.
Revert supplies --mainline only when selected, correcting the inverted condition
in the pinned implementation. The mainline matrix uses a fixture-local editor
configuration; other history-action fixtures exercise the editor proxy.

GinLog reset actions now cover default/soft/hard/merge/keep modes. Tests assert
actual HEAD, index and worktree state rather than only command output.

GinLog lightweight tag creation and force replacement are implemented.
Annotated tag actions and the default tag alias now use the editor proxy.
Signed tag actions use the same proxy with Git signing configuration.

GinLog fixup and instant-fixup are implemented. Instant autosquash starts at the
selected parent (or --root), correcting the pinned double-parent traversal.
Amend/reword and their instant variants use the editor proxy and have real
history/content assertions, including cancellation.

GinReflog now uses the shared history display and implemented commit actions,
with separate default/persistent arguments and mapping settings. Its functional
coverage and remaining compatibility limits are recorded with GinLog below.

GinStash now lists saved changes with apply/pop/drop, show/yank and automatic
refresh. Its functional audit covers browse/echo, selected refs, custom formatting
and emoji/encoding below. Combined-diff show navigation remains outside the
ordinary unified-diff navigation supported by the pinned parser.

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
still need auditing. Emoji options and raw read overrides have dedicated
regressions below; broader parser/UI parity remains open. Source/attribution reload now
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

## Status echo candidate records

Status echo now exposes the pinned `XY`, absolute `path`, and optional absolute
`origPath` fields instead of the executor's lowercase status, relative paths and
buffer line number. As in the pinned parser, the first blank status column is
shown as a dot. The display projection leaves internal staging/unstaging and
file-action records intact.

A real repository exercises staged, unstaged, staged-and-unstaged, deleted,
renamed and untracked paths. The complete selection, rename-only selection and
header-only empty selection are checked before and after reload, with unchanged
Git status afterward. The expected six records were independently verified using
the pinned TypeScript parser and its gatherer's absolute-path conversion. The
Lua path handling continues to preserve literal filename bytes; this test does
not establish equivalence with upstream's quoted-path parser for control bytes.

## Log and reflog candidate range boundaries

The standard history parser now uses the pinned gatherer's `getbufline` range
rules: independently clamp both endpoints to line one, return an empty selection
for reversed/out-of-buffer ranges, and preserve inclusive endpoints. Previously
`{0, 0}` returned no candidate and negative end lines used Neovim API indexing
instead of the pinned lower-bound rule. Buffer zero is resolved to the current
buffer before invoking Vim functions, including the custom-parser path.

Real log/reflog views check six boundary ranges with both standard and custom
patterns, using both explicit buffer numbers and zero. The original implementation
failed the zero-endpoint case.


## Component functional-scope completion audit

The pinned three component modules expose six getters: branch/traffic ascii and
unicode, plus worktree name/full. The Lua modules and legacy Vimscript wrappers
implement all six. `test_component.lua` verifies the rendered strings against
real diverging Git history, legacy statusline evaluation, no-upstream/detached/
unborn branches, file-buffer repository selection, directory changes, trailing
spaces, leaving a repository, failed-query retention/recovery, and rejection of
late results from a previous repository. Event cases observe updated values in
the callback and verify that unchanged refreshes do not emit events.

The audit found one shared-cache difference affecting users: querying only a
branch component could report errors from unused traffic queries and emit an
event for an unused worktree value. The cache now tracks requested component
kinds, filters diagnostics and change notifications accordingly, and schedules a
refresh when a new kind is first requested. An isolated child-Neovim case uses
branch alone with verbose enabled, switches between repositories with the same
branch name, then activates traffic and checks that its diagnostic becomes
visible without an explicit refresh.

This closes the component functional checklist. The runtime deliberately shares
Git results, updates on first use and DirChanged, and suppresses stale replies.
It does not reproduce Denops startup events or the upstream 100 ms per-module
TTL caches; the shared 100 ms component-event debounce remains. These runtime
choices do not establish completion of the other command/API migration items.

## Browse flag parsing and literal paths

GinBrowse previously rejected `--`, preventing literal dash-prefixed paths, and
parsed only exact spellings of a small flag list. It now uses the shared pinned
flag grammar and treats tokens after the separator as positional arguments.
The command follows the pinned browse dispatcher: boolean options depend on flag
presence, unused parsed flags are ignored, and repeated remote flags are rejected
because the upstream grouped value is not a string.

Real-Git tests browse committed `-note.md` and `++repository` paths after the
separator, exercise attached short-flag values and explicit/repeated boolean
values, and prove duplicate remote validation leaves the target register and
browser untouched. This closes the command-parser gap, not the wider hosting
provider URL audit inherited from upstream's git-browse dependency.

## Browse SSH transport ports

Remote URLs such as `ssh://git@github.com:2222/owner/repo.git` were rejected
because the transport port was included in the provider/alias lookup key. The
port is now removed from the hostname before looking up the provider and building
the HTTPS base, matching upstream's use of URL.hostname. Four real-repository
cases cover GitHub, GitLab, Bitbucket and an aliased GitLab host, checking home
and file permalink URLs while leaving the configured fetch URL unchanged.

Evidence was checked against deno-git-browse v1.0.1's
[hostname lookup](https://github.com/lambdalisue/deno-git-browse/blob/v1.0.1/hosting_service/mod.ts)
and [GitLab URL base](https://github.com/lambdalisue/deno-git-browse/blob/v1.0.1/hosting_service/services/gitlab_com.ts),
as well as cached 1.1.6 providers. Pinned vim-gin declares a ^1.0.1 dependency,
not an exact transitive version; the current registry did not resolve exact
1.0.1, so its GitHub tag source was inspected directly. Newer-only provider
features and other URL parsing edge cases remain outside this verification.

## Browse path line suffixes

GinBrowse now recognizes the upstream `path:line` and `path:start:end` forms.
Previously the suffix was embedded in the URL's filename. Parsing precedes Git
object classification, so directory ranges are ignored; a single zero omits the
line link, while explicit two-endpoint ranges retain both endpoints even when
equal. Ex command ranges are formatted into the same path representation as in
the pinned browse command. The Lua URL helper still accepts its separate range
option for callers already using that API.

The reference is deno-git-browse v1.0.1
[object URL parsing](https://github.com/lambdalisue/deno-git-browse/blob/v1.0.1/object_url.ts)
and the pinned command's `formatPath`. Real repository cases cover all three
providers, single and paired lines, equal endpoints, leading zeroes, single zero,
and directory ranges. Existing Ex-range and permalink tests remain in the suite.

## Browse encoded remote repository paths

Remote repository paths now preserve existing percent escapes instead of encoding
the percent sign a second time. This matches URL.pathname handling in the
upstream URL base formatter. The change is limited to remote paths: literal Git
filenames continue to be encoded when constructing a file URL.

Three real-repository cases cover HTTPS, SSH and scp-style remotes, checking both
home and file permalink output and the unchanged configured fetch URL. A fourth
case commits a filename containing literal `%20` and checks its `%2520` URL while
also preserving a double-encoded remote repository name. The downloaded v1.0.1
URL base formatter was executed separately and confirmed both remote escape
expectations. Malformed escape sequences and other URL canonicalization details
remain outside this check.

## Browse remote URL component normalization

Remote parsing now separates scheme, authority and repository path. HTTP(S)
hostnames are case-normalized, userinfo is removed from the authority, and query
and fragment components are excluded from the repository path. A trailing slash
is removed before the `.git` suffix; URI schemes containing plus signs are also
recognized. Existing scp-style remotes and percent-escape handling are retained.

Seven cases failed before the change: uppercase HTTPS/hostname, trailing slash,
query, fragment, userinfo plus query/fragment, an SSH port plus query/fragment,
and git+ssh. Real repositories now produce the expected home and commit URLs
without rewriting their fetch configuration. The expectations were checked by
executing the v1.0.1 URL-base formatter with native URL parsing. This covers the
listed representations; full WHATWG URL canonicalization is not claimed.

## Browse request lookup from complete merge messages

Request lookup now inspects complete commit messages and the full ordered merge
ancestry, rather than only subjects and the first merge. This fixes GitHub
requests identified in a body or after an intermediate unlabeled merge. GitLab
`See merge request project!N` messages produce `/-/merge_requests/N` URLs, including
aliased GitLab hosts. Bitbucket continues to report that no request route exists.

This request feature follows git-browse 1.1.6's `pull_request_url.ts` and provider
extractors, inspected from the local Deno cache. That version satisfies pinned
vim-gin's ^1.0.1 dependency and supplies the public --pr behavior; GitLab request
support is not attributed to the minimum 1.0.1 provider inspected for basic URLs.
Remote default-branch discovery retains the existing local remote-HEAD/main
policy rather than adding a network query through `git remote show`.

Real histories contain an intermediate unlabeled merge and a later request ID in
the merge body, with remote HEAD pointing to trunk. Tests cover lookup from the
topic commit, the GinBrowse command on the merge, and the history browse:pr:yank
action for GitHub, GitLab and an aliased host. Missing-request errors are checked
for both supported request providers and the unsupported Bitbucket route.


## Browse functional-scope completion audit

The pinned browse dispatcher and command wrapper are accounted for by the Lua
command and action handlers. The functional checklist is now complete:

| Public behavior | Current evidence |
| --- | --- |
| Revision/path selection, Ex ranges and repository/worktree options | Real file, directory, revision and status/history action fixtures; zero address and path-suffix cases |
| home, commit, permalink and request routes | GitHub/GitLab/Bitbucket routes, real merge ancestry and GitLab aliases; unsupported/missing-request errors |
| Remote selection and aliases | Containment/ancestry and origin preference, explicit remote, validated alias dictionaries |
| Argument handling | Shared flag grammar, separator/literal paths, repeated remote rejection; default/persistent settings audit |
| Copy and no-browser output | Named registers, bare yank forms, current-file range URLs and action variants |
| Open dispatch and errors | Native vim.ui.open reaches vim.system with the generated URL; missing-handler and spawn errors propagate after the requested yank |

The open tests replace only the process launch while exercising the native
opener, and simulate opener availability for portability. They do not launch an
external browser or prove OS application registration. Removing the plugin's
open call makes all three dispatch cases fail. Bare ++yank and ++yank= are also
verified to populate the unnamed register.

Compatibility boundaries remain explicit: native Neovim opening replaces
systemopen; request lookup uses git-browse 1.1.6 and local remote HEAD/main;
nested GitLab repository paths and literal filename handling retain the Lua
implementation's extensions. The URL tests establish the supported remote forms,
not complete WHATWG canonicalization. Other migration checklist items remain open.


## Shared action functional-scope completion audit

The pinned action/core.ts responsibilities are covered by gin.action: action
registration, aliases, discovery/completion, dispatch with a captured range,
choice, repeat and reduced/full help. Existing action tests verify global/local
mapping precedence, user aliases and callbacks, expression/Ex mappings, range
restoration after errors, saved-action validation, empty choices, help filtering
and JSON echo. View-specific registration oracles inventory the available Plug
names; they are not substitutes for each view's behavior tests.

New child-Neovim interaction cases exercise the default status mappings through
real keyboard input. A Visual selection invokes choice with `a`, completes
`stag<Tab>` to stage, and stages exactly the two selected files. Repeat at a new
cursor stages only the remaining file. A second case cancels native input with
Ctrl-C, preserves the prior action and empty index, then repeats at a new row.
Both cases inspect Git's index; the successful workflow also verifies staged and
working-file content. Synchronization waits for the refreshed status content as
well as the post event, avoiding reads during the scheduled reload. Removing
choice completion makes the first case fail.

This closes the shared-action functional checklist. Native vim.ui.input supports
replacement UIs; help columns use display widths rather than JavaScript string
lengths. Neither change introduces a Denops dependency. View-specific mutation
semantics and the broader command/URI audit remain separate checklist items.

## Status removal and original-path action evidence

Status action tests now exercise two previously registration-only behaviors.
For rm/rm:force, two files have distinct HEAD, index and working contents:
ordinary removal rejects the selected file without dropping its index entry;
forced removal drops only that entry, retaining the other staged file, both
working files and HEAD contents. This checks the pinned action/rm.ts use of
--cached and its force variant against real Git state.

For yank:path:orig, a range containing a staged rename and a modified ordinary
file yields the absolute original path followed by the ordinary entry's empty
value. Selecting only the ordinary file clears the register. Repository status
is unchanged. The expected empty-row behavior follows status/edit.ts's origPath
projection and action/yank.ts's newline join. These cases extend functional
evidence without closing the broader status checklist.

## Unstage intent conversion failure ordering

The pinned action/stage.ts handles unstage:intent-to-add by resetting newly
added files, converting them to intent-to-add, then resetting other selected
files. Lua previously reset both groups before conversion. If a newly added
file disappeared after status was displayed, conversion failed after the other
files had already lost their staged contents.

The Lua action now preserves the pinned ordering. A real Git regression deletes
the new file after opening status and confirms that conversion fails while the
other file retains its staged content. The earlier successful reset still
refreshes status. Restoring and staging the missing file, refreshing the view
and retrying converts it to an empty intent entry and unstages the other file,
preserving both working files. The regression failed against the old ordering
because the tracked index contained HEAD content instead of its staged content.

## GinStatus functional-scope completion audit

The pinned command/status/main.ts, command.ts and edit.ts map to gin.status's
argument validation, URI construction, reads, candidate selection and action
installation. The allowed flag inventory matches the pinned command. Status
tests cover default and persistent arguments, explicit worktree selection,
flag grouping and separators, path filters through reload, legacy URI reads,
encoding, Git colors and literal filename bytes. Shared command declaration,
ftplugin, mapping and buffer tests cover the common command/UI contracts.

Every action family initialized by status/edit.ts has functional evidence:

| Pinned action family | Lua behavior and evidence |
| --- | --- |
| core, echo | Visual selection, keyboard choice/completion, cancellation, repeat, aliases/help; exact public echo fields for tracked, renamed and unknown paths |
| add, stage | Forced add, intent entries, deletion, stage/unstage from subdirectories and literal paths; partial failure ordering and completion events |
| reset_file | Destination-only reset of a staged rename, separate from whole-rename unstage |
| restore | Working/index restoration, ours/theirs and merge/diff3 conflict markers with unmerged index stages |
| rm | Cached removal, ordinary refusal and forced removal with working-file and other-index-entry preservation |
| stash | Selected-path stash, empty selection, keep-index with distinct staged and working contents |
| edit | Working, index and HEAD reads, split opening and persistent decoding settings |
| diff, diff_smart | Working/index/HEAD comparisons and smart selection for staged versus unstaged changes; persistent arguments |
| patch | Both panes and each single-side variant from status; real partial staging/unstaging from a subdirectory, retaining the other hunk and working contents |
| chaperon | Both sides and ours/theirs variants from status; real conflict resolution, still-unmerged index until explicit staging, then selected-side index contents |
| browse | Status-selected path from a subdirectory; shared provider, remote, register and opener coverage in the Browse audit |
| yank | Named-register absolute paths and original rename paths, including empty original-path rows |

The new single-side Patch cases verify a new tab, the two-pane layout and index
contents after applying just the first hunk. Chaperon's side cases now verify
both the working result and the index after explicit staging. Existing refresh
tests cover command events in visible/hidden views, file writes while hidden,
preserved window positions and action repeat after reload. The pinned action
registration oracle independently inventories Plug names and aliases; it is
not used as proof of mutation semantics.

This closes the status functional checklist. Known representation and behavior
differences remain explicit: NUL-delimited Git output preserves literal paths;
display quoting/sorting uses the decoded paths; unstage handles both sides of a
rename while reset remains destination-only; empty selections for Git mutation
file actions are no-ops. This is not an exact display-byte or unrestricted URI interoperability
claim. The broader command/URI audit remains open; subsequent Patch and Chaperon
functional audits are recorded below.

## Patch working-pane decoding

The pinned patch/command.ts forwards cmdarg to index, HEAD and working-file
opens. Lua previously forwarded encoding/fileformat only to the revision panes,
and its shared buffer opener ignored these options for ordinary files. Patch
now passes them to the working pane, and the opener lets Ex parse escaped
++enc/++ff arguments because nvim_cmd does not parse those arguments itself.
The structured opener route remains unchanged when neither option is present.

A regression uses UTF-8 bytes with CRLF and explicitly requests latin1/unix.
All three panes must then show the same Latin-1 interpretation and literal CR,
with matching fileencoding/fileformat. The old implementation showed UTF-8/DOS
in the working pane and failed this check. Writing an edited working pane is
verified against raw file bytes while the index remains unchanged. A filename
containing spaces and a bar also checks escaping through the Ex route. Existing
revision/index and command-buffer decoding tests remain part of validation.

## Patch transfers and reused panes

Real Git tests now cover HEAD-to-index and worktree-to-index diffput, plus
index-to-worktree diffput and worktree diffget. Each case changes only the first
hunk in the destination buffer, leaves disk and index unchanged until writing,
then checks the selected destination's persisted content and the other storage
location's unchanged content.

Reopening Patch while its index buffer remained visible previously reused stale
content after an external git add. The pinned patch/command.ts runs a non-forced
silent edit for each pane during initialization. Lua now also rereads each pane
before diffthis, preserving explicit encoding/fileformat options on that read.
A regression verifies that the reused index buffer shows the new staged content;
a separate case verifies that unsaved index edits survive a refused non-forced
reload and do not alter Git's index. The existing forced-decoding test guards
against losing ++enc/++ff during this initialization refresh.

## Patch Visual ranges

Four keyboard cases now verify forward/reverse Visual ranges with both index
diffget and worktree diffput. The selection spans two separated changes and
leaves a third change outside the range. Tests inspect the index buffer before
writing, confirm Git's index is still unchanged, then write and verify both
selected changes are staged while the working file retains all three changes.
Removing the range argument makes all four cases fail.

The Lua mappings explicitly pass the captured Visual range; the pinned mappings
use <Cmd>diffget/diffput without an explicit range. This is a Lua behavior
extension, not exact mapping execution parity. Both routes use Neovim's native
diff engine. Direct native range experiments also showed that a selection at
an insertion/deletion boundary need not behave like replacing the same numbered
lines in another buffer. The tests establish range propagation across separated
changes, not arbitrary line replacement within a diff block; help now states
that boundary. No production-code change was needed for these tests.

## Patch opener window identity

The pinned Patch command retains the window ID returned by its index opener.
Lua instead looked up the first window displaying that buffer. If GinEdit
already displayed the index, a botright split/vsplit could open a new window
but configure diff mode and restore focus in the old one.

Patch now retains the current window when the opener makes the index current,
using the buffer lookup only when the opened buffer is not current. Regression
cases for horizontal and vertical splits verify that the new window is focused
and diff-enabled while the original window remains outside diff mode. Both
side panes are omitted in these fixtures to isolate the opener's window choice.

The follow-up preview case requires retaining opener results directly: pedit
leaves the current window unchanged, so current-window preference alone still
selects the old index display. The shared Lua buffer opener now returns the
opened window as a second result alongside its existing buffer result. For
pedit it locates the current tab's preview window containing that buffer;
ordinary openers return the window they entered. Patch uses that result instead
of reconstructing it from the buffer. Tests cover both creation and reuse of a
preview window while a normal window already displays the same index, preserving
the original window's non-diff state. Existing split/vsplit tests remain in place.

## Chaperon opener window identity

The same buffer-to-window lookup also affected Chaperon when the working file
was already visible. Chaperon now consumes the shared opener's returned window
ID, matching the pinned command's infoWorktree.winid flow. Horizontal split,
vertical split and preview tests reproduce the old focus error and verify the
newly opened conflict window is selected and diff-enabled while the original
window stays outside diff mode.

Each opener is exercised with both side panes present and with both omitted.
The fixtures also verify conflict markers/content are stripped from the shared
working buffer and Git's index remains unmerged. As with Patch, test cleanup
clears previewwindow after retaining a single window, preventing preview state
from leaking into later cases.

## Chaperon stage refresh

The pinned initTheirs/initOurs routines reread their revision buffers with a
non-forced silent edit. Lua previously reused already visible stage buffers
without rereading them. After index stages changed, reopening Chaperon could
therefore display old conflict alternatives.

Chaperon now refreshes side panes before enabling diff, retaining explicit
encoding/fileformat options. It does not reload the working pane, where the
user may already have edited a resolution. A real Git regression replaces both
stage-2 and stage-3 blobs through update-index, reopens Chaperon in a new tab,
and verifies the same side buffers now show the updated contents. The test also
checks that a manual unsaved resolution stays in the working buffer and the
working file on disk remains unchanged. The old code failed by showing the old
ours content after reopening.

## Chaperon supplements during non-merge operations

Real conflict fixtures now cover cherry-pick, rebase and revert alongside the
existing merge case. Each fixture confirms the expected CHERRY_PICK_HEAD,
REBASE_HEAD or REVERT_HEAD commit, opens Chaperon with supplements enabled, and
compares all three rendered logs with Git output for that operation head,
HEAD, and their left/right history comparison. Side-pane content is checked
against the actual index stages 2 and 3, rather than assuming branch labels
retain their ordinary meaning during rebase or revert.

The tests also verify fixed-height supplement windows, final working-pane focus,
and unchanged index and disk content. This exercises every alias in the pinned
chaperon/util.ts inventory through a real stopped Git operation; no production
change was needed.

## Patch and Chaperon functional-scope completion audit

The pinned patch/main.ts and chaperon/main.ts argument routes and their
command.ts pane initialization routines map to gin.patch, gin.chaperon,
gin.diff_mapping and the shared opener. Functional evidence now covers the
following responsibilities, beyond simply registering mappings:

| Responsibility | Evidence |
| --- | --- |
| Path and command entry | Explicit subdirectory paths, current-file defaults, status actions, default/persistent argument inventory, explicit worktree and duplicate-option handling |
| Pane construction | Three panes, either side omitted, both sides omitted, tab/split/vsplit/preview opening, index/working focus and reused-buffer window identity |
| Patch transfers | Index diffget from HEAD/worktree; HEAD/worktree diffput to index; index diffput and worktree diffget; untouched hunk and storage-location checks |
| Visual selection | Forward/reverse ranges spanning two changes with a third excluded, real index writes, and a range-removal mutation that fails all four cases |
| Conflict resolution | Removal of conflict blocks, ours/theirs diffget and diffput, working-buffer changes before write, unchanged unmerged stages until explicit staging, final stage-zero blob contents |
| Reopening and read options | Fresh reused index/stage contents, preservation of unsaved index/manual resolution buffers, explicit Patch decoding and raw working-file write-back |
| Mapping configuration | Default/Plug mappings, disabled defaults, invalid setting rejection before layout changes, stale mapping cleanup and retained user mappings |
| Supplemental history | Real merge/cherry-pick/rebase/revert conflicts, exact Git log content, actual stage 2/3 blobs, height/focus and unchanged repository state |

New Chaperon side-diffput tests complete both transfer directions: resolving
from either side changes the working buffer first, writing updates only the
working file, and an explicit Gin add clears unmerged stages and records the
chosen content. These checks close the two functional checklist items above.

Compatibility boundaries are retained rather than counted as exact parity:
mapping-disable settings accept the documented numeric extension; omitted panes
do not leave unusable directional mappings; Lua Visual mappings pass an explicit
range; native diff boundaries determine the resulting edits. Conflict stripping
matches the pinned seven-character markers followed by a space, not arbitrary
custom marker sizes. Shared command modifiers/options and unrestricted URI/API
compatibility remain part of the separate full command audit. Completing these
functional items does not complete the overall migration.

## Mixed line endings in GinEdit

GinEdit's decoder previously inferred DOS format from any CRLF and split only
on CRLF. A blob mixing CRLF and LF then left newline bytes inside a buffer line,
causing nvim_buf_set_lines to fail. Explicit ++ff=dos had the same problem.

Automatic detection now retains mixed input as UNIX text, preserving literal
CR bytes, while explicit DOS decoding splits LF-only lines too and strips CR
from CRLF pairs. Three real index fixtures compare automatic, UNIX and DOS reads
with native Neovim file reads, including buffer text, fileformat and endofline.
They then write the index and inspect raw Git blob bytes while verifying that
the working file retains its original mixed endings. Both automatic and DOS
cases failed before the change. The pinned edit reader delegates decoding to
Denops buffer.decode; these tests use native Neovim behavior as the runtime
reference rather than asserting an unexecuted Denops comparison.

## Embedded LF in Mac-format index buffers

Explicit Mac-format reads had a related failure: splitting on CR left literal
LF bytes inside lines, which nvim_buf_set_lines rejects. Native Neovim instead
represents those bytes as CR within the buffer and converts them back to LF
when writing Mac format. GinEdit now performs those reversible conversions
around its CR line splitting/joining.

The regression reads the same blob through native edit and GinEdit, compares
buffer contents, and compares the written index blob with a native file write.
Both writes reproduce the original bytes, and the repository working file is
unchanged. The original decoder failed before a buffer could be loaded.

## Literal index path normalization

GinEdit's path normalization implicitly expanded environment variables and a
leading tilde. A repository path such as $GIN_EDIT_LITERAL/file could therefore
open a different index entry, while ~/file could be rejected as outside the
repository. The pinned edit command preserves relative filename strings.

Path normalization now disables environment expansion and protects a leading
tilde before normalization. Filename-expression expansion remains in the
earlier command argument layer. Two real repository fixtures use literal dollar
and tilde directories, plus a decoy path selected by the environment variable.
They verify the intended entry is read and written, the decoy index blob is
unchanged, and the literal working file is preserved. Both cases failed before
the fix: one read the decoy and the other raised an outside-repository error.

## Symlink index writes and clean filters

GinEdit's direct hash-object/update-index path preserves the existing index
mode, but previously used path-based clean conversion for symlinks as well as
regular files. Git add stores a symlink's target string without applying a
matching clean filter. GinEdit could therefore change that string unexpectedly
on write, even while retaining mode 120000.

Writes for mode 120000 now use hash-object --no-filters; ordinary file writes
retain their path-based clean filters. A real symlink fixture configures an
uppercase clean filter, confirms Git add leaves the original target lowercase,
then edits the index target and verifies its exact lowercase bytes and mode.
The working symlink and its target file remain unchanged. The fixture disables
fixendofline explicitly to retain the link blob's no-EOL representation. Before
the fix, the written target was incorrectly uppercased.

## Unicode encoding and BOM write-back

The BOM audit found two write defects: Latin-1 received an unwanted converted
BOM, and vim.fn.iconv did not convert UTF-16LE data at all on the supported
runtime, leaving UTF-8 bytes in the index. A Vimscript string conversion is not
a reliable transport for encodings containing NUL bytes.

GinEdit now uses an explicit Lua codec for UTF-16, UCS-2 and UCS-4 in big- and
little-endian forms, including UTF-16 surrogate pairs and embedded NUL. Generic
big-endian formats recognize a little-endian BOM on read. BOM insertion is
limited to the supported Unicode encodings; Latin-1 keeps its content without
a prefix. Other existing encodings continue through iconv.

Eight native-write comparisons cover UTF-8, Latin-1 and all six new codec
formats, using Japanese text and non-BMP characters where representable. The
tests compare raw file bytes with the index blob and read it back through
GinEdit. Separate cases verify an embedded NUL round trip and that an
unrepresentable UCS-2 write leaves the index, working file and unsaved buffer
intact. The codec rejects incomplete code units and invalid scalar/surrogate
sequences; this is explicit failure rather than a claim of native malformed-byte
replacement parity. No external converter or new runtime dependency is required.

## Binary index write options

GinEdit previously applied fileformat conversions and inserted a BOM even with
binary set. Native Neovim writes binary buffers with LF separators and no BOM,
while still honoring an explicitly set fileencoding on write. The encoder now
follows that observed behavior and retains its existing endofline handling.

Native-write comparisons cover both DOS and Mac fileformat settings with binary,
bomb and UTF-16LE fileencoding enabled. Literal CR inside a line is preserved,
separators are LF, and no final newline is added when endofline is off. The tests
compare raw bytes and verify the working file is unchanged. The old encoder
failed by adding a UTF-16LE BOM and converting the separator to CRLF.

## GinEdit functional completion audit

The pinned `denops/gin/command/edit/{main,command,edit,read,write,util}.ts`
provide command dispatch, revision/index opening, addressed insertion and index
write-back. The Lua routes are `plugin/gin-edit.lua` and `lua/gin/edit.lua`,
with shared opening and decoding options in `lua/gin/buffer.lua`.

| Functional scope | Exercised evidence |
| --- | --- |
| Revision and index reads | `tests/test_edit.lua` opens repository-relative paths from a subdirectory, checks immutable revision buffers and editable index buffers, and reads pinned upstream URI names with escaped roots/fragments. |
| Index-only write-back | Real Git blob assertions distinguish HEAD, index and working content; executable mode survives a missing working file, and symlink mode/target remain intact. |
| Filters and failure retention | Path-specific clean filters run for regular files and are bypassed for symlinks. Index-lock, required clean-filter and UCS-2 conversion failures preserve unsaved edits and existing index/working content. |
| Addressed reads | Insertion positions, change marks, empty source/destination buffers, FileReadPost and explicit decoding overrides are checked without changing destination encoding options. |
| Write completion | Successful writes clear modified and publish completion; eventignore suppression and a failing post-write hook have separate assertions. |
| Data representation | Native Neovim comparisons cover mixed LF/CRLF, Mac embedded LF, Unicode byte order/BOM and binary write formatting. Embedded NUL, empty blobs and no-final-newline writes have dedicated cases. |
| Consumers | Patch transfer tests persist selected hunks through the index buffer; Chaperon reads index stages. Shared edit actions cover working-file and revision targets in their existing functional audit. |

The final failure fixture makes a required clean filter reject a changed buffer,
then compares the entire staged-entry listing, original index blob, working
file and still-modified buffer. This tests failure before index publication,
complementing the existing index-lock failure after object hashing.

The checked scope is functional, not byte-for-byte Denops parity. Upstream
writes by temporarily replacing the working file and running git add; this port
hashes and updates the index directly. Native Neovim end-of-line and binary
write rules, unchanged working files, and retained unsaved edits on write
failure are deliberate behavior choices. The Unicode codec rejects malformed
or unrepresentable input; exhaustive encoding aliases, malformed-input
replacement behavior and automatic encoding detection are not certified here.
The broad command/options/API compatibility checklist remains open.

Validation: all 41 GinEdit cases pass on minimum Neovim 0.10.0. `make check`
and the integrated full suite pass (1,257 cases in 48 groups).


## Diff default-prefix reset

Git accepts `--default-prefix` to restore `a/` and `b/` after `--no-prefix`
or explicit source/destination prefixes. GinDiff already preserved the flag
when executing Git, but its shared jump/fold path decoder did not apply that
reset. For a real repository path `a/file`, `--no-prefix --default-prefix`
therefore displayed a spurious rename from `a/a/file` to `b/a/file` and could
open the wrong working path.

The decoder now restores the default prefixes in saved flag order before
applying reverse-diff swapping. Real Git fixtures cover reset after no-prefix,
reset before no-prefix, reset before/after custom prefixes and reverse diffs.
They assert the fold label and the actual opened working file and content.
The original implementation fails the reset-after-no-prefix fold assertion.

The pinned diffjump parser recognizes ordinary `@@` hunks only; its
`parser.ts` range regex does not accept combined `@@@` hunks. Combined-diff
navigation is consequently not established as an upstream-supported feature
by this source audit. The broader GinDiff functional checklist remains open.

Validation: `make check` and all 1,262 full-suite cases pass. All 61 GinDiff
cases also pass on minimum Neovim 0.10.0.

## GinDiff functional completion audit

The pinned `command/diff/{main,command,edit,read,commitish}.ts` routes map to
`plugin/gin-diff.lua`, `lua/gin/diff.lua`, the shared buffer insertion/opening
helpers, and `lua/gin/diffjump.lua`. The pinned `feat/diffjump` and
`feat/difffold` implementations provide the navigation and folding reference.
The checked scope is ordinary unified-diff display, revision selection,
addressed insertion, navigation and folding, with the boundaries below.

| Functional scope | Exercised evidence in `tests/test_diff.lua` |
| --- | --- |
| Comparisons | Working/index, cached, explicit revision ranges and status smart-diff dispatch use actual Git repositories with different HEAD/index/working content. |
| Reload and flags | Cached views, repeated filters, short/long flag order, escaped legacy URIs, encoding, processors and no-color options survive reload with expected output. |
| Jump targets | Working files, editable index buffers and immutable revisions are checked; three-dot old targets resolve the merge base and reversed diffs swap the targets. |
| Jump mappings | Old/new/smart Plug mappings run from Normal, Visual, Select and operator-pending modes without modifying Git state. Mapping disable options are covered separately. |
| Positions | A two-hunk fixture inserts a line in the first hunk and replaces a later line in the second. Context jumps select index line 26 or working line 27, preserve the cursor column and leave both contents/index entries unchanged. No-final-newline markers also have an offset regression. |
| Paths | Quoted Unicode/tab paths, literal backslashes, default/custom/no-prefix ordering, reverse diffs and deleted-file markers have direct target or fold assertions. |
| Folding | File status labels, custom/published prefixes, header-like removed text and clearing folds after a reload to an empty diff are checked. |
| Addressed reads | Reading a diff URI inserts output while retaining the destination's ordinary filetype and editability. |

The new position tests were mutation-checked: using the old hunk's start line
for the new side makes the new-side test land on `replacement` instead of
`line 26`; the old-side case still passes. The mutation was then restored.

These checks do not certify every Git output mode as navigable. Combined
`@@@` hunks are not recognized by the pinned diffjump range parser or this
port's parser. Arbitrary processors, word-diff, line-prefix and relative-path
output may change the structure expected by navigation. Explicit custom
source/destination prefixes are supported as tested above. Merge-base,
reverse/cached target handling, quoted paths and excluding hunk content from
header detection include corrections beyond the pinned implementation; this
is not a claim of identical upstream behavior. Full command/options/API
compatibility remains on the broader migration checklist.

Validation: all 63 GinDiff cases pass on minimum Neovim 0.10.0. `make check`
and the integrated full suite pass (1,264 cases in 48 groups).


## Tag deletion ordering and partial failure

The pinned `action/tag_delete.ts` dispatches one deletion per selected tag.
The normal-mode `bare/main.ts` dispatcher wraps each command in denops std v7
`helper.friendlyCall`, which reports an Error and returns so the loop can
continue. The Lua implementation instead passed every selected tag to one
`git tag -d` invocation. With the tested Git, a locked later ref made that
whole invocation fail, retaining even an earlier deletable tag.

Deletion now runs once per deduplicated selected tag, in selection order.
Each successful deletion retains the ordinary completion notification and
view refresh. Failures are collected while subsequent selected tags are
attempted, then propagated together to the Lua caller. This preserves the
port's explicit error reporting while matching upstream normal-mode progress
through the selection; upstream debug mode's immediate propagation is not
introduced as a separate Lua mode.

Two real Git fixtures lock either the first or second selected tag. They
verify that the other tag is deleted, the locked tag's object is unchanged,
the working file/index remain clean, the action reports failure, and the view
refresh contains only the retained tag. The batched implementation fails the
Git-state assertion; an intermediate fail-fast loop fails when the first tag
is locked. Minimum Neovim 0.10.0 passes all 20 tag cases after the final change.

Validation: `make check` and all 1,266 full-suite cases in 48 groups pass.


## Branch deletion continues through selected commands

The pinned `action/branch_delete.ts` dispatches each remote deletion, worktree
removal and local branch deletion separately through the normal-mode command
wrapper. Like tag deletion, a reported command failure does not terminate the
selection loop. The Lua action previously propagated the first failure before
attempting subsequent selected branches.

Both `delete` and `delete:force` now collect command failures while continuing
through the selected operations, then return those errors together. Successful
commands retain their existing completion notifications and view refreshes.
Symbolic aliases remain skipped, and the existing protection against removing
the current worktree remains in place. Worktree removal still precedes local
branch deletion, including Git's own refusal to delete a checked-out branch
when worktree removal fails.

Real Git regressions select the current branch followed by an ordinary merged
branch. They require deletion of the second branch despite rejection of the
first, an error result, unchanged HEAD/current branch/working file/index, and
a refreshed listing containing only the retained branch. Both ordinary and
forced deletion failed the second-ref assertion before the change.

Validation: all 45 branch cases pass on minimum Neovim 0.10.0. `make check`
and the integrated full suite pass (1,268 cases in 48 groups).


## Forced worktree and tag-switch boundaries

The pinned `action/worktree_new.ts` distinguishes ordinary creation from
`worktree:force` by its force flag; `action/branch_delete.ts` similarly forces
worktree removal and branch deletion only for `delete:force`.

New real Git cases verify both boundaries. Creating another checkout of an
already checked-out branch fails ordinarily without changing cwd or creating
the requested directory. The force action creates that checkout, enters it,
and preserves the branch refs and the contents of both worktrees. Deleting a
branch with a dirty linked worktree ordinarily reports failure and preserves
the dirty file/ref; forced deletion removes that worktree and branch, refreshes
the view, and preserves the main worktree's HEAD and file.

A separate GinTag case confirms that ordinary `switch` on an annotated tag
reports Git's rejection while preserving the attached branch, HEAD, index and
working file. Only the existing `switch:detach` action requests detachment;
the ordinary action is not silently converted to it.

All 68 branch/tag cases pass on minimum Neovim 0.10.0. These cases strengthen
the ref-action audit without completing the remaining browse/show consumer
checks or the broad option/API compatibility checklist.

Validation: `make check` and all 1,271 integrated full-suite cases pass.


## Branch and tag functional completion audit

The pinned `command/branch/edit.ts` and `command/tag/edit.ts` initialize the
ref views and their action families. Lua equivalents are `lua/gin/branch.lua`
and `lua/gin/tag.lua`, with shared choice/echo/browse behavior in `action.lua`
and `browse.lua`. Tests cover the following functional routes with real Git
state, rather than treating the registration oracle alone as proof of action
behavior.

| Functional scope | Evidence |
| --- | --- |
| Branch display and selection | `test_branch.lua`: local/remote/alias records, detached HEAD, linked worktrees, colors, abbreviation/verbosity, sorting, legacy URIs and custom multiline/NUL formats retain action targets. |
| Tag display and selection | `test_tag.lua`: lightweight/annotated objects, ordering/patterns, legacy URIs, custom multiline/NUL formats, colors, encoding and emojify retain selected refs. |
| Switch/new/move | Branch switching, forced replacement, orphan creation, branch rename, linked-worktree move and prompt cancellation have direct ref/cwd/file assertions. Tag switch rejection and explicit detach have separate cases. |
| Deletion | Ordinary/forced local and remote branch deletion, dirty worktrees, current-branch protection, tag selection, command failures, continuing subsequent selections and successful refreshes are checked. |
| Worktree creation | Selected starting refs, branch names, orphan empty indexes, default paths, cancellation and ordinary-versus-force duplicate checkouts are exercised. |
| Merge/rebase | `test_branch.lua` verifies ff/no-ff/ff-only, message editing/cancellation, rebase replay/exec, interactive Apply and instant-drop against resulting history. |
| Browse consumers | `test_browse.lua` now opens five ref view kinds with an opaque display format and HEAD advanced beyond the selected ref. Repository permalinks and commit URLs must resolve the selected commit, including peeling annotated tags. These tests use no-browser/yank and make no network request. |
| Echo/yank | Branch echo checks pinned local/remote/alias record shapes; tag echo checks the selected annotated object independently of display. Named-register/ref and commit yanks have existing cases. |
| Log/show | `test_log.lua` checks selected branch history and log filters. `test_tag.lua` checks annotated content and revision jumping; `test_show.lua` covers GinTag emojify with edit/split/vsplit/tabedit and the alias, including reload. |
| Shared interaction/events | The branch registration oracle, per-view Visual choice/repeat tests and action completion-suppression fixtures supplement the functional cases. |

This completion mark covers these functional ref-view routes, not every Git
flag, byte-identical default output or all custom parser expressions. Structured
metadata intentionally retains actionable refs when display formats change.
The existing worktree creation `-b` correction and current-worktree protection
are retained; multi-delete errors are propagated after processing the selection
rather than reproducing Denops' normal-mode error-message handling exactly.
Complete command/options/API compatibility remains open in the main checklist.

Validation: all 105 browse/tag/show cases pass on minimum Neovim 0.10.0. The
preceding worktree-boundary audit also verified all 68 branch/tag cases there.

The integrated full suite passes all 1,277 cases in 48 groups; `make check`
also passes.


## Stash functional completion audit

Pinned `command/stash/edit.ts` initializes browse, echo, show, apply, drop, pop
and stash-reference yank actions. `action/stash_{apply,pop,drop}.ts` deliberately
select only the first candidate, including a multi-line selection. The Lua
implementation in `lua/gin/stash.lua` follows that rule; it does not copy the
multi-delete behavior of Branch or Tag.

| Functional scope | Evidence |
| --- | --- |
| Listing and refs | `test_stash.lua` checks native/legacy flag grouping, filtering, reload, custom and multiline/NUL formats, encoding and emojify while retaining the selected stash reference. |
| Apply/pop variants | Four new real Git cases store different index and working contents for the same file and select all three visible stashes. Ordinary apply/pop restores working content with the base index; `:index` restores the saved index too. Apply retains all stash hashes; pop removes only the first selected stash and retains the other hashes in order. Refreshed row counts are checked. |
| Drop and failure | Existing cases drop only the first selected stash despite index shifting, and verify that a conflicted pop retains all stash hashes while exposing unmerged index entries. |
| Browse/echo/yank | Echo exposes stashRef/index/commit fields; multiline yank returns the selected reflog reference. A new no-browser case generates the commit URL for an older selected stash despite an opaque display format. |
| Show | Selected stash show verifies its saved URI target and combined-diff content. `test_show.lua` exercises all emojify openers and reload for GinStash. |
| Shared interaction/read/events | Per-view Visual choice/repeat, addressed legacy URI insertion and successful/suppressed action completion are covered by existing fixtures. |

This establishes the functional stash operations, not navigation within all
Git show output forms. Stash show normally emits combined hunks, which the
pinned diffjump parser does not support; displaying them is covered separately
from ordinary unified-diff navigation. The broader command/options/API audit,
including all pretty formats and parser-expression compatibility, remains open.

Validation: all 17 stash cases pass on minimum Neovim 0.10.0.

The integrated full suite passes all 1,282 cases in 48 groups; `make check`
also passes.


## History mainline action matrix

Both GinLog and GinReflog now have real Git coverage for `cherry-pick:1`,
`cherry-pick:2`, `revert:1` and `revert:2`. The fixture creates a non-fast-forward
merge with distinct changes on each parent. Cherry-picking onto the selected
parent must produce the merge tree; reverting from the merge must reproduce
that parent's tree. Each result must have exactly the previous HEAD as its
parent and a clean working tree/index, with no unresolved index entries.

The action receives a two-row selection whose first row is the merge. This
also checks the pinned `xs.at(0)` behavior: only that first selected commit is
acted upon. The eight cases cover both history view consumers and both parent
numbers, supplementing the existing ordinary pick/revert and parent-one revert
cases.

The pinned `action/revert.ts` has an inverted mainline condition: a nonempty
mainline omits the flag, while the empty variant supplies an empty value. The
Lua implementation already uses the intended mainline flag behavior, consistent
with the action names and Git, rather than reproducing that defect. This audit
adds evidence for the existing correction; it changes no production code.

Validation: all eight new cases pass on minimum Neovim 0.10.0. `make check`
and the integrated full suite pass (1,290 cases in 48 groups).


## Log and reflog functional completion audit

Pinned `command/log/edit.ts` and `command/reflog/edit.ts` initialize the same
commit-action families. `lua/gin/log.lua` implements both views, with separate
command settings and candidate parsing. The following source-to-test mapping
supports the functional completion mark; it does not certify every Git pretty
format, command option or custom parser expression.

| Functional scope | Evidence |
| --- | --- |
| Display, selection and reload | `test_log.lua` checks history order, revision/path/ref limits, graph/default/color formats, legacy URIs, custom parsers, line boundaries and rejection of hash-like display words. |
| Show/navigation | Selected show targets, per-view Visual Enter/choice/repeat and `test_show.lua` opener/emojify/reload fixtures cover both history consumers; diff navigation has its own ordinary-unified-diff audit. |
| Browse/echo/yank | Both views now verify that browse and echo target an older selected commit instead of HEAD. Existing ranges and yanks verify selected candidate order. |
| Switch | Ordinary switch rejects commit targets. Both views explicitly detach to the first selected older commit while preserving the newer main branch ref and clean file/index state. |
| Cherry-pick/revert | Ordinary operations and the preceding eight-case mainline matrix check Git trees, parentage, clean state and first-selection behavior in both views. |
| Reset | Default/soft/hard/merge/keep cases assert HEAD/index/worktree changes, keep-mode rejection and restoration of a reflog-only commit. |
| Merge/rebase | Selected commit merge, reflog rebase replay, interactive editor Apply and prompt cancellation are exercised. Branch tests separately cover merge variants and the shared rebase action families. |
| Tags | Lightweight, force replacement, annotated/default alias with message editing, verifiable SSH-signed force tags and cancellation have real-ref/content checks. |
| Fixup | Fixup/amend/reword, root autosquash and instant amend/reword verify history, messages, descendant preservation and staged-content handling; cancellation retains edits/history. |
| Addressed reads | `test_history_read.lua` checks custom/emoji output, explicit encoding, insertion marks, FileReadPost, unchanged destination options, empty output and failure preservation for both URI families. |

The added detach cases create a third commit, select rows two through three,
and require HEAD to become the second commit while main still points to the
third. This distinguishes first-selection behavior from either leaving HEAD
unchanged or processing all selected entries.

Existing corrections beyond pinned behavior remain explicit: revert mainline
flags, instant-fixup parent/root selection and ordinary unified-diff navigation
fixes are not claims of identical upstream execution. Complete options/API,
editor lifecycle and presentation compatibility remain on the main checklist.

Validation: 86 history/action/read cases pass on minimum Neovim 0.10.0. After
strengthening the detach fixtures with a newer HEAD, both changed cases were
rerun there successfully.

The integrated full suite passes all 1,294 cases in 48 groups; `make check`
also passes.


## Blame functional completion audit

Pinned `command/blame/{main,command,edit,history,detail,parser,buffer_utils}.ts`
provide the command, synchronized panes, commit selection, history and details.
The Lua equivalents are `lua/gin/blame.lua` and its plugin/ftplugin/syntax
integration. `tests/test_blame.lua` supplies the following functional evidence.

| Functional scope | Evidence |
| --- | --- |
| Layout and source | Subdirectory invocation opens attribution/content/detail panes, uses committed content despite a dirty working file, synchronizes cursors/scrolling, and retains structured commit and physical/source-line maps for populated and empty files. |
| Attribution/detail | Group continuations, relative-time boundaries, cursor-driven detail changes, divider retention, missing-commit detail clearing and stderr-only progress have direct assertions. |
| Commit navigation | Historical rename and quoted filename cases select source commits and parents. The new insertion-plus-rename fixture distinguishes current source line 5 from original line 2 and checks both synchronized cursors. |
| History | Back/forward restores revision, filename and physical positions; new selections truncate forward entries. Divider/no-parent actions and failed navigation retain usable views/history. |
| Reload/lifecycle | Either pane reloads the existing windows. Hidden/missing paired-file restoration, legacy names and stored context, missing-context errors and companion cleanup preserve unrelated buffers. |
| Integration/options | Filetype changes undo mappings/window pinning, disabled ftplugins are respected, remapped navigation survives reload, and encoding/fileformat/emojify settings survive history. Raw decoding overrides, literal source versus emojified metadata, divider signs and colors are covered. |

For the new regression, replacing `originalLineNumber` with the current
`lineNumber` made navigation land on physical row 1 instead of row 4. That
mutation was restored before the full run. The normal case also verifies that
back/forward navigation changes neither HEAD nor working/index state.

The checked scope is functional navigation/history/detail. Exhaustive blame
encoding behavior (including multibyte/BOM/Mac input), parser/UI parity and all
command/options/API compatibility remain on the broader checklist. These tests
do not imply that all such combinations are supported identically to Denops.

Validation: all 38 blame cases pass on minimum Neovim 0.10.0.

The integrated full suite passes all 1,295 cases in 48 groups; `make check`
also passes.

## GinBuffer failed-reload output retention

The pinned `command/buffer/edit.ts` calls Denops `buffer.concrete` after a
successful replacement. Its buffer-local restore autocmd retains the previous
successful content when a later Git command or processor fails. A direct
headless upstream probe confirmed that an initial `valid output` survives
`:edit` after the processor changes to consume stdin and exit 7. Upstream's
friendly error wrapper reports the error without throwing from `:edit`.

Lua previously propagated the error after Neovim had already cleared the
buffer, leaving an empty display. GinBuffer now retains the latest successful
lines, ANSI decorations, decoding options and filetype in buffer-local state,
restores that display when execution fails, and still propagates the execution
error to the caller. The snapshot belongs to the buffer and is discarded on
wipeout. Failed addressed reads leave the destination untouched and emit no
`FileReadPost`.

`tests/test_buffer.lua` covers Git and processor failures for both reload and
addressed read, plus a successful refresh followed by failure to prove that the
latest content, color spans, DOS line format and custom filetype are retained.
This closes the execution-failure retention gap; it does not finish the wider
GinBuffer/API audit or establish parity for decoding failures and all buffer
lifecycle operations.

Validation: all 1,300 mini.test cases across 48 groups pass; `make check` and
`git diff --check` pass. The 22-case GinBuffer suite and the subsequently added
latest-output decoration case also pass on Neovim 0.10.0.

## GinBuffer decoding failure and retry

The saved display now also covers failures after successful Git execution,
including decoding and replacement. Previously the executor-only error handler
left an empty buffer when the strict Unicode decoder rejected an incomplete
code unit. The regression test reads valid UTF-16LE output, replaces it with an
odd byte count, checks the retained text and encoding plus immutable/unmodified
state, then supplies valid new output and repeats the failure. This proves that
a failed decode neither poisons the snapshot nor prevents a later refresh.

This fixture exercises the Lua decoder's existing strict-error contract, not
byte-for-byte malformed-input parity with upstream's TextDecoder. Upstream's
`buffer.concrete` restore route follows its friendly error handler regardless
of which read stage throws. Arbitrary malformed-encoding parity and the wider
GinBuffer lifecycle/API audit remain separate outstanding work.

Validation: all 1,301 mini.test cases in 48 groups pass, including all 24
GinBuffer cases. Those 24 cases also pass on Neovim 0.10.0. `make check` and
`git diff --check` pass.

## GinBuffer functional audit

The checked GinBuffer item covers its command-output workflow, URI reads,
decorations and optional unified-diff features. It does not close the final
cross-command option/API/encoding audit.

| Pinned route / behavior | Lua evidence |
| --- | --- |
| `command/buffer/command.ts`: build an output URI and open the requested view | `test_buffer.lua` checks immutable output, split modifiers and a preview with explicit encoding/format while preserving focus; `test_show.lua` covers edit, split, vsplit and tabedit consumers and repeated reload. |
| `command/buffer/edit.ts`: execute Git, run processor, decode and replace | `test_buffer.lua` checks processor reuse, explicit encoding/format, stderr progress without echoing captured stdout, failures and successful retries. |
| ANSI decorations, monochrome and emoji replacement | `test_buffer.lua` checks highlight spans, removal in monochrome mode and emoji-dependent byte positions across reload and read. |
| `command/buffer/read.ts`: insert processed output | Addressed reads check inserted lines, marks, destination options and events; empty output, explicit encoding, both-channel progress and failed execution are covered. |
| Optional diff jump and fold setup | Empty `++diffjump` resolves HEAD and its parent with source navigation; mapping-disable behavior is checked separately. A direct `++difffold` command checks fold summary and clearing obsolete folds after reload, with index/working-file assertions. |
| Output lifetime and repeated reads | Native and legacy URI cases preserve special arguments; execution/decode failures retain the last successful display. An unload/reopen failure keeps the snapshot, a subsequent success updates it, and wipeout removes it. |
| Interactive commands inside the output view | `test_editor_interaction.lua` commits through synchronous GinBuffer using keyboard input and verifies the resulting commit subject. |

The added lifecycle, preview and fold cases pass without production changes.
The source comparison uses pinned `24cce091cfa32c013bc53cf4ff8f721d6690cf24`,
including `command/buffer/{main,command,edit,read}.ts`; no haiku55 input is used.

Remaining cross-cutting audit items include automatic encoding/format detection,
malformed byte handling, every built-in `++opt` alias, custom indicator/API
contracts, and the complete scratch-buffer write lifecycle. This functional
checkmark does not claim those broader contracts are complete. The pinned help
also says GinBuffer accepts bang and displays errors in its buffer, while its
actual command declaration lacks bang and its executor throws on failure; the
implementation and regression evidence above follow the executable routes.

Validation: all 1,304 mini.test cases across 48 groups pass. The 26-case
GinBuffer suite and subsequently added preview case pass on Neovim 0.10.0.
`make check` and `git diff --check` pass.

## Rebase cancellation and remaining terminal proxy gap

`test_editor_interaction.lua` now cancels an edited interactive-rebase todo
through actual keyboard input, both with and without `Gin ++wait`. The todo is
changed from `pick` to `drop` before `:Cancel`. Git must exit unsuccessfully,
without `GinCommandPost`, while HEAD, index entries and working content remain
unchanged and no rebase state directory remains. This complements the existing
consecutive-reword tests that exercise multiple successful editor requests.
The cancellation route matches pinned `proxy/server.ts` (clear the editor file
and return a failed editor status) and `autoload/gin/internal/proxy.vim`.

The proxy checklist remains unchecked: pinned `proxy/server.ts` sets process-wide
`GIT_EDITOR`, `GIT_ASKPASS` and its listener address at startup, and the pinned
help explicitly covers Git invoked from Neovim terminals. Lua currently builds
these overrides only for Gin child processes via `editor.environment()`; plugin
startup does not export them. Ordinary terminal Git therefore does not yet
inherit the proxy. This is a confirmed implementation gap, not merely missing
test coverage, and must be addressed before completing the proxy audit.

Validation: all 1,306 mini.test cases in 48 groups pass. All 21 keyboard-driven
editor interaction cases also pass on Neovim 0.10.0. `make check` and
`git diff --check` pass.

## Terminal proxy inheritance

`plugin/gin-proxy.lua` now exports the existing Lua editor/askpass launchers and
RPC address into Neovim's environment at plugin startup. This closes the terminal
inheritance gap recorded above and follows pinned `proxy/server.ts`, which also
sets these environment variables globally. The separate startup file keeps
proxy availability independent of the main Gin command's loaded marker. Its
own `loaded_gin_proxy` guard prevents repeat initialization.

`test_proxy_startup.lua` uses independent child Neovim instances and real
terminal jobs without invoking Gin commands. A terminal `git commit` opens the
proxy, accepts keyboard input through `:Apply`, and records the expected commit
and tree. A terminal `git credential fill` obtains both fields through the RPC
askpass with terminal prompting disabled. Four startup configurations verify
independent editor/askpass opt-outs, retaining inherited values for disabled
proxies, and idempotent sourcing. The flags must be configured before plugin
loading to prevent process-wide overrides, as documented in the help and README.

The general mini.test harness disables this startup file so existing suites can
control inherited/per-process environments independently; the startup behavior
itself is tested in the isolated children without that marker. The existing
launcher cleanup and RPC listener implementation are reused. This change does
not add dynamic process-wide reconfiguration when flags change after startup,
or claim the remaining proxy/API audit is complete.

Validation: all 1,312 mini.test cases in 49 groups pass. All six isolated proxy
startup cases also pass on Neovim 0.10.0. `make check` and `git diff --check` pass.

## Exported proxy address after listener recovery

The existing per-command environment builder restarts its RPC listener if it
was stopped. After process-wide startup export was added, this left the global
`GIN_EDITOR_ADDRESS` pointing at the old socket: Gin recovered, but a subsequent
terminal `git credential fill` failed with exit 128. The new regression test
stops the exported listener, runs a synchronous Gin status command to trigger
recovery, then runs a terminal credential query without injecting an environment.
Both credential prompts and the resulting fields now succeed.

Listener recreation updates the exported address only if it still equals the
previous Gin address. A separate test confirms that a subsequently configured
process address is left intact while Gin obtains a live per-command listener.
This supports newly launched terminal jobs after recovery; it does not mutate
the environment of already-running shells or add automatic restart without a
new Gin environment request.

Validation: all 1,314 mini.test cases across 49 groups pass. The 26 proxy
startup/askpass cases pass on Neovim 0.10.0. `make check` and `git diff --check`
pass.

## Editor and askpass functional audit

The proxy item now covers the pinned user workflows in `proxy/server.ts`,
`proxy/{editor,askpass}.ts`, `autoload/gin/internal/proxy.vim` and the commit/
rebase ftplugins. Lua uses Neovim RPC and headless Neovim launchers instead of
the pinned Deno TCP transport; the internal wire protocol is not a compatibility
API. The functional coverage is as follows.

| Pinned behavior | Lua evidence |
| --- | --- |
| Export Git editor and askpass environment on startup | `test_proxy_startup.lua`: terminal commit and credential fill without Gin commands, independent opt-outs, preserved inherited values and repeated-source guard. |
| Open editor with configured opener, silently | `test_editor.lua` validates opener failures and suppressed file-read messages; `test_editor_interaction.lua` exercises edit/split/vsplit/tabedit/preview with actual keyboard input, asynchronously and with `++wait`. |
| Apply writes the message and allows Git to proceed | Commit content/tree checks in editor and terminal tests; synchronous GinBuffer commit in the interaction suite. |
| Cancel rejects Git and clears the editor file | Editor tests preserve index/working data; terminal cancellation verifies no commit, empty COMMIT_EDITMSG, staged content retained and no remaining editor-buffer request. |
| Quit confirmation and apply-without-confirm | `test_editor.lua` covers positive/default/rejected answers and the setting; keyboard tests cover write/quit acceptance and quit rejection. |
| Interactive rebase uses repeated editor requests | Consecutive reword tests verify rewritten subjects, commit ancestry, trees and cleared rebase state; cancellation of an edited todo preserves history/index/worktree. |
| Masked credential prompts and prompt failure | `test_askpass.lua` uses real credential fill and controlled responses/errors; keyboard interaction tests exercise native inputsecret, including its interrupted empty response. |
| Proxies during synchronous commands and output processors | Editor, askpass and interaction suites cover `++wait`, progress-enabled execution, GinBuffer and processors. |
| Commit/rebase Accept/Cancel aliases | `test_editor_aliases.lua` covers both filetypes, existing global/local commands, disabling values, repeat sourcing and undo cleanup. |
| Recovery and failed apply | Listener recovery tests cover per-command and exported terminal addresses. A failed write preserves the request for retry; opener failures release Git without overwriting unsaved work. |

The terminal cancellation case passed without production changes. The combined
Neovim 0.10 interaction run also exposed a test timing issue: mini.test samples
`v:errmsg` after `nvim_input`, so an expected synchronous Git cancellation may be
reported directly by `type_keys` if it completes before the sample. That test
now permits only the expected `Git prompt cancelled` error in `++wait` mode;
it still requires a completed nonzero Git exit and unchanged repository state.
All other input errors remain failures.

This closes the proxy functional checklist, not the overall migration audit.
The process-wide opt-out settings are startup settings; already-running shell
environments are not rewritten after listener recovery. Custom external proxy
protocols and the broader command/options/API compatibility audit remain outside
this functional claim.


The first full audit run exposed a separate five-second test deadline in the
hook-credential cherry-pick case. Its late failure then surfaced in the next
revert case. Both cases passed in isolation. These hook fixtures launch multiple
Git/headless-Neovim processes; their completion wait now allows 30 seconds while
retaining all exit, prompt, ancestry/tree and clean-worktree assertions. This
changes the test deadline only, not production execution policy. The failed full
run is retained in `/tmp/gin-proxy-audit-full.log`.

Validation: the complete rerun passes all 1,315 mini.test cases in 49 groups
(`/tmp/gin-proxy-audit-full-recheck.log`). The 34 isolated startup/editor/askpass
interaction cases pass on Neovim 0.10.0 after the expected-cancellation test fix.
`make check` and `git diff --check` pass.

## Automatic fileformat preferences

A headless probe against the pinned upstream with `fileencodings=utf-8,latin1`
and `fileformats=mac` decoded a Latin-1/CR-only index blob into two Mac-format
lines. Lua instead treated the output as UTF-8/UNIX. This change addresses the
fileformat half of that confirmed gap; automatic encoding selection is still
outstanding.

The shared decoder now limits detected formats to `fileformats`, uses its first
entry when no delimiter matches, and falls back to the target buffer's
`fileformat` when the list is empty. Buffer and edit read/insert routes pass the
target buffer explicitly, so a background output buffer does not inherit the
current window's fallback. Explicit `++ff`/`++fileformat` still take precedence,
and existing mixed-LF/CRLF native-read behavior is retained.

The reference behavior is in Denops std 7.6.0 `buffer/fileformat.ts`, imported by
the pinned view readers. New real-index fixtures cover allowed-format filtering,
Mac CR-only text, detected UNIX despite a leading Mac preference, delimiter-free
fallback and an empty preference list for both GinBuffer and GinEdit. A separate
background-buffer fixture checks target-local fallback. Index bytes remain
unchanged. The 79 fileformat/buffer/edit cases pass on Neovim 0.10.0; the full
integrated run is recorded separately below when complete.

Validation: the integrated run passes all 1,326 mini.test cases across 50 groups
(`/tmp/gin-auto-fileformat-full.log`). The 79 targeted cases pass on Neovim
0.10.0. `make check` and `git diff --check` pass. Re-running the original probe
now selects Mac format and splits the CR-only lines correctly; its Latin-1
encoding mismatch remains the next separate fix.

## Stateless encoding preparation

Added a strict TextDecoder-style decoding library for Unicode and single-byte
encoding candidates, with immutable generated alias/mapping tables. It preserves
candidate order and original option labels, reports a stripped Unicode BOM, and
falls back to replacement-decoded UTF-8 when no candidate succeeds. UTF-8 decoding
reuses the stream decoder's complete-input path without ANSI removal or trimming;
UTF-16BE has an explicit fixed-endian route.

This library is not yet wired into GinBuffer/GinEdit. Seven multibyte decoder
families still need implementation before automatic `fileencodings` selection
can be considered addressed. Explicit encoding behavior and malformed-input
compatibility also remain under audit. See `tests/audit/README.md` for provenance
and the bounded scope of the checked-in Deno reference corpus.

The 70 encoding tests pass on Neovim 0.10.0. The 134 encoding/edit/indicator cases,
reference regeneration check, `make check` and `git diff --check` pass. The full
integrated suite passes all 1,396 cases across 51 groups
(`/tmp/gin-encoding-full.log`).

## Strict Shift_JIS candidates

The encoding library now decodes Shift_JIS (including its registered aliases),
using a lazily loaded table of 9,604 valid byte pairs generated from Deno's fatal
TextDecoder. ASCII/NUL, U+0080 and halfwidth kana use direct rules. Invalid
standalone bytes, unknown pairs and incomplete leads fail the candidate so the
next `fileencodings` entry can be tried. Japanese text and halfwidth kana first
failed with the expected missing-decoder error before implementation.

The normal mini.nvim suite compares every single byte and all 65,536 two-byte
inputs with checked-in Deno results, plus aliases, representative strings and
200 deterministic longer inputs. The 331 encoding tests pass on Neovim 0.10.0.
A separate temporary differential probe also compared 76,792 single/pair/long
inputs against the integrated decoder successfully. These corpora establish
bounded decoder evidence, not completion of automatic buffer encoding selection.
Six multibyte families remain, and the new library is still not wired into views.
Full-suite validation passes all 1,657 mini.test cases across 52 groups
(`/tmp/gin-shift-jis-full.log`). The oracle regeneration check, `make check`
and `git diff --check` also pass.

## Strict Big5 and EUC-KR candidates

Big5 and EUC-KR now use a shared strict two-byte decoder with separate lazy
mapping tables. ASCII and NUL remain single-byte text; invalid pairs and
incomplete leads fail the candidate. Big5's four mappings that produce two
Unicode code points retain both characters. The explicit Big5 expansion test
first failed with the missing-decoder error before implementation.

The generator records actual fatal Deno TextDecoder results for every single
byte, all 65,536 byte pairs per encoding and 200 deterministic longer inputs per
encoding. Production mappings are split into lead-byte rows, preserving exact
UTF-8 strings and avoiding a single large flat constant table. Candidate tests
cover Korean text, all four expanding Big5 pairs and incomplete-input fallback.

All 594 encoding and Big5/EUC-KR cases pass on current Neovim and Neovim 0.10.0.
The generation check, `make check` and `git diff --check` pass. The full suite
passes 2,178 cases across 53 groups (`/tmp/gin-double-byte-full.log`).
GBK, gb18030, EUC-JP and ISO-2022-JP remain unimplemented
in the production library, and automatic view encoding selection is still unwired.

## Strict EUC-JP candidates

The EUC-JP decoder now handles ASCII/NUL, halfwidth kana, JIS0208 pairs and
0x8F-prefixed JIS0212 triples. It checks byte ranges before computing mapping
pointers and rejects unknown/incomplete sequences so later encoding candidates
can be tried. The mixed Japanese/kana/supplementary regression failed with the
expected missing-decoder error before implementation.

Generated JIS0208 and JIS0212 tables contain 7,336 and 6,067 code points. JIS0208
mappings are also checked against Deno ISO-2022-JP output, preparing a common
table for the remaining stateful decoder. Every byte pair and all 0x8F-prefixed
triples are compared with the Deno oracle; single bytes, aliases, mixed longer
inputs and candidate selection are covered separately.

All 595 encoding/EUC-JP cases pass on current Neovim and Neovim 0.10.0. The oracle
check, `make check` and `git diff --check` pass. The full suite passes all 2,695
cases across 54 groups (`/tmp/gin-euc-jp-full.log`).
GBK, gb18030 and ISO-2022-JP remain unimplemented in production, and automatic
view encoding selection remains unwired.

## Strict ISO-2022-JP candidates

The ISO-2022-JP decoder now handles ASCII, Roman, halfwidth katakana and JIS0208
modes using per-call state and the shared JIS0208 table. Invalid escapes, adjacent
escape designations without intervening output, incomplete pairs and invalid
mode-specific bytes fail the candidate. A mixed Roman/kana/JIS/ASCII test first
failed with the expected missing-decoder error before implementation.

The normal mini.nvim suite checks all pairs following ESC and all pairs in JIS
mode against Deno. The common fixture includes every byte in each designated
mode, escape transitions and deterministic longer inputs. Separate cases ensure
state does not survive a decode call (including failures), and preserve candidate
order: UTF-8 first accepts the escape bytes literally, while ISO-2022-JP first
interprets them. A temporary shared-table probe passed 153,716 Deno comparisons.

All 600 encoding/ISO-2022-JP cases pass on current Neovim and Neovim 0.10.0.
Oracle generation, `make check` and `git diff --check` pass. The full suite
passes all 3,214 cases across 55 groups (`/tmp/gin-iso-2022-jp-full.log`).
GBK/gb18030 and view-level automatic encoding selection remain;
explicit nonfatal decoding still needs a separate compatibility audit.

## Strict GBK and GB18030 candidates

GBK and GB18030 now use a common strict decoder with lazy tables: 23,940 mapped
byte pairs and 209 contiguous four-byte ranges. ASCII/NUL and the single-byte
Euro sign are handled directly. A binary search resolves four-byte pointers;
invalid lead/trail bytes, truncated sequences and unmapped pointers reject the
candidate. The initial GBK four-byte regression failed with the missing-decoder
error before implementation.

The separate Deno generator verifies equality of GBK/GB18030 over every single
byte, byte pair and all 1,587,600 structurally valid four-byte inputs. Regular
mini.nvim tests cover all byte pairs for both labels plus 4,793 boundary,
mutation, truncation and mixed-input cases per label. All 603 targeted cases pass
on current Neovim and Neovim 0.10.0. An optional mini.nvim exhaustive four-byte
audit also passes against the Deno-generated SHA256 digest, independent of the
compressed production tables. See `tests/audit/README.md` for reproduction.

All 39 Deno-supported families now have strict candidate decoders. This completes
the decoder prerequisite only: automatic view encoding selection is not wired,
and explicit nonfatal decoding remains under audit. The full suite passes all
3,733 cases across 56 groups (`/tmp/gin-gb18030-full.log`). `make check`,
`git diff --check` and the GB18030 oracle regeneration check pass.

## Automatic fileencoding selection

The shared read decoder now tries `fileencodings` in order when no nonempty
explicit encoding is supplied. It uses the strict Lua candidates, skips failed
or unknown candidates, and falls back to replacement-decoded UTF-8 with an empty
fileencoding when none succeeds. Explicit encoding options retain precedence;
their existing conversion path is unchanged and still needs a separate audit of
nonfatal TextDecoder behavior.

Actual headless GinBuffer and GinEdit probes against the locked upstream covered
13 inputs per view: Latin-1, Shift_JIS, EUC-JP, Big5, EUC-KR, GBK four-byte input,
ISO-2022-JP/UTF-8 candidate ordering, unknown candidates, invalid UTF-8 fallback,
an empty candidate list, UTF-16LE and UTF-8 BOMs. Lua now matches the displayed
bytes and final fileencoding in all cases. Neovim normalizes selected `gbk` to
`cp936`. The regression suite also includes gb18030, addressed reads through both
URI schemes without changing destination encoding, explicit-option precedence,
and byte-exact Latin-1/UTF-16LE index write-back.

BOM option parity is intentionally not claimed by these probes: upstream
GinBuffer does not set bomb, and its GinEdit helper recognizes only the UTF-8
byte prefix. Lua retains its existing decoded-BOM metadata/write-back behavior,
including UTF-16, to preserve encoded index content on write. The observed
remaining differences are GinBuffer's UTF-8/UTF-16 bomb metadata and GinEdit's
UTF-16 bomb metadata, not displayed text or selected encoding. This remains an
explicit compatibility difference for the broader encoding audit.

The first Latin-1 automatic-view test failed before wiring the library. The
34 new mini.nvim tests pass on Neovim 0.10.0; the preceding 110-case run included
31 of them plus existing fileformat/edit/buffer coverage, also passing. Formatting
and diff checks pass. The full integrated suite passes all 3,767 cases across
57 groups (`/tmp/gin-auto-encoding-full.log`).

## Explicit UTF-8 replacement decoding

Explicit `++enc=utf-8`/`utf8` previously left invalid byte sequences in buffer
text. The read path now uses the complete UTF-8 replacement decoder already
used by automatic fallback, before the existing BOM/line-format processing.
The initial GinEdit regression failed by comparing raw 0xFF with U+FFFD; the
terminal rendered both similarly, so the byte-level string assertion matters.

Thirteen Deno-checked inputs cover invalid leads, incomplete prefixes, invalid
continuations, surrogate encodings, overlong sequences, values above U+10FFFF,
valid astral/boundary characters, literal U+FFFD, NUL and BOMs. Both commands and
both UTF-8 spellings are tested while automatic candidates prefer Latin-1, plus
addressed reads through both URI schemes. Source index bytes and destination
encoding remain unchanged. All 54 new cases and the existing edit/buffer suites
pass on Neovim 0.10.0 (122 cases total). Formatting and diff checks pass.

The live pinned-upstream GinEdit probe now agrees on decoded bytes and encoding
for invalid/truncated explicit UTF-8. It still reports endofline=true for these
unterminated inputs, while Lua preserves endofline=false; this existing metadata
difference is separate from decoding parity. UTF-16, legacy single-byte aliases
and multibyte nonfatal decoding still need fixes. Full-suite validation for this
UTF-8 change passes all 3,821 cases across 58 groups
(`/tmp/gin-explicit-utf8-full.log`).

## Explicit single-byte decoding

Explicit single-byte encodings now use the same label registry and mappings as
automatic selection, with undefined bytes replaced by U+FFFD. The initial
Latin-1 regression failed because iconv treated 0x80 as U+0080 instead of the
Windows-1252 Euro mapping used by TextDecoder. UTF-8 explicit decoding also now
uses the common replacement entrypoint, preserving its existing BOM behavior.

Replacement mode is opt-in; default strict candidate decoding still rejects
undefined bytes. The view calls it only for implemented replacement codecs
(UTF-8 plus 29 single-byte families). The oracle generator records every byte
and a full 256-byte concatenation per family, giving 7,453 nonfatal reference
comparisons. Real-view and addressed-read cases cover Latin-1/ASCII/Windows-1252
aliases and undefined ISO-8859-3/Windows-1253 bytes while preserving source data
and destination encoding. The live pinned-upstream Latin-1 probe now agrees on
displayed bytes and selected encoding.

All 249 encoding/explicit-read/edit/buffer tests pass on Neovim 0.10.0. Oracle
regeneration, formatting and diff checks pass. The full suite passes all 3,863
cases across 58 groups (`/tmp/gin-explicit-single-full.log`).
UTF-16 and legacy multibyte replacement decoding, metadata differences and the
broader write-encoding audit remain separate work.

## Explicit UTF-16 replacement and label semantics

UTF-16 candidates and explicit reads now share a fixed-endian decoder with strict
or replacement modes. In replacement mode, malformed/unpaired surrogates and
incomplete code units produce U+FFFD; a pending high surrogate plus a partial
trailing unit at EOF produces one replacement, matching TextDecoder. Label
normalization now also applies to explicit UTF-16, so `utf-16` and `ucs-2` read
as LE. The incomplete UTF-16 GinEdit regression failed before implementation.

The generator records every two-byte input for both endiannesses, selected
code-unit boundary combinations, all one-byte suffixes, lone bytes and longer
inputs. A temporary independent corpus of 78,729 cases per endianness also passed
against the integrated decoder. The actual pinned-upstream probes now agree on
displayed text and selected encoding for incomplete UTF-16, an invalid surrogate
followed by ASCII, and the generic utf-16 label. Previously documented BOM and
endofline metadata differences remain separate.

Three existing expectations needed correction for this behavior. Native
big-endian utf-16/ucs-2 write comparisons retain their byte-exact assertions but
read the result back with explicit utf-16be; the same generic labels no longer
mean BE when reading. Failed-decoder snapshot restoration now uses the existing
strict ucs-2le extension, since malformed UTF-16 is successfully replacement-
decoded. The shared native Unicode writer and its validation remain unchanged.

All 780 encoding/explicit-read/edit/buffer tests pass on current Neovim and
Neovim 0.10.0. Oracle regeneration, formatting and diff checks pass. The full
suite passes 4,394 cases across 59 groups (`/tmp/gin-explicit-utf16-full.log`).
Legacy multibyte replacement decoding and the remaining
API/metadata/write compatibility audits are not complete.

## Explicit Shift_JIS, Big5 and EUC-KR replacement

Shift_JIS and the shared Big5/EUC-KR decoder now support strict and replacement
modes. Invalid pairs emit U+FFFD; an ASCII trail is reprocessed rather than
swallowed, whereas a non-ASCII trail is consumed with its valid lead. Invalid
standalone leads and incomplete final leads emit one replacement. Strict mode
still fails on the same malformed inputs and remains the automatic-selection
default. The initial Shift_JIS view regression failed because iconv returned
`??` before the quote instead of one replacement character.

The Deno generator now records strict and replacement output for every byte
pair in all three families, with single-byte and longer replacement cases in
the common fixture. The integrated decoders also passed a separate 75,792-case
corpus each. Real-view and addressed-read tests cover ASCII recovery, non-ASCII
invalid trails, standalone failures, truncation and 0x80. Source bytes and read
destination encoding are preserved. Pinned-upstream probes now agree on text
and encoding for the confirmed Shift_JIS and Big5 failures.

All 1,080 targeted encoding/explicit-read/edit/buffer tests pass on Neovim 0.10.0.
Generation, formatting and diff checks pass. The full suite passes 4,434 cases
across 59 groups (`/tmp/gin-nonfatal-pairs-full.log`).
EUC-JP, ISO-2022-JP and GBK/gb18030 replacement decoding remain, together with the
broader metadata, write-encoding and API compatibility audits.

## Explicit EUC-JP replacement

The EUC-JP decoder now supports replacement decoding for explicitly selected
encodings while retaining strict automatic selection. Invalid pending sequences
consume their non-ASCII trail but retry an ASCII trail, and truncated JIS0212
prefixes produce one replacement. State resets after errors so subsequent JIS0208
characters decode normally. The initial real-view regression produced `???? `
instead of the upstream replacement character followed by a space.

The Deno fixtures now cover strict and replacement results for every byte pair
and every 0x8F-prefixed triple, plus single bytes and mixed longer inputs. An
independent 141,328-case corpus passes against the integrated implementation.
Both views and addressed reads exercise malformed sequences and ASCII recovery;
source bytes and destination encoding remain intact. The pinned-upstream GinEdit
probe for `8F A2 20` now agrees on text bytes and fileencoding; the previously
documented endofline metadata difference remains. All 840 related tests pass
on Neovim 0.10.0. Oracle regeneration and formatting checks pass. The full suite
passes 4,454 cases across 59 groups (`/tmp/gin-eucjp-replacement-full.log`).
ISO-2022-JP and GBK/gb18030 replacement and broader
metadata, write-encoding and API compatibility audits remain incomplete.

## Explicit ISO-2022-JP replacement

ISO-2022-JP now supports replacement decoding for explicit reads. Invalid
escapes replace ESC and reprocess the remaining bytes in the previous output
state. A valid escape interrupting a JIS pair replaces the unfinished character
and changes state. Consecutive valid escapes still report an error, but in
replacement mode the new state takes effect. Strict candidate selection remains
the default. The initial GinEdit regression retained ESC instead of emitting
U+FFFD for `1B 24 20`.

Strict and replacement fixtures cover every JIS byte pair and escape suffix,
all mode bytes, adjacent escapes and longer mixed inputs. The integrated decoder
also matches Deno on a separate 404,641-case corpus. Real-view and addressed-read
tests cover truncation, each output state, invalid escapes and state changes
following errors. The pinned-upstream GinEdit probe now matches text bytes and
fileencoding; the existing endofline metadata difference remains.

All 862 related tests pass on Neovim 0.10.0. Oracle regeneration, formatting and
diff checks pass. The full suite passes 4,474 cases across 59 groups
(`/tmp/gin-iso-replacement-full.log`). GBK/gb18030 replacement and
the broader metadata, write-encoding and API compatibility audits remain open.

## Explicit GBK/gb18030 replacement

GBK and gb18030 now use the shared decoder's replacement mode for explicit
reads. Invalid third or fourth bytes retry the suffix after the first lead;
truncated prefixes at EOF emit one replacement for the whole pending sequence.
Structurally complete but unmapped quadruples consume all four bytes. Invalid
pair trails retry ASCII, and standalone invalid bytes consume only themselves.
Strict automatic candidate selection retains its previous behavior. The first
GinEdit regression produced `??0?? ` instead of `�0� ` for `81 30 81 20`.

Deno fixtures now include replacement results for every byte pair, single bytes,
quadruple boundaries, mutations, truncations and mixed inputs under both labels.
The integrated decoder also passes a separate 508,945-case corpus including all
lead/digit/third-byte prefixes and structured malformed longer inputs. Both
views and addressed reads exercise the recovery and preserve source bytes and
destination encoding. The pinned-upstream GinEdit probe now agrees on text and
fileencoding; the existing endofline metadata difference remains.

All 907 related tests pass on Neovim 0.10.0. Oracle regeneration, formatting and
diff checks pass. The full suite passes 4,517 cases across 59 groups
(`/tmp/gin-gb-replacement-full.log`). This completes replacement
codec implementation for the supported TextDecoder families, but unsupported
explicit labels and broader metadata, write-encoding and API audits remain open.

### Remaining explicit-label rejection difference

A pinned-upstream GinEdit probe confirms that `ucs-2le`, `ucs-2be`, `ucs-4`,
`utf-32`, `utf-32le`, `cp932`, `cp936` and an unknown name report invalid encoding
labels; `utf-16be` is accepted. The current Lua reader instead accepts native
`ucs-2le` through its Unicode fallback. This extension remains to be removed or
otherwise reconciled with the pinned read contract; native writer semantics
need their own audit and must not be inferred from the read labels.

The upstream `edit:edit` dispatcher uses denops std 7.6.0 `friendlyCall`, which
catches the decoder error and schedules a non-history `echo`. Therefore pcall
success and an empty `:messages` history do not prove successful decoding.
The probe captures `:redir` across timer processing and checks actual buffer
content, rather than treating that command return as success evidence.
Temporary evidence: `/tmp/gin-explicit-label-probe-upstream.json`.

## Reject unsupported explicit read encodings

Explicit reads now always use the TextDecoder-compatible replacement decoder.
The prior fallback to native Unicode and iconv accepted `ucs-2le`, despite the
pinned upstream reporting an invalid label. The initial real-view rejection
regression failed because this input succeeded. Both views and addressed reads
now reject native-only and unknown labels while preserving source bytes and
read destinations. Automatic selection continues to skip invalid candidates.

Native writer byte comparisons remain intact. UCS-2LE writer output is read
back using UTF-16LE, and UCS-4 writer cases retain their byte-exact comparison
without attempting a TextDecoder-unsupported read. Failed-read snapshot tests
now provoke an unsupported-label error after a successful UTF-16LE load and
verify a later supported reload restores normal operation. The related 298
tests pass on current Neovim and Neovim 0.10.0; formatting checks pass.
The full suite passes 4,550 cases across 59 groups
(`/tmp/gin-label-rejection-full.log`). General notification/error-handling parity and the
metadata, write-encoding and API audits are still separate unfinished work.

### Pinned-upstream write-metadata evidence

A fresh isolated Git-index probe compares actual staged bytes and confirms these
remaining differences (all cases restore the original working file):

| Input/options | Pinned upstream bytes | Current Lua bytes |
| --- | --- | --- |
| `A`, noendofline/nofixendofline | `41 0A` | `41` |
| empty buffer, noendofline/nofixendofline | `0A` | empty |
| UTF-16LE with bomb | `EF BB BF 41 00 0A 00` | `FF FE 41 00 0A 00` |
| UTF-16BE with bomb | `EF BB BF 00 41 00 0A` | `FE FF 00 41 00 0A` |
| Latin-1 with bomb | `EF BB BF 41 0A` | `41 0A` |
| binary, dos, bomb, noendofline | `EF BB BF 41 0D 0A` | `41` |

UTF-8 BOM and ordinary DOS output agree. Upstream `edit/write.ts` always joins
content with a final fileformat line ending and `util/bom.ts` always adds the
UTF-8 prefix. This is a real output-policy difference, not a decoder failure.
The user has been asked whether to retain correct encoding-specific BOMs and
missing-final-newline preservation with documented deviations, or reproduce
these pinned behaviors. No decision has yet been applied.
Evidence: `/tmp/gin-write-metadata-{upstream,lua}.json`.

## Gin final-output decoding

The bare command's final display now uses the shared replacement decoder on
concatenated stdout and stderr, matching pinned `command/bare/command.ts`.
Default decoding is UTF-8 regardless of fileencodings; explicit labels use the
same TextDecoder aliases and rejection rules as buffer reads. The initial
Shift_JIS regression displayed `??"` instead of `�"`. Raw process results remain
unchanged. Decoder failures are reported in synchronous and asynchronous runs
without scheduling a successful GinCommandPost event.

Tests cover malformed Unicode and multibyte output, aliases, stdout/stderr
sequence boundaries, unsupported and empty explicit labels, and error delivery.
The existing UTF-16 BOM test used iconv to generate its bytes, which could silently
leave the input unconverted on this host. It now constructs actual UTF-16LE/BE
code units and still checks that only the leading BOM is removed.

All 179 command/encoding tests pass on Neovim 0.10.0; formatting and diff checks
pass. The corrected live probe uses `Gin ++wait` for both implementations and
confirms matching final text on its eleven cases. Earlier async observations
mixed successive commands and are not valid per-case evidence. UTF-16 progress
output still differs in how NUL-containing text is displayed (upstream binary
representation versus Lua control-character rendering); this remains a separate
indicator audit item. The full suite passes 4,565 cases across 59 groups
(`/tmp/gin-command-decoding-full.log`).
Evidence: `/tmp/gin-command-encoding-matrix-{upstream,lua}.json`.

### Indicator NUL representation diagnosis

Instrumenting the pinned `gin#indicator#echo#write` callback in an isolated
runtime confirms that a decoded `A` followed by NUL arrives as Vim Blob type 10
and displays as `0z4100`; ordinary decoded strings arrive as type 1. The UTF-16
surrogate probe arrives as `0z00EFBFBD.4100` after UTF-8 progress decoding.
The pinned echo backend uses Vim's `join`, which stringifies these Blob values.
Lua's echo backend instead calls `table.concat` and nvim_echo directly, retaining
NUL as a control character. Lua-to-Vim function calls already convert NUL strings
to Blobs, so using Vim join in the built-in echo path reproduces the pinned
representation without changing stream bytes or custom callback payloads.
This fix remains to be applied after the current command-decoding validation.
Evidence: `/tmp/gin-indicator-encoding-matrix-upstream.json` and a headless
`vim.fn.join` probe yielding the same Blob representations.

## Echo indicator NUL display

The built-in echo indicator now joins lines with Vim's join, matching the pinned
backend's Blob formatting for NUL-containing strings. The initial mini.test
regression compared `A\0` and a longer NUL/replacement-character line against
`0z4100` and `0z00EFBFBD.4100`, and failed before the change. Ordinary lines remain
plain text. Raw process bytes, UTF-8 progress decoding and custom indicator
callbacks are unchanged.

The complete eleven-case command display probe now agrees with the pinned
upstream including the formerly different UTF-16 progress text. All 81 command
and indicator tests pass on Neovim 0.10.0; formatting and diff checks pass.
The full suite passes 4,566 cases across 59 groups
(`/tmp/gin-indicator-nul-full.log`).

### Remaining NUL final-display difference

An added live `Gin ++wait` probe with UTF-8 bytes `41 00 42` confirms that the
pinned final echo also receives a Blob and renders `0z410042`; Lua still renders
`A^@B`. For `41 00 0A 42 0A`, upstream renders the entire final message as
`0z41000A42.0A`, including its trailing line ending. The progress indicator
formats each split line separately, and that portion now agrees. Final-output
handling must therefore stringify the complete NUL-containing message before
any ordinary trailing-newline display trimming. This remains a separate fix
following indicator validation. Evidence: `/tmp/gin-command-nul-matrix-*.json`.

The expanded final-NUL probe confirms normalization order for single NUL,
ANSI-colored NUL content, leading UTF-8 BOM, Japanese text, and explicit DOS,
Mac and Unix separators. For example `A\0\r\nB\r\n` becomes
`0z41000A42.0A` under DOS but `0z41000D0A.420D0A` under Unix. ANSI decoration and
a leading UTF-8 BOM disappear before Blob conversion; trailing normalized LF
remains in the Blob. Reference results are in
`/tmp/gin-command-nul-expanded-upstream.json`.

## Final command NUL display

Final command output now converts NUL-containing messages to Vim Blob notation
after decoding, fileformat normalization and ANSI removal, before ordinary
trailing-newline display trimming. The initial regression exposed literal NUL
and a missing final LF instead of `0z41000A42.0A`. Raw process result objects and
bytes remain unchanged. Mini.test cases cover a single NUL, ANSI, UTF-8 BOM,
Japanese characters and DOS/Mac/Unix normalization against captured upstream
results. Assertions avoid mini.test's Blob-as-String diagnostic limitation.

All 89 command/indicator tests pass on Neovim 0.10.0. Twenty complete live command
displays, including progress and final output, match the pinned upstream.
Formatting and diff checks pass. The full suite passes 4,574 cases across
59 groups (`/tmp/gin-command-nul-full.log`).

## Bare Gin functional audit ledger

Pinned entrypoints are `plugin/gin.vim`, `command/bare/{main,command}.ts`,
`util/cmd.ts`, `git/executor.ts` and `util/indicator_stream.ts`.

| Behavior | Current evidence |
| --- | --- |
| Arbitrary Git commands, async/default and ++wait | `test_command.lua` stages real files and checks index paths and completion events in both routes. |
| Argument expansion and ++ option parsing | Current/alternate filename helpers, separators produced by expansion, literal plus-prefixed paths, duplicate options, bare wait removal and ECMAScript line terminators have fixtures. |
| Decode combined stdout/stderr, normalize newlines, remove ANSI | Command tests and live malformed-encoding/NUL matrices exercise the final-output route and raw-result retention. |
| Progress lifecycle | Indicator suites cover stream boundaries, concurrent settings restoration, backend failures, public wrappers and NUL Blob notation. |
| Completion notifications | Command tests cover coalescing, eventignore at dispatch and no success event after Git, processor, backend or decoding errors. |
| Editor/askpass handling during waits | Proxy/editor interaction tests exercise keyboard-driven commit/rebase and credentials. |
| Postprocessors | Lua accepts ++processor on bare Gin as an extension; pinned bare main.ts does not accept it, although GinBuffer/GinDiff do. Shared processor execution is separately covered. |

A six-case live modifier probe shows a remaining user-facing mismatch. Pinned
`silent Gin ++wait` still displays progress and suppresses the final success
message; `silent!` also suppresses the friendly final error but still has
progress. Lua suppresses all progress for both silent forms. Pinned normal and
silent failures return through friendlyCall, whereas Lua ++wait raises an
exception. Both implementations emit one completion event on success and none
on failure. Redirection also captures Lua's suppressed exception text under
silent!, so redirection output is not by itself proof of visible UI output.
The modifier/error contract remains open; the bare-command checklist is not yet
closed. Evidence: `/tmp/gin-command-modifiers-{upstream,lua}.json`.

## Bare Gin friendly errors and silent modifiers

The :Gin entrypoint now routes through a user-command wrapper. Git and processor
failures are displayed as friendly `[gin]:` messages using UTF-8-decoded,
ANSI-stripped stderr; parser and other errors are caught without a Lua stack
trace. Normal and silent user commands return after reporting errors. silent!
suppresses the final error. All modes retain live progress, while silent and
silent! suppress the final success message, matching the pinned command path.

The internal execute API retains its previous exception/notification behavior
and silent indicator suppression. A progress option enables the user-command
path explicitly, and an on_error callback receives execution failures in either
mode. This preserves existing callers that depend on failure propagation or
silent internal execution. An initial attempt to infer progress from configured
indicator names broke the existing silent-backend test; the explicit progress
option resolves that regression without changing its assertion.

The initial friendly-error regression failed because :Gin ++wait threw. Three
existing user-command error tests now check notification content, unchanged Git
state and absent success events; direct API error tests remain intact. Twelve
real-process cases cover normal/silent/silent!, synchronous/asynchronous and
success/failure combinations. The live modifier comparison now agrees on
return behavior, progress/final-error suppression and completion events.
All 103 command/indicator/declaration tests pass on Neovim 0.10.0; formatting and
diff checks pass. The full suite passes 4,587 cases across 59 groups
(`/tmp/gin-friendly-command-full.log`).

### Help-tag compatibility gap

The pinned help file declares 115 tags. The current local file is missing 88,
including per-command argument settings, mapping-disable settings, component
functions, Plug mappings and section aliases. Their implementation or explanatory
text often exists, but the old :help lookup does not reach it. A temporary copy
adds these aliases at 31 existing explanations; helptags generation succeeds,
and all 115 upstream lookups land on their exact tag in the local help file.
The lookup check resolves real paths because macOS canonicalizes /tmp to
/private/tmp. This documentation fix remains to be applied after the current
runtime change is committed. Temporary preparation and verification:
`/tmp/gin-help-tags.py`, `/tmp/gin-help-tag-check.lua`.


### Restored upstream help lookups

Applied the 88 missing compatibility tags to doc/gin.txt, next to the existing
explanations for settings, functions, mappings and sections. All 115 tags from
the pinned upstream now resolve to their exact tag line in the local help file.
The check uses a byte-identical temporary copy with generated helptags, leaving
no generated tags file in the repository. Current Neovim and Neovim 0.10.0 pass.
The initial 0.10 run encountered an unrelated system vimdoc parser ABI mismatch;
repeating with filetype plugins disabled isolates and verifies help navigation.
Diff checks pass. This documentation-only change follows the 4,587-case runtime
suite at 537faa6; the runtime suite was not repeated for tag additions.

These aliases restore navigation, not proof of complete prose coverage. In
particular, per-scheme buffer-name aliases currently lead to the shared URI
compatibility explanation; a complete URI grammar/content audit remains open.


### Per-scheme URI help coverage

Expanded the ten buffer-name help entries into separate explanations rather
than pointing every tag at one shared paragraph. The text distinguishes the
Lua formatter's query/encoded-fragment layout from the accepted upstream
semicolon layout, and identifies each upstream fragment's data and terminator.
Log/reflog/stash explicitly distinguish Lua JSON argument arrays from upstream
parameter-based flags/selectors. Blame documents all three associated schemes.

Compared the pinned help section (lines 654-734) with lua/gin/uri.lua and the
view readers, including log/stash argument reconstruction and blame pane names.
Existing legacy URI tests in test_edit, test_diff, test_buffer, test_branch,
test_log, test_stash, test_status and test_tag cover the behaviors described;
these were inspected, not rerun for this prose-only change. Generated helptags
and all 115 upstream lookups pass on current Neovim and 0.10.0 (the latter with
filetype plugins disabled to avoid the system vimdoc parser ABI mismatch).
This improves documentation coverage without closing the full runtime or
configuration compatibility audit.


### Bare Gin final newline preservation

A fresh six-case comparison of normal/silent/silent! and success/failure found
that normal successful output lost one final newline in Lua. The pinned
bare/command.ts joins decoded lines without trimming, and Denops helper echo
passes that text to Vim's echo. Removed the final newline trim in command.finish.
The new regression first failed with "output" instead of "output\n"; command
tests now pass with retained final newlines, including the existing fileformat,
Unicode BOM and joined stdout/stderr cases. The six live modifier cases now
match upstream for captured output, return behavior and completion events.
Formatting and diff checks pass. The full suite passes 4,588 cases across 59
groups (`/tmp/gin-final-newline-full.log`), and all 79 command cases pass on
Neovim 0.10.0 (`/tmp/gin-final-newline-nvim010.log`).

A separate fresh history probe clears :messages before each case. Upstream
leaves history empty in all six cases, whereas Lua records normal successful
output. This matches the source distinction between upstream :echo and Lua's
nvim_echo history=true. History behavior remains to be fixed independently.
Probe: `/tmp/gin-command-history.lua`, with results in
`/tmp/gin-command-history-{upstream,lua}.json`.


### Bare Gin output history

Changed command.finish to echo without adding message history, matching the
pinned Denops helper's :echo. A real :messages regression first showed the
command result appended to a prior message; it now leaves that history intact.
Updated display tests to observe final text instead of using the incorrect
history flag as a proxy for completion. The twelve modifier/wait/error cases
identify final output by its retained newline and assert history=false.

All 80 command tests pass on current Neovim and 0.10.0. The fresh six-case live
probe matches upstream output, history, return behavior and events. Formatting
and diff checks pass. The full suite passes 4,589 cases across 59 groups
(`/tmp/gin-command-history-full.log`).


### Remaining view-command error boundary

A fresh probe passes ++unknown=value to all thirteen view commands under normal,
silent and silent! modifiers. All 39 upstream calls return normally; Lua raises
in the 26 normal/silent cases. Its 13 silent! cases suppress the exception at
Ex level but redirection still captures Lua traceback text. No success event
is emitted in either implementation. The reference dispatchers all use
friendlyCall; twelve also use ensureSilent. Browse omits ensureSilent and its
friendly notification remains visible even under silent!, confirmed live.

This is a user-command entrypoint gap, distinct from direct Lua API exceptions
and BufReadCmd/BufWriteCmd failure propagation. Any fix must retain those
boundaries and update tests that currently expect a user-command exception to
observe notifications and unchanged state instead. Evidence:
`/tmp/gin-all-view-errors.lua`, `/tmp/gin-all-view-errors-{upstream,lua}.json`.


### View-command friendly boundary implementation

All thirteen view-command entrypoints now call a shared friendly boundary that
catches synchronous failures and displays an ErrorMsg without message history.
Twelve respect silent!; Browse deliberately passes no suppression because the
pinned dispatcher omits ensureSilent. The bare Gin wrapper shares the same
reporting function while retaining its asynchronous result handling. Direct Lua
command APIs and read/write autocmd handlers are unchanged.

The first GinEdit invalid-option regression failed with an exception, then
passed after adding the boundary. The new suite covers all 39 command/modifier
combinations with notification, history, event and unchanged-window assertions,
plus thirteen checks that direct command APIs still throw. Existing invalid
configuration and argument tests now observe friendly errors while retaining
their Git/buffer/window/register assertions. All 157 command, configuration and
boundary cases pass. The live 39-case parser-error probe agrees with upstream on
return behavior, notification visibility, history and events; diagnostic wording
still differs. Formatting and diff checks pass. The first full run reached 4,641 cases and
found 23 remaining assertions expecting user-command exceptions, in encoding,
status configuration and native browser failure tests. Updated these to assert
friendly errors, retaining their state checks. All 337 cases in those three
files now pass (`/tmp/gin-view-errors-adjusted.log`); the 157 boundary/command/
configuration cases also pass on Neovim 0.10.0. The full rerun passes all 4,641 cases across 60 groups
(`/tmp/gin-view-errors-full-recheck.log`).

A second probe reaches errors inside BufReadCmd (including missing revisions in
an empty repository). The new boundary catches these, but their exception text
contains Neovim's nested callback context and traceback. Cleaning that text and
comparing Git-failure diagnostics remain open; the parser-error comparison does
not establish complete error-message parity. Evidence:
`/tmp/gin-view-git-errors.lua`, `/tmp/gin-view-git-errors-lua.json`.

The Git-failure probe was also run against upstream. GinEdit and GinBlame show
only Git stderr in the friendly error, including its final newline; Lua retains
its internal exit-code prefix and nested callback traceback. In an empty
repository Browse also discovers a different first error (upstream missing HEAD
versus Lua missing origin), which is separate from notification presentation.
Reference results: `/tmp/gin-view-git-errors-upstream.json`.


### Nested callback diagnostic prototype

Captured view-command Git failures on both current Neovim and 0.10.0. Current
Neovim labels nested exceptions "Lua callback:", while 0.10 uses "Error executing
lua callback:". The first prototype matched zero old-version cases; added an
explicit nonzero coverage assertion and support for both forms. A temporary
unwrapper now extracts the original message from all 18 captured nested errors
on each version. It only unwraps messages beginning with an nvim API context and
preserves traceback-like text within the message by removing the final actual
stack suffix. Direct messages containing such text remain unchanged.

This is preparation, not an applied runtime fix. Prototype files:
`/tmp/gin-error-unwrapping{,-nvim010}.lua`; old-version capture:
`/tmp/gin-view-git-errors-nvim010-lua.json`. Removing the internal Git exit-code
prefix and preserving raw stderr's trailing whitespace still requires separate
handling; the prototype only removes callback context and the traceback.


### Remove nested callback traces from friendly errors

The shared reporter now unwraps Neovim API callback errors before displaying
them. It recognizes both current and 0.10 callback labels and removes the final
stack suffix only within an nvim API context. Literal traceback-like text in a
diagnostic remains intact. A real GinEdit missing-file test first failed with
the complete BufReadCmd context/stack; it now displays the underlying Git error.

Four additional cases exercise current/old context and literal multiline text.
They also exposed the old source-prefix removal matching across newlines and
deleting diagnostic content up to an embedded filename:line marker. Limiting
that operation to the first line fixes the three reproduced failures.

All 137 command/boundary cases pass on current Neovim and 0.10.0; the fresh live
Git-error probe yields 23 friendly messages without callback context or traces.
Formatting and diff checks pass. The full suite passes 4,646 cases across 60
groups (`/tmp/gin-nested-error-full.log`). The internal "git exited" prefix and trimmed
stderr whitespace remain differences from upstream; this change does not
claim byte-identical Git failure diagnostics.


### Git diagnostic preservation follow-up

The remaining stderr whitespace is lost in git.error_message, which applies
vim.trim before git.run raises a string. The friendly boundary cannot recover
those bytes after Neovim wraps the exception. Existing direct execute tests also
assert the trimmed "git exited 7: broken" string, so preserving stderr requires
an intentional diagnostic-contract update rather than only an echo change.
Throwing behavior and status reporting must remain tested. The pinned executor
throws decoded, ANSI-stripped stderr, while its separate captured-query process
helper prefixes the exit status. Those paths must not be conflated when aligning
friendly diagnostics. No runtime changes for this follow-up are applied yet.


### Preserve whitespace in internal Git error strings

Removed vim.trim from git.error_message so leading spaces, trailing spaces and
final newlines survive from stderr into the thrown error. The existing source
and exit-code prefix remains; direct APIs continue throwing strings. Color
escapes are still removed, and unchecked process results retain raw stderr.

A real Git alias first reproduced loss of two leading spaces, one trailing
space and two newlines. Four cases now cover Git/processor failures with and
without progress, checking status, raw output and exact thrown text. Existing
command/color-error assertions now expect the preserved newline; the real
GinEdit callback test also checks it survives the Neovim error wrapper.
All 152 Git/command/boundary tests pass on current Neovim and 0.10.0.

A fresh live probe compares 15 final Git diagnostic payloads to upstream after
excluding the still-known Lua exit-code prefix; all match including trailing
newlines. This is payload agreement, not complete notification parity.
The full suite passes 4,650 cases across 60 groups
(`/tmp/gin-error-whitespace-full.log`).


### Remaining empty-output display behavior

A fresh live bare-command probe runs a successful Git alias with empty stdout
and stderr under normal/silent/silent!. The pinned normal command emits an empty
echo (redirection captures a newline), whereas Lua emits nothing. Both suppress
the final display under silent/silent! and emit one success event in all cases.
The source confirms this difference: upstream always calls helper.echo after
joining decoded output, while command.finish guards on output ~= "". The empty
success path should clear the previous display rather than skip the echo.
Evidence: `/tmp/gin-empty-output.lua`, `/tmp/gin-empty-output-{upstream,lua}.json`.

The remaining diagnostic prefix cannot be stripped uniformly: upstream's
captured-query helper includes a status prefix and Browse's external URL helper
also produces custom messages. Further alignment must identify the execution
path instead of assuming every string with a Git exit prefix is raw executor
stderr. This does not affect the whitespace-preservation change under test.


### Empty successful command output

command.finish now echoes even when decoded output is empty, matching the
pinned bare-command display path. The initial real-Git regression observed no
echo at all; the fix emits an empty non-history message. Six cases cover normal,
silent and silent! in both waiting and asynchronous modes, checking the final
echo and one success event. All 86 command tests pass on current Neovim and
0.10.0. The fresh six-case live comparison (empty success and Git failure across
modifiers) agrees on display, history, return behavior and events.
Formatting and diff checks pass. Validation logs:
`/tmp/gin-empty-output-green.log`, `/tmp/gin-empty-output-nvim010.log`.

The user requested faster parallel worktree integration. Independent Browse,
action UI and help/config work now start from 9302eeb in separate worktrees;
only the foreground main owner cherry-picks. Contributors run scoped tests and
leave shared dependencies/goldens unchanged. Fixed-port tests and the final full
suite are owned by the foreground integrator. The previous full suite passed
4,650 cases at 9302eeb; a new full suite will run on the integrated changes rather
than on each small intermediate commit. This empty-output change currently has
targeted validation, not a new full-suite result.


### Preserve numeric diagnostic text at command boundaries

The display wrapper no longer mistakes `revision:42: missing` for a Lua
source location. It recognizes Lua file and chunk prefixes explicitly while
retaining nested callback unwrapping. The regression failed before the change.
Current Neovim passes 210 command, boundary and Browse cases; Neovim 0.10 passes
145 command and boundary cases. Logs: `/tmp/gin-integrated-prefix-browse.log`
and `/tmp/gin-prefix-nvim010.log`. Full integration validation follows the
parallel batch.


### First parallel worktree integration batch

Main remains the sole integration owner. Worker commits were inspected and
cherry-picked in these pairs (worker -> main):

- Browse revision ordering: 0d717ce -> 34e978a.
- Help/configuration examples: 7900146 -> 9a2f54b.
- Action mapping error boundaries: 368b18d -> 5adac69.
- Action transient output: d04964a -> 80237c2.
- Deferred repeated-choice boundaries: 00d088e -> c32a0e9.
- Missing Browse remotes: f7a5368 -> 15c7755.

Browse passes 72 scoped cases on current Neovim and 0.10. Five revision-error
and six missing-remote live comparisons match pinned upstream. The worker also
confirmed an upstream dependency bug: getCommitURL omits cwd when resolving a
commit, potentially selecting the Denops process repository. Lua keeps the
requested worktree's SHA instead of reproducing this bug. Evidence:
`/tmp/gin-browse-commit-probe.lua`, `/tmp/gin-browse-commit-upstream.json`,
`/tmp/gin-browse-remote-{upstream,lua}.json`.

The action changes preserve strict direct APIs while reporting mapped failures
through the command display boundary, including deferred choice/repeat/alias
paths. The initial action/default-mapping suite passes 78 cases on both Neovim
versions; the final action suite passes 28 on both. Live repeat/help/echo checks
agree with upstream on exception, errmsg and message-history behavior. Logs:
`/tmp/gin-actions-repeat-choice-{green,nvim010}.log` and
`/tmp/gin-action-ui-{upstream,lua}.json`.

Help checks resolve all 115 upstream tags on both versions. The documented
mapping example stages a real fixture, survives refresh and leaves direct
calls outside the choice-repeat history. Shared dependencies and goldens were
not modified by workers; none ran full-suite or fixed-port daemon tests.
The foreground full suite passed all 4,681 cases across 60 groups against
15c7755db31196dab41064fcb43ab2b034df511c, with no failures or notes.
Log: `/tmp/gin-parallel-batch-full.log`.


### Ex-compatible openers

Worker commits efc6c0a and 38cdfbf were integrated as d9d4a72 and de5bddc.
The exact-name whitelist rejected the documented `botright vsplit` opener
and valid `new`/`tabnew` commands. Openers now use Ex parsing and execution,
with escaped filenames and decoding options. Parsed canonical `pedit` detects
compound and abbreviated preview commands while preserving the established
actual-preview-window return contract used by Patch and Chaperon.

Both regressions failed before the changes. On current Neovim and 0.10.0,
124 cases across opener, buffer, editor, Patch and Chaperon pass, including
spaces and literal pipe/percent/hash filename characters, already-visible
buffers, preview focus and encoding/fileformat. Four live opener comparisons
match pinned upstream content, window count and display. Logs:
`/tmp/gin-help-openers-current.log`, `/tmp/gin-help-openers-nvim010.log`,
`/tmp/gin-help-opener-{upstream,lua}.json`. README and help now describe Ex
openers and escaped embedded modifiers. The full-suite result above predates
these opener changes; integration testing will cover the next combined batch.


### Processor startup and compound FileType integration

Worker 7c6ed51 was cherry-picked as f3ac8d6. A missing processor executable
reported an error without recording terminal failure when a friendly callback
was installed, leaving `Gin ++wait` waiting indefinitely. Failure state is now
independent of notification, direct Lua waiting calls remain strict, and user
commands report once without a success event. Worker command tests passed on
current Neovim and 0.10; main's integrated command/boundary suite passes 148
cases on 0.10 (`/tmp/gin-integrated-processor-nvim010.log`). Live evidence:
`/tmp/gin-bare-processor-{audit,fixed}.json`. Bare processors are a Lua extension;
the pinned bare command does not accept this option.

Worker f1f28e7 adds the pinned after-ftplugin entrypoint for compound blame
FileTypes. It reuses guarded blame mappings without changing the host ftplugin.
Five new lifecycle cases cover host settings/order, disabled defaults with Plug
mappings, repeated sourcing with user customization, cleanup/reinitialization
and the actual Lua ftplugin. Both versions pass 168 related cases across four
groups (`/tmp/gin-compound-ftplugin-{current,010}.log`). The tests append the
plugin's after directory to runtimepath and trigger FileType normally. Makefile
format checking now includes the new after tree. The next full suite covers
these changes together with the previously integrated opener fixes.


### Final public-surface inventory

The bounded source inventory accounts for all 17 pinned commands, 18 URI read
hooks (11 BufReadCmd and seven FileReadCmd), the index write hook, 13 public
autoload APIs, 33 action modules and 308 per-view action registrations. Counts
for branch/status/log/reflog/tag/stash are 44/79/62/62/30/31. The command and API
suites discover declarations directly from the pinned source; action tests
compare registrations, aliases and mapping attributes with the pinned oracle.
Per-view functional ledgers above provide the separate real Git-state evidence.

All twelve regular ftplugin paths (including nested gitcommit/gitrebase
extensions), the sole after-ftplugin path, four syntax files and sixteen
default highlight groups have destinations. The new compound-Blame tests
exercise the previously missing after-ftplugin lifecycle. Internal Denops
helpers are implemented by Lua modules rather than preserved as public internal
Vimscript symbols. Blame navigation, diff jumps, components, utilities and
proxy/editor routes are accounted for in their functional ledgers.

This closes the entrypoint discovery inventory; it is not a claim of identical
behavior for every input or scheduling order. Existing documented differences
include component cache timing, native writer behavior and the corrected
Browse working-directory bug. The outstanding writer BOM/end-of-line policy
question above still prevents declaring the migration complete. The integrated
full suite at 8d9bbed5bd38a0e5e84c529a2210b0e24c207134 passed all 4,697 cases
across 62 groups, with zero failures and notes. Log:
`/tmp/gin-parallel-second-full.log`. The top-level audit checklist now records
the completed functional/source audits and retains the writer-policy decision
as an explicit unresolved completion requirement. Earlier chronological entries
that say an audit remains open describe their historical stage; this final
inventory and integrated result supersede those status statements.


### Writer decision prepared for review

The current index-write rules are now documented in help alongside read-label
rules: encoding-specific Unicode BOMs, no Latin-1 BOM, binary LF/no-BOM,
encoding retention, and explicit noendofline/nofixendofline preservation.
These descriptions were checked against edit.encode and existing byte-level
native-write comparisons in test_edit.lua. The help explicitly identifies the
pinned writer differences and pending final policy, rather than treating an
unanswered question as acceptance. No runtime or test behavior changed; the
4,697-case integrated result remains applicable to the runtime tree.
