// Converts docs/PRIVACY_POLICY.md into the section model that
// scripts/build_privacy_policy_docx.ps1 renders, so the .docx is always built
// from the same text as the Markdown and HTML versions.
//
//   node scripts/privacy_policy_sections.mjs <out.json>
//
// Model: [{kind:'h1'|'h2'|'h3'|'p', text}, {kind:'bullet', items}, {kind:'hr'},
// {kind:'table', header, rows}]. Inline markup: **bold**, _italic_.
// Underscores inside `code` are replaced by U+E000, which the builder turns
// back into "_" after it has parsed the italic markers.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = process.argv[2];
if (!out) throw new Error('usage: node scripts/privacy_policy_sections.mjs <out.json>');

const md = readFileSync(join(root, 'docs', 'PRIVACY_POLICY.md'), 'utf8').replace(/\r\n/g, '\n');
const UNDERSCORE = String.fromCharCode(0xE000);
const inline = (s) => s
  .replace(/`([^`]+)`/g, (_, c) => c.replace(/_/g, UNDERSCORE))
  .replace(/(^|[\s(])\*([^*]+)\*(?=[\s.,;:)]|$)/g, '$1_$2_');

const lines = md.split('\n');
const sections = [];
const isBlock = (l) => /^(#{1,3}\s|---+\s*$|\||\s*[-*]\s+|\d+\.\s)/.test(l);
const isItem = (l) => /^\s*[-*]\s+/.test(l) || /^\d+\.\s+/.test(l);
for (let i = 0; i < lines.length;) {
  const line = lines[i];
  if (!line.trim()) { i++; continue; }
  let m;
  if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
    sections.push({ kind: 'h' + m[1].length, text: inline(m[2]) });
    i++;
  } else if (/^---+\s*$/.test(line)) {
    sections.push({ kind: 'hr' });
    i++;
  } else if (line.startsWith('|')) {
    const rows = [];
    while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
    const cells = (r) => r.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => inline(c.trim()));
    const [head, , ...body] = rows;
    sections.push({ kind: 'table', header: cells(head), rows: body.map(cells) });
  } else if (isItem(line)) {
    const items = [];
    while (i < lines.length && isItem(lines[i])) {
      items.push(inline(lines[i++].replace(/^\s*[-*]\s+/, '').replace(/^\d+\.\s+/, '')));
    }
    sections.push({ kind: 'bullet', items });
  } else {
    while (i < lines.length && lines[i].trim() && !isBlock(lines[i])) {
      sections.push({ kind: 'p', text: inline(lines[i++]) });
    }
  }
}
writeFileSync(out, JSON.stringify(sections, null, 1), 'utf8');
console.log(`${sections.length} sections -> ${out}`);
