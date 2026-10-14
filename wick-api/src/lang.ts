//
//  lang.ts: the languages the server can score a round in.
//
//  Each has its own ~10k frequency-ranked reference vocabulary (ported from the
//  iOS app, so a rank number means the same thing on both platforms). Gemini's
//  embedding model is multilingual, so a Spanish guess and a Spanish secret
//  embed in the same space as English ones; what changes per language is only
//  the reference list the guess is ranked against, and the "is this a real
//  word" gate (dictionary.ts).
//
//  English stays the default everywhere: every caller that does not say
//  otherwise gets "en", so existing clients keep working unchanged.
//

import { RANK_VOCAB } from "./rankvocab.js";
import { RANK_VOCAB_ES } from "./rankvocab/es.js";
import { RANK_VOCAB_FR } from "./rankvocab/fr.js";
import { RANK_VOCAB_IT } from "./rankvocab/it.js";
import { RANK_VOCAB_DE } from "./rankvocab/de.js";

export type Lang = "en" | "es" | "fr" | "it" | "de";
export const LANGS: readonly Lang[] = ["en", "es", "fr", "it", "de"] as const;

export function isLang(x: unknown): x is Lang {
  return typeof x === "string" && (LANGS as readonly string[]).includes(x);
}

/** A request's `lang` field, defaulting to English. Unknown values fall back
 *  to English rather than erroring, so an older or odd client still plays. */
export function langOf(x: unknown): Lang {
  return isLang(x) ? x : "en";
}

const VOCAB: Record<Lang, string[]> = {
  en: RANK_VOCAB,
  es: RANK_VOCAB_ES,
  fr: RANK_VOCAB_FR,
  it: RANK_VOCAB_IT,
  de: RANK_VOCAB_DE,
};

/** The reference vocabulary for a language, in rank order. */
export function rankVocabFor(lang: Lang): string[] {
  return VOCAB[lang];
}
