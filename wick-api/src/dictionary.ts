//
//  dictionary.ts — "is this a real English word?" for the web single-player.
//
//  iOS scores on-device with Apple's NLEmbedding, which simply has no vector for a
//  non-word ("dokc", "loght") — so those guesses are rejected there. The web
//  scores via Gemini, which will embed ANY string and hand back a (cold) score, so
//  typos and keyboard mash used to count as guesses. This restores parity: the
//  /warmth endpoint checks the guess against a ~274k-word English list first.
//
//  Loaded once from the `word-list` package (dwyl's words.txt) via createRequire so
//  no type shim is needed. Fails OPEN: if the list can't be read, we never block a
//  guess — better to accept a typo than to reject real words.
//

import { readFileSync } from "node:fs";
import wordListPath from "word-list";

let words: Set<string> | null = null;

function load(): Set<string> {
  if (words) return words;
  try {
    words = new Set(readFileSync(wordListPath, "utf8").split("\n").filter((w) => w.length > 0));
  } catch {
    words = new Set(); // unavailable → fail open (see isRealWord)
  }
  return words;
}

/** True if `word` is a known English word — or if the dictionary is unavailable
 *  (fail open, so a missing asset never blocks play). Matching is lowercase; a
 *  guess with stray punctuation is retried on its letters-only form. */
export function isRealWord(word: string): boolean {
  const w = word.trim().toLowerCase();
  if (!w) return false;
  const set = load();
  if (set.size === 0) return true; // no dictionary loaded → don't block anything
  if (set.has(w)) return true;
  const lettersOnly = w.replace(/[^a-z]/g, "");
  return lettersOnly.length > 0 && set.has(lettersOnly);
}

/** Number of words loaded (0 if the list is unavailable) — for diagnostics. */
export function dictionarySize(): number {
  return load().size;
}
