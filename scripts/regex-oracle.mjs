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

  ['octal-one', String.raw`^\1$`, '\x01'],
  ['octal-leading-zero', String.raw`^(\01)$`, '\x01'],
  ['octal-three-digits', String.raw`^(\377)$`, '\xff'],
  ['octal-limit', String.raw`^(\400)$`, ' 0'],
  ['decimal-identity', String.raw`^(\89)$`, '89'],
  ['octal-and-digit', String.raw`^(\18)$`, '\x018'],
  ['octal-tail-quantifier', String.raw`^(\18+)$`, '\x01888'],
  ['octal-tail-not-group-quantifier', String.raw`^(\18+)$`, '\x018\x018'],
  ['octal-leading-zero-before-capture', String.raw`^\01(a)$`, '\x01a'],
  ['forward-reference', String.raw`^\1(a)$`, 'a'],
  ['forward-reference-two', String.raw`^\2(a)(b)$`, 'ab'],
  ['decimal-not-reference-prefix', String.raw`^(a)\18$`, 'a\x018'],
  ['decimal-reference-ten', String.raw`^(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\10$`, 'abcdefghijj'],
  ['forward-reference-ten', String.raw`^\10(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)$`, 'abcdefghij'],
  ['class-octal-with-capture', String.raw`^(a)[\1]$`, 'a\x01'],
  ['class-octal-range', String.raw`^([\1-\3]+)$`, '\x01\x02\x03'],
  ['class-decimal-identity', String.raw`^([\8\9]+)$`, '8998'],
  ['escaped-parentheses-not-captures', String.raw`^\1\(a\)$`, '\x01(a)'],
  ['class-parentheses-not-captures', String.raw`^\1[(]$`, '\x01('],
  ['noncapture-not-capture', String.raw`^\1(?:a)$`, '\x01a'],
  ['lookaround-not-capture', String.raw`^\1(?=a)a$`, '\x01a'],
  ['named-group-counted', String.raw`^\1(?<name>a)$`, 'a'],
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
