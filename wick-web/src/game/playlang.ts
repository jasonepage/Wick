//
//  playlang.ts: which language the round itself is played in.
//
//  The menu language (i18n.ts) and the PLAY language are different things. A
//  Spanish speaker can play in English with Spanish meanings on screen (the
//  learning mode), or play the round in Spanish: Spanish answer, Spanish
//  guesses scored against the Spanish word list, Wick answering in Spanish.
//
//  The server can score en/es/fr/it/de (wick-api/src/lang.ts). Chinese has
//  menus and meanings only, so a zh menu always plays in English.
//

import { getLang } from "../i18n.ts";

export type PlayLang = "en" | "es" | "fr" | "it" | "de";
const PLAYABLE: readonly PlayLang[] = ["es", "fr", "it", "de"];
const KEY = "wick.playNative";

/** Can the menu language also be a play language? */
export function canPlayNative(): boolean {
  return (PLAYABLE as readonly string[]).includes(getLang());
}

/** Has the player asked to play in their menu language (when it is playable)? */
export function playNative(): boolean {
  try { return localStorage.getItem(KEY) === "1"; } catch { return false; }
}

export function setPlayNative(on: boolean): void {
  try { localStorage.setItem(KEY, on ? "1" : "0"); } catch { /* ignore */ }
}

/** The language the next round is played in. */
export function playLang(): PlayLang {
  const l = getLang();
  return playNative() && (PLAYABLE as readonly string[]).includes(l) ? (l as PlayLang) : "en";
}
