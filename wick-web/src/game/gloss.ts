//
//  gloss.ts: short meanings for a player who is learning English.
//
//  The game is always played in English (sp.secret is the English word and the
//  Keeper answers in English). When the menus are in another language, the
//  player's OWN screen can show what each English word means: a guess row reads
//  "sea · 海 · Hot" and the solved screen reads "ocean · 海洋".
//
//  Two sources:
//    1. The daily pool already carries every answer in es/fr/it/de/zh, so the
//       ANSWER's meaning works for every non-English language with no download.
//    2. A per-language dictionary of the words the game can score (the server's
//       rank vocabulary), built offline by scripts/build-gloss-<lang>.mjs and
//       fetched only when that language is chosen, so players in other
//       languages download nothing. Today only zh has one (ECDICT, MIT; see THIRD_PARTY_NOTICES.md).
//
//  Spoiler rule: nothing here may reach share text, the share card or the
//  replay video. Only the player's own screen shows meanings.
//

import type { Lang } from "../i18n.ts";
import type { DailyWord } from "./daily.ts";

type Table = Record<string, string>;

// Plain JSON under public/ (fetched, not bundled): a bundled chunk escaped every
// character to \uXXXX and doubled the download. Resolved against the page's base
// so it works under a subpath (GitHub Pages).
const FILES: Partial<Record<Lang, string>> = { zh: "gloss/zh.json" };
const LOADERS: Partial<Record<Lang, () => Promise<Table>>> = {
  zh: () => fetch(new URL(FILES.zh!, document.baseURI).href).then((r) => {
    if (!r.ok) throw new Error(String(r.status));
    return r.json() as Promise<Table>;
  }),
};
const tables: Partial<Record<Lang, Table>> = {};
const pending: Partial<Record<Lang, Promise<boolean>>> = {};

/** True when this language can show per-guess meanings at all. */
export function hasGuessGloss(lang: Lang): boolean {
  return lang in LOADERS;
}

/** Load the dictionary for a language. Resolves true the first time it becomes
 *  ready (so the caller can re-render), false if nothing new was loaded. */
export function loadGloss(lang: Lang): Promise<boolean> {
  const loader = LOADERS[lang];
  if (!loader || tables[lang]) return Promise.resolve(false);
  const p = pending[lang];
  if (p) return p;
  const run = loader()
    .then((table) => { tables[lang] = table; return true; })
    .catch(() => false)
    .finally(() => { delete pending[lang]; });
  pending[lang] = run;
  return run;
}

/** Meaning of a guessed English word in the given language, or null when there
 *  is none (English, dictionary not loaded yet, or the word is not in it). */
export function guessGloss(word: string, lang: Lang): string | null {
  const table = tables[lang];
  if (!table) return null;
  return table[word.trim().toLowerCase()] ?? null;
}

/** Meaning of the round's answer, straight from the daily pool. */
export function answerGloss(word: DailyWord | null, lang: Lang): string | null {
  if (!word || lang === "en") return null;
  const m = word[lang];
  return m && m !== word.en ? m : null;
}

/** "ocean · 海洋", or just the word when there is no meaning to add. */
export function withGloss(word: string, meaning: string | null): string {
  return meaning ? `${word} · ${meaning}` : word;
}
