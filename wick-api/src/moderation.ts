//
//  moderation.ts — a small content filter for the only user-generated content in
//  Wick: the word a Dare setter picks (the guesser sees it at the reveal) and the
//  words the guesser types (the setter spectates them live). Race never exposes a
//  player's words to the opponent, and single-player never leaves the device, so
//  this is deliberately scoped to the Dare exposure paths (App Review 1.2).
//
//  Two tiers, on purpose:
//    • SLURS — hateful terms with no legitimate game use. Blocked BOTH as a set
//      secret AND as a guess (a guesser can't use them to harass the setter).
//    • VULGAR — crude/sexual words that CAN be legitimate guesses ("cock" for a
//      rooster, "bitch" for a female dog). Blocked only as a deliberately-chosen
//      secret; still allowed as an organic guess so real gameplay isn't punished.
//
//  Matching is exact on a normalized single token (both secrets and guesses are
//  single words), which sidesteps the "Scunthorpe problem" — "class", "cockpit",
//  and "assassin" never trip a substring. Normalization folds common leet, strips
//  separators/punctuation, and collapses 3+ repeated letters so light obfuscation
//  ("f4ggot", "n i g g e r", "fuuuck") still resolves to the base term.
//
//  This is a starter list, not an exhaustive one — extend the sets as needed.
//

const LEET: Record<string, string> = {
  "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i",
};

/** Fold to a comparable token: lowercase, de-leet, strip non-letters, collapse
 *  runs of 3+ identical letters (real words don't have them). */
export function normalizeForModeration(word: string): string {
  return word
    .toLowerCase()
    .replace(/[013457@$!]/g, (c) => LEET[c] ?? "")
    .replace(/[^a-z]/g, "")
    .replace(/(.)\1{2,}/g, "$1");
}

// Hateful slurs — never a legitimate guess or secret.
const SLURS = new Set(
  [
    "nigger", "nigga", "niggers", "niggas", "faggot", "fag", "faggots", "fags",
    "chink", "chinks", "gook", "gooks", "spic", "spics", "wetback", "wetbacks",
    "kike", "kikes", "coon", "coons", "wop", "wops", "beaner", "beaners",
    "raghead", "ragheads", "sandnigger", "porchmonkey", "jigaboo", "darkie", "darky",
    "tranny", "trannies", "shemale", "shemales", "dyke", "dykes",
    "retard", "retards", "retarded",
  ].map(normalizeForModeration),
);

// Crude/sexual profanity — blocked as a chosen secret, allowed as a guess.
const VULGAR = new Set(
  [
    "fuck", "fucker", "fuckers", "fucking", "motherfucker", "motherfuckers",
    "shit", "shits", "shitty", "cunt", "cunts", "bitch", "bitches", "bastard",
    "asshole", "assholes", "dick", "dicks", "cock", "cocks", "pussy", "pussies",
    "prick", "pricks", "twat", "twats", "wank", "wanker", "wankers",
    "slut", "sluts", "whore", "whores", "cum", "jizz", "boner", "dildo",
    "blowjob", "handjob", "tits", "titties", "boobs",
  ].map(normalizeForModeration),
);

/** A slur — objectionable anywhere it could be shown to another player. */
export function isSlur(word: string): boolean {
  return SLURS.has(normalizeForModeration(word));
}

/** Block a Dare setter's chosen secret: slurs OR crude/sexual words (a
 *  deliberately-set vulgar word gets shown to the guesser at the reveal). */
export function isBlockedSecret(word: string): boolean {
  const n = normalizeForModeration(word);
  return SLURS.has(n) || VULGAR.has(n);
}

/** Block a live guess (the setter spectates it): slurs only, so genuine guesses
 *  like "cock" (rooster) or "bitch" (female dog) still count. */
export function isBlockedGuess(word: string): boolean {
  return SLURS.has(normalizeForModeration(word));
}
