// Capture the pinned parsers' editor-facing JSON, including undefined and NaN.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const lock = JSON.parse(readFileSync(new URL('../deps-lock.json', import.meta.url)));
const head = execFileSync('git', ['-C', root + '.deps/vim-gin', 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (head !== lock['vim-gin'].commit) throw new Error('vim-gin checkout does not match deps-lock.json');
execFileSync('git', ['-C', root + '.deps/vim-gin', 'diff', '--exit-code', 'HEAD', '--', ...['log', 'reflog', 'tag', 'stash'].map(kind => `denops/gin/command/${kind}/parser.ts`)]);
// getbufline exposes a buffer's NUL bytes as embedded newlines to Denops.
const patterns = ['', '.*', '^(a)?$', '^(a*)$', '^(\\w+)$', '^(.*?):(.*)$', '^([a-f0-9]+)\\s+(\\S+)', '^(stash@\\{(\\d+)\\})', '^(a)?(b)$', '^(?i:(a))$', '('];
const lines = ['', 'a', 'b', 'ab', 'A', 'abc123 release', 'stash@{12}: saved', 'ref:　-12tail', 'ref:invalid', 'ref:' + '9'.repeat(400), 'β😀', 'a\0b', 'a', '\ufeffa'];
const records = [];
for (const kind of ['log', 'reflog', 'tag', 'stash']) {
  const { parse } = await import(new URL(`../.deps/vim-gin/denops/gin/command/${kind}/parser.ts`, import.meta.url));
  for (const pattern of patterns) {
    let expected;
    try {
      let entries = parse(lines.map(line => line.replaceAll('\0', '\n')), new RegExp(pattern)).entries;
      if (kind === 'stash') entries = entries.map(entry => ({ ...entry, commit: entry.stashRef }));
      expected = { status: 'ok', entries };
    } catch { expected = { status: 'error' }; }
    records.push({ kind, pattern, lines, expected });
  }
}
const serialized = JSON.stringify(records, null, 2) + '\n';
const path = fileURLToPath(new URL('../tests/audit/parser-oracle.json', import.meta.url));
if (process.argv[2] === '--write') writeFileSync(path, serialized);
else if (process.argv[2] !== '--check') throw new Error('usage: node scripts/parser-oracle.mjs --write|--check');
else if (readFileSync(path, 'utf8') !== serialized) throw new Error('Pinned parser oracle changed');
console.log(`${records.length} pinned parser cases verified at ${head}`);
