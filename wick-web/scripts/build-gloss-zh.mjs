//
//  build-gloss-zh.mjs: builds public/gloss/zh.json, the short Chinese meaning
//  shown next to each guess (and the answer) when the web game is in Chinese.
//
//  Source: ECDICT (https://github.com/skywind3000/ECDICT, MIT license). Download
//  ecdict.csv from that repo and run:
//
//    node scripts/build-gloss-zh.mjs /path/to/ecdict.csv
//
//  Only the words the game can score are kept: the server's rank vocabulary
//  (wick-api/src/rankvocab.ts) plus the daily pool, so the file stays small and
//  is loaded only when the language is Chinese. No npm packages.
//

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const csvPath = process.argv[2];
if (!csvPath) { console.error("usage: node scripts/build-gloss-zh.mjs ecdict.csv"); process.exit(1); }

// The words we want: rank vocabulary + daily pool answers.
const rankSrc = readFileSync(join(here, "../../wick-api/src/rankvocab.ts"), "utf8");
const raw = rankSrc.match(/const RAW = `([\s\S]*?)`;/)?.[1] ?? "";
const want = new Set(raw.split(/\s+/).filter(Boolean).map((w) => w.toLowerCase()));
const pool = JSON.parse(readFileSync(join(here, "../src/game/dailyPool.json"), "utf8"));
for (const e of pool) want.add(e.en.toLowerCase());
console.log(`wanted words: ${want.size}`);

// Minimal CSV reader (handles quoted fields with embedded newlines and "" escapes).
function* rows(text) {
  let row = [], field = "", q = false, i = 0;
  while (i < text.length) {
    const c = text[i];
    if (q) {
      if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else q = false; }
      else field += c;
    } else if (c === '"') q = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n") { row.push(field); yield row; row = []; field = ""; }
    else if (c !== "\r") field += c;
    i++;
  }
  if (field.length || row.length) { row.push(field); yield row; }
}

// One short gloss from an ECDICT translation field. The field holds lines like
// "n. 海, 海洋, 海浪" separated by a literal backslash-n. Take the first real
// line, drop the part-of-speech tag, keep the first sense.
function shortGloss(tr) {
  if (!tr) return null;
  const lines = tr.split(/\\n|\n/).map((s) => s.trim()).filter(Boolean);
  for (const line0 of lines) {
    let line = line0;
    if (/^\[(网络|电影|名|地)\]/.test(line)) continue;        // network slang, proper names
    line = line.replace(/^\[[^\]]*\]\s*/, "");                  // "[法] 海洋" -> "海洋"
    line = line.replace(/^[a-z]+(\.[a-z]*)*\.?\s*/i, "");        // "n. ", "vt. ", "pron. "
    line = line.replace(/^\([^)]*\)\s*/, "");                    // leading parenthetical
    const first = line.split(/[,，;；]/)[0].trim();
    if (!first) continue;
    if (!/[㐀-鿿]/.test(first)) continue;                 // must contain Chinese
    if (first.includes("的过去式") || first.includes("复数")) continue;
    return first.length > 8 ? first.slice(0, 8) : first;
  }
  return null;
}

const text = readFileSync(csvPath, "utf8");
const out = {};
const lemmaOf = {};   // inflected form -> base word, from ECDICT's "exchange" column ("0:run")
let header = null;
for (const r of rows(text)) {
  if (!header) { header = r; continue; }
  const word = r[0];
  if (!word) continue;
  const lw = word.toLowerCase();
  if (!want.has(lw)) continue;
  const g = shortGloss(r[3]);
  // Prefer the lowercase entry; a capitalized one (London, April) fills a gap.
  if (g && (!out[lw] || lw === word)) out[lw] = g;
  const m = (r[10] ?? "").match(/(?:^|\/)0:([^\/]+)/);
  if (m) lemmaOf[lw] = m[1].toLowerCase();
}
// Second pass: an inflected form (was, students) borrows its base word's gloss.
const base = {};
const needBase = new Set(Object.values(lemmaOf));
for (const r of rows(text)) {
  const w = (r[0] ?? "").toLowerCase();
  if (needBase.has(w) && !base[w]) { const g = shortGloss(r[3]); if (g) base[w] = g; }
}
for (const w of want) if (!out[w] && lemmaOf[w] && base[lemmaOf[w]]) out[w] = base[lemmaOf[w]];
// A few forms of "to be" have no usable ECDICT line of their own.
const OVERRIDES = { was: "是(过去式)", are: "是" };
for (const [w, g] of Object.entries(OVERRIDES)) if (want.has(w) && !out[w]) out[w] = g;
const sorted = Object.fromEntries(Object.keys(out).sort().map((k) => [k, out[k]]));
const dest = join(here, "../public/gloss/zh.json");
writeFileSync(dest, JSON.stringify(sorted));
const missing = [...want].filter((w) => !out[w]);
console.log(`wrote ${Object.keys(sorted).length} entries to ${dest}; missing ${missing.length}: ${missing.slice(0, 40).join(" ")}`);
