# Custom parser regex backend audit

These optional mini.nvim tests compare a candidate with the no-flags JavaScript
`new RegExp(pattern)` used by the pinned vim-gin parsers. They are outside the
normal `tests/test_*.lua` collection and do not add a runtime dependency.

Regenerate or verify the checked-in oracle with Node (generated with v26.8.2):

```sh
node scripts/regex-oracle.mjs --check
node scripts/regex-oracle.mjs --write
```

Review oracle changes before committing them. Captures include the full match
at position 1, followed by numbered groups. Each string is represented as UTF-16
code units, preserving lone surrogates and distinguishing an empty capture from
an unmatched group (`null`). Error messages and named-group dictionaries are
not compared: the current parsers consume numbered captures only.

To audit jsregexp, build a separate checkout as described in the
[regex ADR](../../docs/ADR/20261014-000000-preserve-custom-parser-regex-semantics.md),
then run from the repository root:

```sh
env -u NVIM -u NVIM_LISTEN_ADDRESS GIN_JSREGEXP_ROOT=/path/to/jsregexp \
  nvim --headless --clean -u tests/minimal_init.lua \
  -c "lua MiniTest.run_file('tests/audit/regex.lua')"
```

The checkout must contain `jsregexp.lua` and the built `jsregexp.so`. Each case
runs in a fresh Neovim process with a five-second timeout. Missing dependencies,
execution errors, signals, malformed output, and semantic differences fail the
audit. Compilation errors are compared as a distinct result. A nonzero exit is
an incompatible candidate result, not a passing product test. This finite corpus
is a selection gate, not proof of complete ECMAScript compatibility.

At jsregexp `aadbcc2045ac5bddad8b211c80cb17b002775c26`, on macOS arm64,
23 of the initial 29 cases pass. Failures with this adapter are:

- `optional`, `unmatched-backreference`: absent captures become empty strings.
- `optional-wide`: child exits on signal 11 (SIGSEGV).
- `non-bmp-class`: automatic Unicode mode changes whether a match exists.
- `surrogate-captures`: split surrogate captures differ from JavaScript.
- `nul`: no match for an input containing NUL.

The optional C audit does not install a candidate. Runtime log/reflog/tag/stash
actions use the Lua backend; their integration tests are in `tests/test_parser_options.lua`.

The oracle must be read in binary mode: Vimscript `readfile()` in text mode
removes U+FEFF bytes, including inside JSON strings. An earlier audit incorrectly
reported a whitespace mismatch because of this input corruption.

## Pure Lua backend

`lua/gin/regex.lua` is the runtime compiler and matcher, exercised by
`tests/test_regex_candidate.lua` in the normal mini.nvim suite. It uses UTF-16
code units, per-match capture state and explicit task/choice stacks for backtracking. The
217-case corpus passes, including the initial cases that reject the C candidate
and numeric escapes, legacy character-class ranges and incomplete control
escapes. Numeric escapes account for total capture count (including forward
references), class context, octal digit limits and quantifier binding on
remaining digits. A range involving a class escape becomes a union of both
endpoints and a literal hyphen, as specified by [ECMAScript Annex
B](https://tc39.es/ecma262/multipage/additional-ecmascript-features-for-web-browsers.html#sec-characterrangeorunion).
The presence of named captures anywhere in the pattern determines whether `\k`
is an identity escape or requires a valid named reference, including inside
classes and before the named group.
Run `node scripts/regex-oracle.mjs --check` to revalidate the reference fixture.

Custom Gin candidate parsers now call this backend. Its `match` output is
a list of UTF-16 capture arrays (full match first, unmatched groups null). The
`match_strings` adapter returns UTF-8 strings for selected captures. Scoped `i`, `m` and `s` modifier groups
are implemented for the exercised grammar. Grammar completeness, input encoding
edge cases, large patterns/inputs, recursion limits, resource bounds and a
broader differential corpus remain under audit. Passing
this corpus does not establish full ECMAScript compatibility.

Capture names use checked-in Unicode 17.0 `ID_Start` / `ID_Continue` ranges
generated from Node v26.8.2, plus ECMAScript's dollar/underscore/joiner rules.
The candidate decodes literal code points, four-digit Unicode escapes, braced
escapes and escaped surrogate pairs into a common name key. Names are not
Unicode-normalized. These tables ship under `lua/gin` and require no external runtime.
Regenerate or verify them separately:

```sh
node scripts/regex-identifiers.mjs --write
node scripts/regex-identifiers.mjs --check
```

A changed Node Unicode database can change this output; review changes before
regenerating. The name parser also follows the observed V8 treatment of escaped
`>` as a name terminator, confirmed on Node v26.8.2 and Deno 2.9.6
(V8 15.0.245.2-rusty). For example, `(?<a\u003e>b)` captures `>b` under
name `a`. This compatibility behavior is covered explicitly, rather than
inferred from the ECMAScript identifier grammar.

Duplicate names are accepted across mutually exclusive disjunction alternatives,
while nested or sequential declarations of the same name are rejected. A named
backreference selects the participating capture, preserving numbered captures
and unmatched slots. The oracle covers forward references, repetitions,
backtracking, lookaround and escaped equivalent names.

Scoped modifiers preserve their enclosing settings on exit. Ignore-case matching
uses a generated Unicode 17.0 table for ECMAScript's **non-Unicode** Canonicalize
operation, shared by literals, class membership and backreferences. It excludes
multi-unit uppercase expansions and non-ASCII-to-ASCII mappings; astral letters
remain UTF-16 units. Regenerate or verify the shipped table with:

```sh
node scripts/regex-casefold.mjs --write
node scripts/regex-casefold.mjs --check
```

The modifier cases include nested enable/disable scopes, lookaround, repetitions,
Unicode case exceptions, negated classes, line terminators and invalid syntax.
This still does not establish complete grammar or resource compatibility.

## Generated differential audit

From the repository root, run `node scripts/regex-differential.mjs`. Set
`GIN_REGEX_NVIM` to test a different Neovim binary. Node builds a deterministic
corpus of 1,248 short patterns and 22,470 comparisons covering combinations of
repetition, alternatives, captures, backreferences, assertions, classes and
selected malformed syntax. Invalid patterns count as one compilation comparison;
valid patterns are matched against 19 short inputs.

A separate Neovim process runs the optional mini.nvim audit, with a 60-second
process timeout. Signals, errors, nonzero exit codes and missing/incomplete
result reports fail. Fixtures and complete mismatch reports remain in the
printed temporary directory; stderr is retained in the output. The runner also
rejects a zero-exit process that did not produce a completion report.

The initial audit exposed three accepted orphan-quantifier patterns (`{1}`,
`{2,1}`, `a{1}{2}`) that JavaScript rejects. These were fixed and added to the
normal regression corpus alongside literal-brace controls. All generated
comparisons now pass. This finite grammar and short-input audit does not measure
large-input behavior, resource bounds or full ECMAScript compatibility.

## Long input checks

The initial continuation-based matcher overflowed the Lua call stack on a long
`a+` input; whether it failed depended on JIT trace history. Matching now uses
explicit task and choice stacks for sequences, captures, alternatives and
repetitions. Six normal-suite tests compare full capture arrays for 65,536-byte
inputs with JIT temporarily disabled and its prior enabled state restored. They
cover greedy/lazy matching, backtracking, repeated captures, alternatives and
lookbehind. The expected capture lengths were also checked with Node.

This removes call-stack growth proportional to ordinary input repetition.
Lookaround evaluation still recurses with assertion nesting, and the compiler
recurses with pattern nesting. Heap usage and pathological backtracking are not
bounded by this change; these resource limits remain under audit.

## Candidate parser boundary

The pinned log/reflog parsers apply a custom pattern directly to nonempty display
lines and consume capture 1; tags consume capture 1 (commit) and 2 (tag); stash
consumes capture 1 (reference) and parses capture 2 as a decimal index. There is
no default-pattern fallback after a custom match fails. This contract was
rechecked against `.deps/vim-gin` at the locked revision. Production custom
matching now follows this contract through `gin.candidate`.

`compiled:match_strings(text, indices)` now provides the string conversion
needed at that boundary. Indices use Lua ordering: 1 is the full match, 2 the
first capture, and so on. Omit indices to convert all captures. No match returns
nil; absent/unmatched captures are `vim.NIL`, while empty captures remain empty
strings. NUL and valid surrogate pairs are preserved as UTF-8. Selected lone
surrogates raise an explicit conversion error, matching the fact that Neovim's
JSON decoder rejects a JSON string containing an unpaired surrogate. Unselected
captures are not converted, since upstream parsers do not expose those fields.
Five adapter tests cover these distinctions and UTF-8 encoding boundaries.

## Pinned parser oracle

`node scripts/parser-oracle.mjs --write` regenerates and `--check` verifies
`parser-oracle.json` using the four TypeScript parsers from the locked vim-gin
checkout. The script requires the expected HEAD and unmodified parser sources;
Node v26.8.2 loads those files directly. The 44 cases compare editor-facing JSON
for custom patterns across empty/unmatched captures, duplicate and blank lines,
Unicode, syntax errors and invalid/overflowing stash indices. Buffer NULs become
embedded newlines at the getbufline boundary before upstream parsing.

`tests/test_candidate_parser.lua` runs the fixture in the ordinary mini.nvim
suite and checks that every candidate remains an object, even when all captures
are missing. An actual echo-action test also verifies `[{}, {}]` formatting
instead of the accidental `[[], []]` produced by untyped empty Lua tables.

## View action registration oracle

```sh
node --experimental-vm-modules scripts/action-oracle.mjs --check
node --experimental-vm-modules scripts/action-oracle.mjs --write
```

This optional Node script (verified with v26.8.2) executes the pinned Branch,
Status, Log, Reflog, Tag and Stash initializers and their action modules, capturing mapping names, alias targets and mapping options.
It checks the upstream commit and rejects changes to the executed source tree.
Type-only names from the older TypeScript imports are removed after stripping
types. Batch/buffer callbacks run directly; buffer rendering, event binding,
flag formatting, status sorting/view preservation and filetype setting are
stubbed. Nullish option handling is reproduced for absent command options. No action callback is run.
Unexpected editor calls fail. Node reports experimental API warnings for its
VM modules and TypeScript stripping; these are tooling-only dependencies.

The regular mini.nvim Branch and default-mapping suites compare the captured
registrations with real Lua buffer mappings: Branch 44, Status 79, Log 62,
Reflog 62, Tag 30 and Stash 31 (308 total). The options captured for direct actions and aliases are checked for uniformity;
regeneration fails if a registration needs per-action option handling. The
mapping suite compares names, aliases and buffer/noremap/silent/expr/nowait/script
attributes in Normal, Visual, Select and Operator-pending modes. It also checks
that these actions are absent from Insert, Command-line, Terminal and Lang-Arg
modes. The mode/default interpretation follows denops std 7's mapping helper.
This does not establish execution semantics or unlisted views, which require
separate integration and mapping tests.

## Text decoding oracle

`deno run --allow-read --allow-write --allow-run --allow-env scripts/encoding-oracle.mjs --check`
verifies the checked-in alias table, single-byte mappings and decoding fixture;
use `--write` to regenerate them. Deno is development-only. The generator checks
vim-gin's locked HEAD and records the SHA256 of the vendored WHATWG
`encodings.json` label registry. Generated Lua headers record the Deno version.

The normal `tests/test_encoding.lua` suite compares strict decoding with actual
Deno TextDecoder results for 37 supported encoding families. Each single-byte
family includes all 256 byte values; Unicode fixtures include BOMs, opposite
byte order, surrogate pairs, incomplete units and invalid UTF-8. Alias tests
include ASCII case and whitespace normalization. Separate cases cover ordered
candidate selection, fallback UTF-8 replacement and BOM metadata.

This is preparatory library coverage, not complete encoding parity. All 39
Deno-supported encoding families now have strict candidate decoders. The library
now supplies automatic buffer encoding selection; explicit nonfatal decoding
remains under audit. The Unicode corpus
is finite; single-byte expected values and production mappings share the Deno
oracle, so exhaustive byte tests verify the Lua lookup path, not Deno itself.

Shift_JIS additionally has a checked-in 256-by-256 oracle matrix for every
2-byte input, exercised by `tests/test_shift_jis.lua`. False entries mean fatal
decoding errors; strings are exact output (including embedded NUL). The ordinary
encoding fixture also covers every single byte, alias normalization, Japanese
text, halfwidth kana, private-use mappings, truncation and 200 deterministic
longer inputs. Candidate tests check successful selection and fallback after an
incomplete lead byte. The production mapping contains 9,604 valid lead/trail
pairs and is loaded only when Shift_JIS is requested. Runtime requires only Lua.

Big5 and EUC-KR have separate full byte-pair matrices, checked by
`tests/test_double_byte_encoding.lua`, and every single byte plus 200 deterministic
longer inputs in the common encoding fixture. Big5's four two-codepoint mappings
are preserved as strings, with an explicit concatenated regression. Big5 has
18,594 mapped pairs; EUC-KR has 17,048. Both use lazily loaded tables indexed by
lead and trail byte. Candidate tests cover Korean text, expanding Big5 output
and fallback after incomplete leads. Automatic view selection is covered separately by `tests/test_fileencodings.lua`.

EUC-JP has matrices for all byte pairs and all triples starting with 0x8F,
exercised by `tests/test_euc_jp.lua`. Its ordinary encoding fixture covers every
single byte, aliases, 200 deterministic longer inputs mixing planes/kana/ASCII,
and explicit incomplete sequences. Separate candidate tests preserve supplementary
characters and reject truncated triples. JIS0208 (7,336 mappings) and JIS0212
(6,067 mappings) use independent generated codepoint tables. The generator also
checks every mapped JIS0208 pair against ISO-2022-JP; the ISO-2022-JP decoder reuses this
table. EUC-JP halfwidth kana is algorithmic.
View-level selection is covered separately by `tests/test_fileencodings.lua`.

ISO-2022-JP has full matrices for every byte pair in JIS mode and every pair
following ESC. Its common fixture includes every byte in each of the five
supported escape-designated modes, transitions with/without intervening output,
and deterministic longer mixed input. `tests/test_iso_2022_jp.lua` also verifies
adjacent-escape rejection, truncated escapes, state isolation and candidate order.
The strict decoder fails immediately on malformed input; explicit nonfatal
TextDecoder behavior remains a separate compatibility task. Runtime shares the
JIS0208 table with EUC-JP and maintains all mode state within one decode call.

GBK and GB18030 share a decoder after comparing all single bytes, byte pairs and
structurally valid four-byte candidates in Deno. Generate/check their separate
assets with:

```sh
deno run --allow-read --allow-write --allow-run --allow-env scripts/gb18030-oracle.mjs --check
```

Use `--write` to regenerate. The script checks the pinned vim-gin HEAD and records
Deno's version. The runtime uses 23,940 mapped byte pairs and 209 contiguous
four-byte ranges. It rejects unmapped pointers and invalid structural bytes.
The regular `tests/test_gb18030.lua` suite covers every byte pair for both names,
all labels, single bytes, range boundaries, all single-position byte mutations
of selected four-byte sequences, truncation and mixed longer input. The reference
fixture contains 4,793 non-matrix cases shared by both aliases.

An optional exhaustive mini.nvim audit compares the runtime's output for all
1,587,600 structurally valid four-byte candidates with a SHA256 digest generated
directly from Deno output (Unicode codepoint or -1, one decimal record per line):

```sh
env -u NVIM -u NVIM_LISTEN_ADDRESS nvim --headless --clean -u tests/minimal_init.lua \
  -c "lua MiniTest.config.collect.find_files = function() return {'tests/audit/gb18030.lua'} end; MiniTest.run()"
```

The expected digest is independent of the compressed runtime tables. Deno accepts
1,087,996 of these candidates. This exhaustive four-byte audit does not establish
arbitrary-length/nonfatal decoding parity or view integration.

Single-byte replacement decoding is checked separately from strict selection.
The common oracle includes nonfatal output for every single byte and one input
containing all 256 bytes for each of the 29 single-byte families (7,453 reference
comparisons). `gin.encoding.decode(data, label, { fatal = false })` enables
replacement for UTF-8, UTF-16, these families, Shift_JIS, Big5 and EUC-KR;
unsupported replacement codecs fail
explicitly. `supports_replacement` gates the view integration while the remaining
nonfatal codecs are implemented. Strict decoding remains the default used by
automatic selection. Real-view tests cover Latin-1/ASCII Windows-1252 aliases,
undefined bytes, and destination-option preservation on addressed reads.

UTF-16 replacement decoding uses fixed byte order from the normalized label;
`utf-16` and `ucs-2` mean UTF-16LE. The common generator writes full 256-by-256
replacement matrices for LE and BE and adds boundary code-unit combinations,
all one-byte suffixes after selected units, lone bytes and deterministic longer
inputs to the regular fixture. `tests/test_utf16_encoding.lua` checks every
2-byte input and verifies that strict candidate mode still rejects malformed
surrogates. The view suite also covers partial units, malformed surrogate pairs,
labels, addressed reads and unchanged source bytes. Native write-encoding names
remain separate: big-endian utf-16/ucs-2 writes are read back explicitly as
utf-16be in the existing write tests.

Shift_JIS, Big5 and EUC-KR fixtures also contain nonfatal output matrices for
every byte pair. The existing pair tests now check both strict success/error and
exact replacement text; common fixture cases cover each single byte and longer
inputs in both modes. Invalid pairs reprocess an ASCII trailing byte, while
non-ASCII trails are consumed with the failed lead. Invalid standalone leads
consume only themselves. The explicit-read suite covers both views and addressed
reads, including retained ASCII delimiters, incomplete leads and 0x80 differences.

EUC-JP replacement fixtures cover every byte pair and every 0x8F-prefixed triple
alongside the strict matrices. Common fixtures include all single bytes and
mixed longer sequences. Explicit-read tests cover incomplete supplementary
characters, ASCII recovery at the second and third bytes, non-ASCII failures,
kana recovery and normal JIS0208 characters after an error, through both views
and addressed reads. Automatic detection still uses strict decoding.

ISO-2022-JP replacement matrices cover every JIS pair and every two-byte escape
suffix. Common cases cover single bytes in each output state, adjacent valid
escapes and mixed longer inputs. View and addressed-read cases test escape
recovery, interrupted JIS characters, truncated prefixes and state changes after
errors. Strict automatic selection continues to reject malformed input.
