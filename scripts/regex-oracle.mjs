// No flags: this is the constructor used by the pinned vim-gin parsers.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const cases = [
  ['log', '^([a-f0-9]+)\\b', 'abc123 message'],
  ['tag', '^([a-f0-9]+)\\s+(\\S+)', 'abc123 release'],
  ['stash', '^(stash@\\{(\\d+)\\})', 'stash@{12}: saved'],
  ['alternation', '^(foo|bar)$', 'bar'],
  ['greedy', '^(a+)(a*)$', 'aaaa'],
  ['lazy', '^(a+?)(a*)$', 'aaaa'],
  ['optional', '^(a)?(b)$', 'b'],
  ['optional-wide', '^(a)?(β)$', 'β'],
  ['empty-capture', '^(a*)(b)$', 'b'],
  ['lookahead', '^(?:hash: )([a-f0-9]+)(?= end$)', 'hash: abc123 end'],
  ['negative-lookahead', '^(?!bad)(\\w+)$', 'good'],
  ['lookbehind', '(?<=hash: )([a-f0-9]+)', 'hash: abc123'],
  ['negative-lookbehind', '(?<!x)(a)', 'a'],
  ['backreference', '^(a+)\\1$', 'aaaa'],
  ['unmatched-backreference', '^(a)?\\1(b)$', 'b'],
  ['named', '^(?<commit>[a-f0-9]+)$', 'abc123'],
  ['named-backreference', '^(?<letter>a)\\k<letter>$', 'aa'],
  ['invalid', '(', 'abc'],
  ['no-match', '^(a)$', 'b'],
  ['empty-match', '()', 'abc'],
  ['empty-pattern', '', 'abc'],
  ['whitespace', '^\\s+(a)$', '\u00a0\ufeffa'],
  ['non-bmp-class', '^([😀])$', '😀'],
  ['non-bmp-dot', '^(.)$', '😀'],
  ['surrogate-pair', '^(\\uD83D\\uDE00)$', '😀'],
  ['surrogate-captures', '^(.)(.)$', '😀'],
  ['nul', '^(a\\x00b)$', 'a\0b'],
  ['line-terminator', '^(.*)$', 'a\u2028b'],
  ['last-line-ending', '^(a)$', 'a\n'],
];
const units = (s) => Array.from({ length: s.length }, (_, i) => s.charCodeAt(i));
const records = cases.map(([name, pattern, input]) => {
  let regex;
  try { regex = new RegExp(pattern); }
  catch { return { name, pattern, input, expected: { status: 'compile-error' } }; }
  const match = input.match(regex);
  return { name, pattern, input, expected: match === null
    ? { status: 'no-match' }
    : { status: 'match', captures: Array.from(match, (s) => s === undefined ? null : units(s)) } };
});
const path = fileURLToPath(new URL('../tests/audit/regex-oracle.json', import.meta.url));
const serialized = JSON.stringify(records, null, 2) + '\n';
if (process.argv[2] === '--write') writeFileSync(path, serialized);
else if (process.argv[2] !== '--check') throw new Error('usage: node scripts/regex-oracle.mjs --write|--check');
else if (readFileSync(path, 'utf8') !== serialized) throw new Error('regex oracle changed; inspect before regenerating');
console.log(`${records.length} no-flags JavaScript cases verified`);
