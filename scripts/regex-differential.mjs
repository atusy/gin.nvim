// Optional deterministic audit; Node is an oracle, never a Gin runtime dependency.
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const atoms = ['a', 'b', '.', '[ab]', '[^a]', '\\d', '\\s', '(a)', '(a?)', '(?:a|b)', '(?=a)', '(?!b)', '(?<=a)', '(?<!b)', '\\b', '^', '$', '()'];
const quantifiers = ['', '?', '*', '+', '{0}', '{1,2}', '*?'];
const patterns = new Set();
for (const atom of atoms) {
  for (const quantifier of quantifiers) {
    patterns.add(`${atom}${quantifier}`);
    patterns.add(`^${atom}${quantifier}b$`);
  }
}
for (const left of atoms) {
  for (const right of atoms) {
    patterns.add(`^(${left}|${right})*$`);
    patterns.add(`^(${left})(${right})\\1\\2$`);
    patterns.add(`(?i:^${left}${right}$)`);
  }
}
for (const pattern of ['{1}', '{2,1}', 'a{', 'a{1', 'a{1,}', 'a{1,2}', 'a{2,1}', 'a{,2}', '[', '[]', '[^]', '[a-b-c]', '[\\d-a]', '(?i)', '(?-:a)', 'a**', 'a??', 'a{1}{2}', 'a|', '|a', '\\', '\\x', '\\u', '\\c', '\\k<x>']) patterns.add(pattern);
const inputs = ['', 'a', 'b', 'ab', 'aa', 'bb', 'aba', 'aab', 'abab', 'aaaa', '1', ' ', 'a\n', '\na', 'A', 'Ab', 'β', '😀', '\0'];
const units = (s) => Array.from({ length: s.length }, (_, i) => s.charCodeAt(i));
const cases = [];
for (const pattern of patterns) {
  let regex;
  try { regex = new RegExp(pattern); }
  catch { cases.push({ pattern, input: '', expected: { status: 'compile-error' } }); continue; }
  for (const input of inputs) {
    const match = regex.exec(input);
    cases.push({ pattern, input, expected: match === null ? { status: 'no-match' }
      : { status: 'match', captures: Array.from(match, (s) => s === undefined ? null : units(s)) } });
  }
}
const directory = mkdtempSync(join(tmpdir(), 'gin-regex-differential-'));
const path = join(directory, 'cases.json');
writeFileSync(path, JSON.stringify({ node: process.version, patterns: patterns.size, cases }));
console.log(`${patterns.size} patterns, ${cases.length} comparisons; fixture: ${path}`);
const env = { ...process.env, GIN_REGEX_DIFFERENTIAL_FILE: path };
delete env.NVIM;
delete env.NVIM_LISTEN_ADDRESS;
const result = spawnSync(process.env.GIN_REGEX_NVIM || 'nvim', ['--headless', '--clean', '-u', 'tests/minimal_init.lua', '-c', "lua MiniTest.run_file('tests/audit/regex_differential.lua')"], { env, encoding: 'utf8', timeout: 60_000, maxBuffer: 8 * 1024 * 1024 });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) console.error(result.error.message);
if (result.signal) console.error(`Neovim terminated by ${result.signal}`);
let complete = false;
try {
  const report = JSON.parse(readFileSync(path + '.result.json', 'utf8'));
  complete = report.compared === cases.length && Array.isArray(report.failures) && report.failures.length === 0;
} catch (error) { console.error(`Missing or invalid completion report: ${error.message}`); }
process.exitCode = result.status === 0 && !result.error && !result.signal && complete ? 0 : 1;
