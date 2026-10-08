//
//  preview.ts — decode a shared challenge/match code → non-revealing OG preview
//               (SRS FR-5, FR-30/OD-7, C5). Runs on the free tier.
//
//  This is a faithful TypeScript port of the app's `DuelCode.swift` bit-unpacker,
//  used ONLY to recognize a code and describe it generically ("you've been
//  challenged"). It decodes the mode/language and, for result codes, the finished
//  score — but it can NEVER reveal the secret word: the code carries only an
//  obfuscated *index* into the app's on-device word bank, and this server holds no
//  word bank at all. So even a fully-decoded code yields no word here (FR-5, C1).
//
//  Legacy safety (C5, FR-30/OD-7): old `WK-`/`WR-` links already shared must keep
//  resolving to a friendly page, never a 404. Unknown/garbled codes fall back to a
//  generic card rather than erroring.
//
//  Keep in lockstep with `Hunch/Engine/DuelCode.swift` and `debug/duel_tracer.py`.
//  Uses BigInt throughout — the salt and packed payloads exceed 32 bits.
//

const SALT = 0x5f3a9c2e17b4d6a1n;

const KIND_DUEL = 0n;
const KIND_RESULT = 1n;

// Field widths (bits) — must match DuelCode.swift exactly.
const VERSION_BITS = 4n;
const KIND_BITS = 2n;
const MODE_BITS = 2n;
const LANG_BITS = 4n;
const WORD_BITS = 18n;
const SOLVED_BITS = 1n;
const GAVEUP_BITS = 1n;
const GUESS_BITS = 12n;
const CHECK_BITS = 8n;

const DUEL_TOTAL_BITS = 38n; // 4+2+2+4+18 + 8
const RESULT_TOTAL_BITS = 50n; // 4+2+4+18+1+1+12 + 8

const SCHEMA_VERSION = 1n;

const DUEL_PREFIX = "WK-";
const RESULT_PREFIX = "WR-";

/** Explicit language order (NOT enum order) — must never shift. */
const LANGUAGE_ORDER = ["english", "spanish", "french", "italian", "german"] as const;
export type DuelLanguage = (typeof LANGUAGE_ORDER)[number];

export type DuelMode = "dare" | "race";

export interface DuelPayload {
  kind: "duel";
  mode: DuelMode;
  language: DuelLanguage;
  /** Obfuscated bank index — NOT a word; not resolvable server-side. */
  wordIndex: number;
}

export interface DuelResultPayload {
  kind: "result";
  language: DuelLanguage;
  wordIndex: number;
  solved: boolean;
  gaveUp: boolean;
  guessCount: number;
}

export type DecodedCode = DuelPayload | DuelResultPayload;

const ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const ALPHABET_INDEX: Map<string, bigint> = new Map(
  [...ALPHABET].map((c, i) => [c, BigInt(i)]),
);

function mask(bits: bigint): bigint {
  return (1n << bits) - 1n;
}

/** Sum of the 8 low bytes, mod 256 — matches Swick's light typo checksum. */
function checksum(payload: bigint): bigint {
  let h = 0n;
  let x = payload;
  for (let i = 0; i < 8; i++) {
    h = (h + (x & 0xffn)) & 0xffn;
    x >>= 8n;
  }
  return h & 0xffn;
}

function base62Decode(s: string): bigint | null {
  if (s.length === 0) return null;
  let v = 0n;
  for (const c of s) {
    const d = ALPHABET_INDEX.get(c);
    if (d === undefined) return null;
    v = v * 62n + d;
  }
  return v;
}

function unpack(code: string, prefix: string, totalBits: bigint): bigint | null {
  let t = code.trim();
  if (t.toUpperCase().startsWith(prefix)) t = t.slice(prefix.length);
  const obf = base62Decode(t);
  if (obf === null) return null;
  const full = obf ^ (SALT & mask(totalBits));
  const cs = full & mask(CHECK_BITS);
  const payload = full >> CHECK_BITS;
  if (checksum(payload) !== cs) return null;
  return payload;
}

function languageAt(index: bigint): DuelLanguage | null {
  const i = Number(index);
  return i >= 0 && i < LANGUAGE_ORDER.length ? LANGUAGE_ORDER[i]! : null;
}

export function decodeDuel(code: string): DuelPayload | null {
  const v = unpack(code, DUEL_PREFIX, DUEL_TOTAL_BITS);
  if (v === null) return null;
  let x = v;
  const wordIndex = x & mask(WORD_BITS);
  x >>= WORD_BITS;
  const lang = x & mask(LANG_BITS);
  x >>= LANG_BITS;
  const mode = x & mask(MODE_BITS);
  x >>= MODE_BITS;
  const kind = x & mask(KIND_BITS);
  x >>= KIND_BITS;
  const version = x & mask(VERSION_BITS);
  const language = languageAt(lang);
  if (version !== SCHEMA_VERSION || kind !== KIND_DUEL || language === null) return null;
  if (mode !== 0n && mode !== 1n) return null;
  return {
    kind: "duel",
    mode: mode === 1n ? "race" : "dare",
    language,
    wordIndex: Number(wordIndex),
  };
}

export function decodeResult(code: string): DuelResultPayload | null {
  const v = unpack(code, RESULT_PREFIX, RESULT_TOTAL_BITS);
  if (v === null) return null;
  let x = v;
  const guesses = x & mask(GUESS_BITS);
  x >>= GUESS_BITS;
  const gaveUp = x & mask(GAVEUP_BITS);
  x >>= GAVEUP_BITS;
  const solved = x & mask(SOLVED_BITS);
  x >>= SOLVED_BITS;
  const wordIndex = x & mask(WORD_BITS);
  x >>= WORD_BITS;
  const lang = x & mask(LANG_BITS);
  x >>= LANG_BITS;
  const kind = x & mask(KIND_BITS);
  x >>= KIND_BITS;
  const version = x & mask(VERSION_BITS);
  const language = languageAt(lang);
  if (version !== SCHEMA_VERSION || kind !== KIND_RESULT || language === null) return null;
  return {
    kind: "result",
    language,
    wordIndex: Number(wordIndex),
    solved: solved === 1n,
    gaveUp: gaveUp === 1n,
    guessCount: Number(guesses),
  };
}

/** Recognize either kind, or null if it isn't one of ours. */
export function decodeAny(code: string): DecodedCode | null {
  const t = code.trim().toUpperCase();
  if (t.startsWith(DUEL_PREFIX)) return decodeDuel(code);
  if (t.startsWith(RESULT_PREFIX)) return decodeResult(code);
  return null;
}

// ── OG preview rendering ──────────────────────────────────────────────────────

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

interface PreviewCopy {
  title: string;
  description: string;
}

/** Build the non-revealing card copy for a code. Never contains a word. */
export function previewCopyFor(code: string): PreviewCopy {
  const decoded = decodeAny(code);
  if (!decoded) {
    // Legacy/garbled — friendly generic card, never a 404 (FR-30/OD-7).
    return {
      title: "You've been challenged in Wick",
      description: "Open the challenge in Wick — the calm hot-and-cold word game.",
    };
  }
  if (decoded.kind === "duel") {
    // Old async "race" links must still land gracefully (FR-30/OD-7). We don't
    // announce a mode split to the sharer; a warm generic invite is enough and
    // stays honest (we can't verify anything word-side here).
    return {
      title: "You've been challenged in Wick",
      description: "A friend dared you to a word. Tap to open it in Wick and race to warm up first.",
    };
  }
  // Result share card — outcome only, still no word.
  const outcome = decoded.solved
    ? `Solved in ${decoded.guessCount} ${decoded.guessCount === 1 ? "guess" : "guesses"}`
    : decoded.gaveUp
      ? "Gave up on this one"
      : "Gave it a shot";
  return {
    title: `Beat this Wick score — ${outcome}`,
    description: "Think you can do better? Open the challenge in Wick and try the same word.",
  };
}

/**
 * Full OG-tagged HTML for `GET /d/:code`. `appLink` is the universal link that
 * opens the app (kept on GitHub Pages per C5); `imageUrl` is optional.
 */
export function renderPreviewHtml(args: {
  code: string;
  appLink: string;
  imageUrl?: string;
}): string {
  const { title, description } = previewCopyFor(args.code);
  const t = escapeHtml(title);
  const d = escapeHtml(description);
  const link = escapeHtml(args.appLink);
  const img = args.imageUrl ? escapeHtml(args.imageUrl) : "";
  const ogImage = img ? `\n  <meta property="og:image" content="${img}" />` : "";
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${t}</title>
  <meta name="description" content="${d}" />
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${t}" />
  <meta property="og:description" content="${d}" />
  <meta property="og:url" content="${link}" />${ogImage}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${t}" />
  <meta name="twitter:description" content="${d}" />
</head>
<body style="font-family:-apple-system,system-ui,sans-serif;background:#1c1712;color:#f5ede2;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:24px;text-align:center;">
  <main>
    <h1 style="font-size:1.5rem;margin:0 0 .5rem;">${t}</h1>
    <p style="opacity:.85;margin:0 0 1.5rem;">${d}</p>
    <a href="${link}" style="display:inline-block;background:#ff8a3d;color:#1c1712;font-weight:600;text-decoration:none;padding:.75rem 1.5rem;border-radius:999px;">Open in Wick</a>
  </main>
</body>
</html>`;
}

// ── 3.1 live-invite links (/p/:code) ──────────────────────────────────────────
//
//  A LIVE invite (Race or Dare) is different from the legacy async /d/:code share:
//  the code is a live rendezvous, not a packed puzzle. The Dare word is NEVER in the
//  link — only the rendezvous code is — so this page can't leak it either. The page
//  carries mode-aware OG tags for chat unfurls, and for a real browser with NO app it
//  redirects into the web client so anyone with the link can play (the "can my dad on
//  Android play?" path). When the app IS installed, iOS opens it via the Universal
//  Link and this page never loads.

export type InviteMode = "race" | "dare";

/** Non-revealing, mode-aware copy for a live invite. Never contains a word. */
export function inviteCopyFor(mode: InviteMode | undefined): PreviewCopy {
  if (mode === "dare") {
    return {
      title: "You've been dared in Wick",
      description: "A friend picked a secret word and dared you to guess it live. Tap to play.",
    };
  }
  if (mode === "race") {
    return {
      title: "Race me in Wick",
      description: "A friend wants to race you to a hidden word — first to warm up wins. Tap to play.",
    };
  }
  return {
    title: "You've been challenged in Wick",
    description: "A friend wants to play Wick with you — the calm hot-and-cold word game. Tap to play.",
  };
}

/**
 * Full HTML for `GET /p/:code?m=race|dare`. `playLink` is where a browser should land
 * to actually play (the web client, carrying the code); `appLink` is the canonical
 * invite URL (og:url + manual "Play" link). Redirects real browsers into the web
 * client; link-preview crawlers just read the OG tags.
 */
export function renderInviteHtml(args: {
  code: string;
  mode?: InviteMode;
  playLink: string;
  appLink: string;
  imageUrl?: string;
}): string {
  const { title, description } = inviteCopyFor(args.mode);
  const t = escapeHtml(title);
  const d = escapeHtml(description);
  const play = escapeHtml(args.playLink);
  const link = escapeHtml(args.appLink);
  const img = args.imageUrl ? escapeHtml(args.imageUrl) : "";
  const ogImage = img ? `\n  <meta property="og:image" content="${img}" />` : "";
  // JSON.stringify makes a safe JS string literal; guard the only sequence that could
  // break out of the <script> element.
  const playJs = JSON.stringify(args.playLink).replace(/</g, "\\u003c");
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${t}</title>
  <meta name="description" content="${d}" />
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${t}" />
  <meta property="og:description" content="${d}" />
  <meta property="og:url" content="${link}" />${ogImage}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${t}" />
  <meta name="twitter:description" content="${d}" />
  <meta http-equiv="refresh" content="0; url=${play}" />
  <script>location.replace(${playJs});</script>
</head>
<body style="font-family:-apple-system,system-ui,sans-serif;background:#1c1712;color:#f5ede2;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:24px;text-align:center;">
  <main>
    <h1 style="font-size:1.5rem;margin:0 0 .5rem;">${t}</h1>
    <p style="opacity:.85;margin:0 0 1.5rem;">${d}</p>
    <a href="${play}" style="display:inline-block;background:#ff8a3d;color:#1c1712;font-weight:600;text-decoration:none;padding:.75rem 1.5rem;border-radius:999px;">Play in Wick</a>
  </main>
</body>
</html>`;
}
