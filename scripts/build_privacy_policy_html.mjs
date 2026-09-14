// Builds docs/PRIVACY_POLICY.html from docs/PRIVACY_POLICY.md, for pasting into
// the website CMS (https://digitalharbor.com.sa/ar/visit-app). The markdown file
// stays the source of truth; re-run after every change to it:
//   node scripts/build_privacy_policy_html.mjs
// Handles the subset the policy uses: headings, paragraphs, bullet and numbered
// lists, tables, horizontal rules, bold, italic, inline code, links, e-mails.
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const md = readFileSync(new URL('docs/PRIVACY_POLICY.md', root), 'utf8').replace(/\r\n/g, '\n');

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const inline = (s) => esc(s)
  .replace(/`([^`]+)`/g, '<code>$1</code>')
  .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  .replace(/(^|[\s(])_([^_]+)_(?=[\s.,;:)]|$)/g, '$1<em>$2</em>')
  .replace(/(^|[\s(])\*([^*]+)\*(?=[\s.,;:)]|$)/g, '$1<em>$2</em>')
  .replace(/(^|[\s(>])(https:\/\/[^\s<]*[^\s<.,;:)])/g, '$1<a href="$2">$2</a>')
  .replace(/(^|[\s(>])([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/g, '$1<a href="mailto:$2">$2</a>');

const isBlockStart = (l) => /^(#{1,3}\s|---+\s*$|\||\s*[-*]\s+|\d+\.\s)/.test(l);
const lines = md.split('\n');
const out = [];
for (let i = 0; i < lines.length;) {
  const line = lines[i];
  if (!line.trim()) { i++; continue; }
  let m;
  if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
    const n = m[1].length;
    out.push(`<h${n}>${inline(m[2])}</h${n}>`);
    i++;
  } else if (/^---+\s*$/.test(line)) {
    out.push('<hr>');
    i++;
  } else if (line.startsWith('|')) {
    const rows = [];
    while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
    const cells = (r) => r.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
    const [head, , ...body] = rows;
    out.push('<table>');
    out.push(`  <thead><tr>${cells(head).map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead>`);
    out.push('  <tbody>');
    for (const r of body) out.push(`    <tr>${cells(r).map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`);
    out.push('  </tbody>', '</table>');
  } else if (/^\s*[-*]\s+/.test(line)) {
    out.push('<ul>');
    while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) out.push(`  <li>${inline(lines[i++].replace(/^\s*[-*]\s+/, ''))}</li>`);
    out.push('</ul>');
  } else if (/^\d+\.\s+/.test(line)) {
    out.push('<ol>');
    while (i < lines.length && /^\d+\.\s+/.test(lines[i])) out.push(`  <li>${inline(lines[i++].replace(/^\d+\.\s+/, ''))}</li>`);
    out.push('</ol>');
  } else {
    const para = [];
    while (i < lines.length && lines[i].trim() && !isBlockStart(lines[i])) para.push(inline(lines[i++]));
    out.push(`<p>${para.join('<br>\n')}</p>`);
  }
}

const html = `<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy Policy — Customer Visits</title>
<!-- GENERATED from docs/PRIVACY_POLICY.md by scripts/build_privacy_policy_html.mjs.
     Do not edit by hand. For the CMS, paste the <article> element (styles optional). -->
<style>
  .privacy-policy { max-width: 820px; margin: 0 auto; padding: 24px 16px; font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif; color: #1d1d1f; }
  .privacy-policy h1 { font-size: 1.9em; margin: 0 0 .4em; }
  .privacy-policy h2 { font-size: 1.35em; margin: 1.6em 0 .5em; }
  .privacy-policy h3 { font-size: 1.1em; margin: 1.3em 0 .4em; }
  .privacy-policy table { border-collapse: collapse; width: 100%; margin: 1em 0; display: block; overflow-x: auto; }
  .privacy-policy th, .privacy-policy td { border: 1px solid #d2d2d7; padding: 8px 10px; text-align: left; vertical-align: top; }
  .privacy-policy th { background: #f5f5f7; }
  .privacy-policy code { background: #f5f5f7; padding: 0 4px; border-radius: 4px; font-size: .92em; }
  .privacy-policy hr { border: 0; border-top: 1px solid #d2d2d7; margin: 2em 0; }
</style>
</head>
<body>
<article class="privacy-policy">
${out.join('\n')}
</article>
</body>
</html>
`;
writeFileSync(new URL('docs/PRIVACY_POLICY.html', root), html);
console.log(`wrote docs/PRIVACY_POLICY.html (${html.length} bytes, ${out.length} blocks)`);
