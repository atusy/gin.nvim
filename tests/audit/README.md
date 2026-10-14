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

No candidate is installed or selected by these tools. Actual log/reflog/tag/stash
action integration and error propagation still require separate product tests.

The oracle must be read in binary mode: Vimscript `readfile()` in text mode
removes U+FEFF bytes, including inside JSON strings. An earlier audit incorrectly
reported a whitespace mismatch because of this input corruption.

## Pure Lua candidate

`lua_regex.lua` is an experimental compiler and matcher, exercised by
`tests/test_regex_candidate.lua` in the normal mini.nvim suite. It uses UTF-16
code units, per-match capture state and continuation-based backtracking. The
64-case corpus passes, including the initial cases that reject the C candidate
and decimal/octal escape and legacy character-class range cases. Numeric escapes
account for total capture count (including forward references), class context, octal digit limits and
quantifier binding on remaining digits. A range involving a class escape
becomes a union of both endpoints and a literal hyphen, as specified by
[ECMAScript Annex B](https://tc39.es/ecma262/multipage/additional-ecmascript-features-for-web-browsers.html#sec-characterrangeorunion).
Run `node scripts/regex-oracle.mjs --check` to revalidate the reference fixture.

This is not an adopted runtime backend and no Gin action calls it. Its output
is a list of UTF-16 capture arrays (full match first, unmatched groups null),
not the strings needed by action parsers. Known unimplemented areas include
some legacy control escapes, non-ASCII/escaped capture names and duplicate-name
rules. Some valid JavaScript patterns therefore raise an unsupported-syntax
error. Input encoding edge cases, large patterns/inputs, recursion limits, resource bounds
and a broader differential corpus must also be audited before integration.
Passing the initial corpus does not establish full ECMAScript compatibility.
