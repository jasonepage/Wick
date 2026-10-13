//
//  zh.test.ts: Simplified Chinese on the web.
//
//  The zh UI table must cover every English key, and every daily-pool entry must
//  carry a Chinese meaning while the pool itself stays exactly as it was: 359
//  entries, same order. The daily word is picked by index from a fixed shuffle,
//  so adding, removing or reordering an entry would change every day's puzzle
//  and break parity with iOS.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { TABLES, LANGS, LANG_LABEL } from "../src/i18n.ts";

const pool = JSON.parse(readFileSync(new URL("../src/game/dailyPool.json", import.meta.url), "utf8")) as Array<Record<string, unknown>>;
const zhGloss = JSON.parse(readFileSync(new URL("../public/gloss/zh.json", import.meta.url), "utf8")) as Record<string, string>;
const hasChinese = (s: string) => /[㐀-鿿]/.test(s);

test("zh is a listed language", () => {
  assert.ok(LANGS.includes("zh"));
  assert.equal(LANG_LABEL.zh, "中文");
});

test("zh table has every en key and the same placeholders", () => {
  const en = TABLES.en, zh = TABLES.zh;
  const missing = Object.keys(en).filter((k) => !(k in zh) || zh[k]!.length === 0);
  assert.deepEqual(missing, []);
  const extra = Object.keys(zh).filter((k) => !(k in en));
  assert.deepEqual(extra, []);
  for (const k of Object.keys(en)) {
    const ph = (s: string) => (s.match(/%@|%d/g) ?? []).sort();
    assert.deepEqual(ph(zh[k]!), ph(en[k]!), `placeholders differ for ${k}`);
  }
});

test("zh strings have no em dashes", () => {
  for (const [k, v] of Object.entries(TABLES.zh)) assert.ok(!v.includes("\u2014"), `em dash in ${k}`);
});

test("daily pool is unchanged apart from the zh field", () => {
  assert.equal(pool.length, 359);
  assert.equal(pool[0]!.en, "ocean");
  assert.equal(pool[pool.length - 1]!.en, "elbow");
  for (const e of pool) {
    assert.equal(typeof e.zh, "string", `no zh for ${e.en}`);
    assert.ok((e.zh as string).length > 0 && hasChinese(e.zh as string), `bad zh for ${e.en}: ${e.zh}`);
    for (const k of ["en", "es", "fr", "it", "de"]) assert.equal(typeof e[k], "string", `${e.en} lost ${k}`);
    assert.equal(typeof e.tier, "number");
  }
});

test("zh guess dictionary covers every daily answer", () => {
  for (const e of pool) assert.ok(hasChinese(zhGloss[e.en as string] ?? ""), `no gloss for ${e.en}`);
  for (const v of Object.values(zhGloss)) assert.ok(v.length > 0 && v.length <= 8);
});
