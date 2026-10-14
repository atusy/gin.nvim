// Execute pinned view action registration; never execute an action callback.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { stripTypeScriptTypes } from 'node:module';
import { SourceTextModule, SyntheticModule } from 'node:vm';
const root = fileURLToPath(new URL('../', import.meta.url));
const upstream = root + '.deps/vim-gin/';
const lock = JSON.parse(readFileSync(root + 'deps-lock.json'));
const head = execFileSync('git', ['-C', upstream, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (head !== lock['vim-gin'].commit) throw new Error('vim-gin checkout does not match deps-lock.json');
const kinds = ['branch', 'status', 'log', 'reflog', 'tag', 'stash'];
execFileSync('git', ['-C', upstream, 'diff', '--exit-code', 'HEAD', '--', 'denops/gin/action', ...kinds.map(kind => `denops/gin/command/${kind}/edit.ts`)]);
const mappings = new Map();
const mappingOptions = {};
const fail = () => { throw new Error('Unexpected editor or action execution during registration'); };
const exports = {
  batch: async (denops, callback) => callback(denops),
  ensure: async (denops, _bufnr, callback) => callback(denops),
  map: async (_denops, lhs, rhs, options = {}) => {
    const name = lhs.match(/^<Plug>\(gin-action-(.*)\)$/)?.[1];
    if (name === undefined) throw new Error('Unexpected mapping: ' + lhs);
    const alias = rhs.match(/^<Plug>\(gin-action-(.*)\)$/)?.[1] ?? null;
    const category = alias === null ? 'action' : 'alias';
    if (mappingOptions[category] && JSON.stringify(mappingOptions[category]) !== JSON.stringify(options)) {
      throw new Error(`Nonuniform mapping options for ${category}: ${name}`);
    }
    mappingOptions[category] = options;
    mappings.set(name, alias);
  },
  bind: async () => {},
  exec: async () => {}, // Buffer rendering is outside this registration oracle.
  formatFlags: () => [],
  filetype: { setLocal: async () => {} },
  unnullish: (value, callback) => value == null ? value : callback(value),
  modifiable: async (denops, _bufnr, callback) => callback(denops),
  winsaveview: async () => ({}), winrestview: async () => {},
  group: async (_denops, _name, callback) => callback({ remove() {}, define() {} }),
  builtinOpts: [], validateOpts: fail, findWorktreeFromDenops: fail,
  parse: fail, parseOpts: fail, assert: fail, is: {}, revParse: fail,
  yank: fail, join: fail, dirname: fail,
};
const stubs = new SyntheticModule(Object.keys(exports), function() {
  for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
});
const modules = new Map();
async function load(path) {
  if (modules.has(path)) return modules.get(path);
  // The pinned source predates explicit type-only imports for these erased types.
  const source = stripTypeScriptTypes(readFileSync(path, 'utf8')).replace(
    /import \{([^}]+)\} from/g, (_match, names) => 'import {' + names.split(',').filter(name => !['GatherCandidates', 'Range', 'Branch', 'Flags', 'Entry'].includes(name.trim())).join(',') + '} from',
  );
  const module = new SourceTextModule(source, { identifier: path });
  modules.set(path, module);
  await module.link(async (specifier, parent) => {
    if (specifier.startsWith('.')) {
      const path = fileURLToPath(new URL(specifier, pathToFileURL(parent.identifier)));
      if (path.startsWith(upstream + 'denops/gin/action/')) return load(path);
    }
    return stubs;
  });
  return module;
}
const oracle = { commit: head, mapping_options: mappingOptions };
for (const kind of kinds) {
  mappings.clear();
  const module = await load(upstream + `denops/gin/command/${kind}/edit.ts`);
  await module.evaluate();
  const denops = {
    dispatcher: {}, call: fail, dispatch: fail,
    cmd: async command => { if (command !== 'silent! 2,$sort /.. /)') fail(); },
  };
  await module.namespace.exec(denops, 1, {});
  if (!mappings.size) throw new Error(`No actions registered for ${kind}`);
  oracle[kind] = Object.fromEntries([...mappings].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
}
const output = JSON.stringify(oracle, null, 2) + '\n';
const destination = root + 'tests/audit/action-oracle.json';
if (process.argv[2] === '--write') writeFileSync(destination, output);
else if (process.argv[2] !== '--check') throw new Error('usage: node --experimental-vm-modules scripts/action-oracle.mjs --write|--check');
else if (readFileSync(destination, 'utf8') !== output) throw new Error('Pinned action oracle changed');
console.log(kinds.map(kind => `${kind}: ${Object.keys(oracle[kind]).length}`).join(", ") + ` action registrations verified at ${head}`);
