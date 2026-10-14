//
//  words.ts: the multiplayer match word pool.
//
//  IMPORTANT (C1 moat): these are words the SERVER may hold for live-match
//  adjudication. They are NOT the single-player daily words. This is a small,
//  self-contained pool the matchmaker draws a secret from per match. It is
//  intentionally a placeholder: before launch, align this pool with the app's
//  curated multiplayer word set (and, if the app resolves the board from a word
//  *index*, agree an index-to-word contract). Flagged: the exact pool source is a
//  handoff item, not fixed by the SRS.
//
//  Every entry carries the same concept in all five languages, so two players
//  who speak different languages can race for the same word: one hunts "ember",
//  the other "brasa". The English form is the canonical id of the entry.
//

import type { Lang } from "./lang.js";

export type MatchWord = Record<Lang, string>;

const W = (en: string, es: string, fr: string, it: string, de: string): MatchWord => ({ en, es, fr, it, de });

/** Placeholder multiplayer word pool. Replace/extend before launch. */
export const MATCH_WORDS: readonly MatchWord[] = [
  W("ember", "brasa", "braise", "brace", "glut"),
  W("flame", "llama", "flamme", "fiamma", "flamme"),
  W("spark", "chispa", "étincelle", "scintilla", "funke"),
  W("cinder", "ceniza", "cendre", "cenere", "asche"),
  W("kindle", "encender", "allumer", "accendere", "entzünden"),
  W("hearth", "hogar", "foyer", "focolare", "herd"),
  W("beacon", "faro", "balise", "faro", "leuchtfeuer"),
  W("lantern", "farol", "lanterne", "lanterna", "laterne"),
  W("candle", "vela", "bougie", "candela", "kerze"),
  W("torch", "antorcha", "torche", "torcia", "fackel"),
  W("glow", "resplandor", "lueur", "bagliore", "schein"),
  W("smoke", "humo", "fumée", "fumo", "rauch"),
  W("ash", "ceniza", "cendre", "cenere", "asche"),
  W("coal", "carbón", "charbon", "carbone", "kohle"),
  W("blaze", "incendio", "brasier", "incendio", "feuersbrunst"),
  W("flicker", "parpadeo", "vacillement", "tremolio", "flackern"),
  W("warmth", "calor", "chaleur", "calore", "wärme"),
  W("signal", "señal", "signal", "segnale", "signal"),
  W("compass", "brújula", "boussole", "bussola", "kompass"),
  W("anchor", "ancla", "ancre", "ancora", "anker"),
  W("harbor", "puerto", "port", "porto", "hafen"),
  W("meadow", "prado", "prairie", "prato", "wiese"),
  W("river", "río", "rivière", "fiume", "fluss"),
  W("summit", "cumbre", "sommet", "vetta", "gipfel"),
  W("orchard", "huerto", "verger", "frutteto", "obstgarten"),
  W("cabin", "cabaña", "cabane", "capanna", "hütte"),
  W("bridge", "puente", "pont", "ponte", "brücke"),
  W("garden", "jardín", "jardin", "giardino", "garten"),
  W("market", "mercado", "marché", "mercato", "markt"),
  W("harvest", "cosecha", "récolte", "raccolto", "ernte"),
  W("willow", "sauce", "saule", "salice", "weide"),
  W("cedar", "cedro", "cèdre", "cedro", "zeder"),
];

/** A provider may return a bare English word (older callers and tests) or a
 *  full entry. This widens either into the five-language form; a bare word is
 *  the same in every language, which keeps every existing test meaningful. */
export function toMatchWord(w: string | MatchWord): MatchWord {
  if (typeof w !== "string") return w;
  return { en: w, es: w, fr: w, it: w, de: w };
}

/**
 * Deterministic-friendly word provider. Pass an `index()` that returns a
 * non-negative integer to pick from the pool (the server injects a random one;
 * tests inject a counter). Defaults to a simple rotating counter.
 */
export function makeWordProvider(index?: () => number): () => MatchWord {
  let i = 0;
  const pick = index ?? (() => i++);
  return () => {
    const n = Math.abs(Math.trunc(pick())) % MATCH_WORDS.length;
    return MATCH_WORDS[n]!;
  };
}
