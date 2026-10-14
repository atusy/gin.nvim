# Preserve default JavaScript regex semantics for custom candidate parsers

| | |
| --- | --- |
| Status | accepted |
| Date | 2026-10-14 |
| Decision-makers | Codex, within the maintainer-authorized Lua migration |
| Consulted | Native preference was unresolved at drafting; the chosen Lua backend needs no native dependency |

## Context

The pinned vim-gin revision constructs `new RegExp(setting)` without flags for
four candidate-parser settings. Captures select commits, tags and stashes for
actions. A different regex language or automatically enabled flag can therefore
change which object an action targets. Custom matching was missing when this decision was proposed; the four settings
are now connected to the Lua backend.

## Drivers

- Preserve the pinned parser's match and capture semantics.
- Keep plugin behavior implemented in Lua for Neovim, without Denops.
- Avoid requiring an external process for every candidate line.
- Make backend requirements and compatibility limits explicit.

## Options

1. A pure Lua ECMAScript matcher. This avoids native build dependencies but
   requires maintaining parsing, backtracking, captures and UTF-16 semantics.
2. A Lua C binding to an ECMAScript engine, with a compatibility adapter or
   maintained patch if necessary. This reuses an existing engine but introduces
   a compiler/module-installation requirement and a backend compatibility gate.
3. Lua/Vim pattern translation. This is small but is not equivalent for general
   JavaScript regexes; it is unsuitable as an unrestricted replacement.
4. A JavaScript subprocess. This offers a direct oracle but adds a runtime and
   process lifecycle to interactive actions. It remains useful for testing.

## Decision

Use the pure Lua backend in `lua/gin/regex.lua`, with checked-in Unicode 17.0
identifier and non-Unicode canonicalization tables. Preserve the no-flags
JavaScript constructor semantics rather than translating patterns into Lua/Vim
syntax. Node is a development oracle only; installation needs no JavaScript
runtime, native build or extra package.

The backend is now connected to all four custom parser settings. Compile once
per candidate collection, select the upstream capture fields, and propagate
compilation/conversion failures without falling back to default candidates.
Keep the existing default paths when the setting is absent or null.

This accepts a maintained Lua implementation, not a claim of complete ECMAScript
compatibility. Input encoding extremes, deeply nested patterns/lookaround, heap
usage and pathological backtracking remain known validation limits. Matching
has no implicit timeout, as with the existing synchronous command behavior.

## Evidence

Inspected and built `kmarius/jsregexp` at
`aadbcc2045ac5bddad8b211c80cb17b002775c26` in an isolated `/tmp` checkout.
Its `jsregexp_compile` sets `LRE_FLAG_UNICODE` when the pattern contains a
non-BMP character, even with no flags supplied. The wrapper uses QuickJS
libregexp. This is confirmed in source and by Neovim/LuaJIT execution, compared
with Node's `new RegExp(pattern)`.

| Pattern | Input | JavaScript capture 1 | jsregexp capture 1 |
| --- | --- | --- | --- |
| `^(?:hash: )([a-f0-9]+)(?= end$)` | `hash: abc123 end` | `abc123` | `abc123` |
| `^(a+)\1$` | `aaaa` | `aa` | `aa` |
| `^([😀])$` | `😀` | no match | `😀` (automatically enables `u`) |
| `^(.)$` | `😀` | no match | no match |
| `^(\uD83D\uDE00)$` | `😀` | `😀` | `😀` |

The non-Unicode JavaScript character class matches one UTF-16 code unit, while
the anchored input occupies two. Automatically enabling Unicode mode changes
this result. The two ASCII successes do not establish general compatibility.

Sources:
- [jsregexp README](https://github.com/kmarius/jsregexp/blob/aadbcc2045ac5bddad8b211c80cb17b002775c26/README.md)
- [jsregexp compiler](https://github.com/kmarius/jsregexp/blob/aadbcc2045ac5bddad8b211c80cb17b002775c26/jsregexp.c)
- [reLua](https://github.com/o080o/reLua), another investigated pure Lua candidate;
  no compatibility conclusion or adoption is made here.

## Reproduction

In the pinned jsregexp checkout, the local macOS build used LuaJIT headers and
resolved Lua symbols from the Neovim host (no global installation):

```sh
make INCLUDE_DIR=-I/opt/homebrew/opt/luajit/include/luajit-2.1 \
  LDFLAGS='-bundle -undefined dynamic_lookup'
```

Load that checkout in a clean Neovim with both `NVIM` and `NVIM_LISTEN_ADDRESS`
unset. The minimal comparison is:

```lua
package.preload['jsregexp.core'] = assert(package.loadlib(
  '/tmp/gin-jsregexp-review/jsregexp.so', 'luaopen_jsregexp_core'
))
package.path = '/tmp/gin-jsregexp-review/?.lua;' .. package.path
local regex = require('jsregexp').compile('^([😀])$')
local match = regex:match('😀')
print(regex.unicode, match and match[1]) -- true, 😀
```

```js
const regex = new RegExp('^([😀])$');
console.log(regex.unicode, '😀'.match(regex)); // false, null
```

## Consequences and confirmation

The plugin now owns a substantial regex implementation and Unicode table update
process. This avoids native builds and JavaScript runtime dependencies, while
requiring continued semantic and resource testing. Ordinary repetition uses
explicit task/choice stacks; pattern parsing and nested lookaround still use
recursion. Selected unpaired surrogate captures fail conversion explicitly.

Validation includes 217 curated Node cases, six 65,536-byte tests with JIT
disabled, five string-adapter tests, and 22,470 generated comparisons. Product
tests exercise the four custom capture paths, actual custom tag deletion and
stash drop selection, and errors/no-match without default-target fallback.
Missing captures required by Git actions fail before argument construction;
yank retains empty slots, matching the upstream join behavior. Minimum Neovim
0.10 is included in validation. These tests prove their exercised cases, not
full language compatibility or migration completion.

The C candidate remains rejected unchanged: binary fixture reading corrected
its original U+FEFF false mismatch, but it still fails six of the initial 29
cases, including an unmatched-capture SIGSEGV. See `tests/audit/README.md` for
reproduction, generated data commands and remaining validation limits.
