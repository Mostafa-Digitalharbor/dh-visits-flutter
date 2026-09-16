// Format-preserving, concurrency-safe editor for lib/l10n/app_{en,ar}.arb.
//
//   node tool/arb_edit.mjs <spec.json>
//
// spec.json:
// {
//   "en": { "set": {key: value}, "remove": [key],
//           "add": [{ "key", "value", "meta"?, "after"? }] },
//   "ar": { ...same, without "meta" }
// }
//
// * `set` rewrites an existing message in place (its @meta is kept).
// * `add` inserts a new message after `after` (default: end of file). `meta`
//   is written as a one-line "@key" object, matching the files' style.
// * `remove` deletes a message and its @meta.
//
// Hand-edited ARBs group keys with blank lines and keep metadata on one line;
// a JSON round-trip would reformat the whole file, so edits are line-based.
// A lock directory serialises concurrent runs.
import { readFileSync, writeFileSync, mkdirSync, rmdirSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const files = { en: join(root, 'lib/l10n/app_en.arb'), ar: join(root, 'lib/l10n/app_ar.arb') };
const lockDir = join(root, '.dart_tool', 'arb_edit.lock');
const spec = JSON.parse(readFileSync(process.argv[2], 'utf8'));

const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
function lock() {
  for (let i = 0; i < 600; i++) {
    try { mkdirSync(lockDir); return; } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      // A lock older than a minute belongs to a crashed run.
      try { if (Date.now() - statSync(lockDir).mtimeMs > 60000) rmdirSync(lockDir); } catch {}
      sleep(100);
    }
  }
  throw new Error('could not acquire ARB lock');
}

const q = (s) => JSON.stringify(s);
const inlineMeta = (m) => JSON.stringify(m).replace(/":/g, '": ').replace(/,"/g, ', "').replace(/\{"/g, '{ "').replace(/\}/g, ' }').replace(/\{ \}/g, '{}');

function edit(file, ops, isTemplate) {
  const raw = readFileSync(file, 'utf8');
  const eol = raw.includes('\r\n') ? '\r\n' : '\n';
  const lines = raw.split(/\r?\n/);
  if (lines.at(-1) === '') lines.pop();
  const keyAt = (l) => /^  "([^"]+)":/.exec(l ?? '')?.[1];
  const span = (key) => {
    const i = lines.findIndex((l) => keyAt(l) === key);
    if (i < 0) return null;
    let j = i + 1;
    if (/\{\s*$/.test(lines[i])) { while (!/^  \},?\s*$/.test(lines[j])) j++; j++; }
    return [i, j];
  };
  const entrySpan = (key) => {
    const s = span(key);
    if (!s) return null;
    const m = span('@' + key);
    return m && m[0] === s[1] ? [s[0], m[1]] : s;
  };
  const lastEntryLine = () => { let p = lines.length - 1; while (!/^  \S/.test(lines[p])) p--; return p; };
  // Every entry ends on a "terminator" line — a one-line entry, or the `  }`
  // closing a multi-line @meta block. All but the last need a comma.
  const fixTrailingCommas = () => {
    const isTerminator = (l) =>
      (/^  "/.test(l) && !/{s*$/.test(l)) || /^  },?s*$/.test(l);
    const terms = [];
    lines.forEach((l, i) => { if (isTerminator(l)) terms.push(i); });
    terms.forEach((i, n) => {
      const bare = lines[i].replace(/,s*$/, '');
      lines[i] = n === terms.length - 1 ? bare : bare + ',';
    });
  };
  for (const [key, value] of Object.entries(ops.set ?? {})) {
    const s = span(key);
    if (!s) throw new Error(`${file}: set: no key ${key}`);
    lines[s[0]] = `  ${q(key)}: ${q(value)},`;
  }
  for (const key of ops.remove ?? []) {
    const s = entrySpan(key);
    if (!s) throw new Error(`${file}: remove: no key ${key}`);
    lines.splice(s[0], s[1] - s[0]);
  }
  for (const e of ops.add ?? []) {
    if (span(e.key)) throw new Error(`${file}: add: ${e.key} already exists`);
    const out = [`  ${q(e.key)}: ${q(e.value)},`];
    if (e.meta && isTemplate) out.push(`  ${q('@' + e.key)}: ${inlineMeta(e.meta)},`);
    let at;
    if (e.after) {
      const s = entrySpan(e.after);
      if (!s) throw new Error(`${file}: add: no anchor ${e.after}`);
      at = s[1];
    } else {
      at = lastEntryLine() + 1;
    }
    lines.splice(at, 0, ...out);
  }
  fixTrailingCommas();
  // Collapse blank-line runs left behind by removals.
  const text = lines.filter((l, i) => !(l.trim() === '' && (lines[i - 1] ?? '').trim() === '')).join(eol) + eol;
  const parsed = JSON.parse(text);
  writeFileSync(file, text);
  return Object.keys(parsed).filter((k) => !k.startsWith('@')).length;
}

lock();
try {
  for (const lang of ['en', 'ar']) {
    if (!spec[lang]) continue;
    const n = edit(files[lang], spec[lang], lang === 'en');
    console.log(`${lang}: ok (${n} messages)`);
  }
  const en = JSON.parse(readFileSync(files.en, 'utf8'));
  const ar = JSON.parse(readFileSync(files.ar, 'utf8'));
  const ek = Object.keys(en).filter((k) => !k.startsWith('@'));
  const ak = new Set(Object.keys(ar).filter((k) => !k.startsWith('@')));
  const missing = ek.filter((k) => !ak.has(k));
  if (missing.length) console.log(`WARNING: missing in ar: ${missing.join(', ')}`);
} finally {
  rmdirSync(lockDir);
}
