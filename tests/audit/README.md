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
