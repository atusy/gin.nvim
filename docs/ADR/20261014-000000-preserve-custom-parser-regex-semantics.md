# Preserve default JavaScript regex semantics for custom candidate parsers

| | |
| --- | --- |
| Status | proposed |
| Date | 2026-10-14 |
| Decision-makers | maintainer; implementation proposal by Codex |
| Consulted | maintainer asked whether a C-extension dependency is acceptable; unanswered at drafting |

## Context

The pinned vim-gin revision constructs `new RegExp(setting)` without flags for
four candidate-parser settings. Captures select commits, tags and stashes for
actions. A different regex language or automatically enabled flag can therefore
change which object an action targets. Type validation is implemented, but
custom matching remains missing.

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

## Proposed outcome

Do not adopt an unmodified backend merely because it advertises ECMAScript
support. Validate the exact no-flags constructor behavior and captures first.
Keep backend selection open pending the native-dependency preference and a
successful compatibility evaluation. No C dependency is added by this ADR.

The current `jsregexp` candidate cannot be used unchanged: its automatic `u`
flag changes a demonstrated no-flags match. An adapter/fork must resolve that
behavior before integration; otherwise continue evaluating a pure Lua matcher.

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

The remaining feature stays visibly incomplete while its backend is evaluated.
This avoids silently changing action targets, but delays custom matching and
may require either native builds or a substantial Lua implementation.

Before accepting a backend, compare capture results against the pinned
no-flags constructor for alternation, greedy/lazy repetition, optional and
unmatched captures, lookaround, backreferences, named groups, invalid patterns,
empty matches, Unicode whitespace and non-BMP input. Then use mini.nvim tests to
prove that custom captures control the four real action paths and that failed
compilation/matching does not fall back to unrelated candidates. Validate the
minimum supported Neovim and document installation on supported platforms.
