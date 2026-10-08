#!/usr/bin/env node
//
//  loadtest.mjs — find where wick-api's knee actually is, instead of guessing.
//
//  Zero dependencies; needs Node 18+ for built-in fetch. Run from the repo root:
//
//    node debug/loadtest.mjs --stage warmth --peak 200
//    node debug/loadtest.mjs --stage static --peak 400
//    node debug/loadtest.mjs --stage mixed  --peak 150 --hold 20
//
//  ── READ THIS BEFORE POINTING IT ANYWHERE ─────────────────────────────────
//
//  Default target is http://localhost:8080, i.e. `npm run dev` in wick-api.
//  Aiming this at guesswick.com requires --yes-really, and you almost certainly
//  should not: every request from one machine shares one source IP, so the
//  per-IP token bucket (burst 40, ~1 rps) starts returning 429 within seconds
//  and you end up measuring the rate limiter rather than the server.
//
//  Locally the script sidesteps that by sending a distinct X-Forwarded-For per
//  virtual user, which is exactly how the server would see N real clients
//  behind Render's proxy. That is a TEST affordance and works only because the
//  local server trusts the header — do not try it against production.
//
//  ── WHAT IT MEASURES ──────────────────────────────────────────────────────
//
//  Concurrency ramps in steps up to --peak, holding each step for --hold
//  seconds. For each step you get RPS, p50/p95/p99 latency, and a status
//  breakdown, so the knee shows up as the step where p99 detaches from p50.
//
//  Guesses are drawn Zipf-ishly from the real daily pool: a small hot set
//  repeated constantly plus a long tail. That is the shape a crowd actually
//  produces, and it is what makes the embedding LRU look the way it will look
//  on the day. A uniform-random word list would badly overstate Gemini cost.
//
//  /healthz is sampled before and after, so the cache hit rate climbing across
//  the run is visible in the summary.
//

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, "..");

// ── args ────────────────────────────────────────────────────────────────────

function arg(name, dflt) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return dflt;
  const v = process.argv[i + 1];
  return v === undefined || v.startsWith("--") ? true : v;
}

const URL_BASE = String(arg("url", "http://localhost:8080")).replace(/\/$/, "");
const STAGE = String(arg("stage", "warmth"));
const PEAK = Number(arg("peak", 100));
const STEP = Number(arg("step", 0)) || Math.max(1, Math.round(PEAK / 5));
const HOLD = Number(arg("hold", 10));
const IS_PROD = /guesswick\.com|onrender\.com/.test(URL_BASE);

if (IS_PROD && arg("yes-really", false) !== true) {
  console.error(
    `\nRefusing to load-test ${URL_BASE}.\n\n` +
      `From one machine every request shares one IP, so the per-IP limiter\n` +
      `(burst 40, ~1 rps) will 429 you within seconds and the numbers will be\n` +
      `meaningless. Run it against a local server, or a throwaway Render service\n` +
      `with WICK_HTTP_RPS raised.\n\n` +
      `If you understand that and still want to: --yes-really\n`,
  );
  process.exit(2);
}
// Spoofing the client IP only makes sense locally; against a real proxy the
// header is overwritten anyway.
const SPOOF = !IS_PROD;

// ── the word pool ───────────────────────────────────────────────────────────

/** The daily pool, so guesses are words the game would actually see. */
function loadWords() {
  const candidates = [
    resolve(REPO, "wick-web/src/game/dailyPool.json"),
    resolve(HERE, "../wick-web/src/game/dailyPool.json"),
  ];
  for (const p of candidates) {
    try {
      const raw = JSON.parse(readFileSync(p, "utf8"));
      const words = raw.map((w) => (typeof w === "string" ? w : w.en)).filter(Boolean);
      if (words.length) return words;
    } catch { /* try the next path */ }
  }
  console.warn("! dailyPool.json not found — falling back to a tiny built-in list");
  return ["ocean", "river", "mountain", "forest", "island", "fire", "storm", "cloud"];
}

const WORDS = loadWords();
const SECRET = String(arg("secret", WORDS[0]));

/** Zipf-ish pick: heavily weighted to the first ~25 words, long tail beyond.
 *  Deterministic-ish shape, random draw — a crowd guessing the obvious things
 *  over and over, with the occasional oddball. */
function guess() {
  const r = Math.random();
  if (r < 0.6) return WORDS[Math.floor(Math.random() * Math.min(25, WORDS.length))];
  if (r < 0.9) return WORDS[Math.floor(Math.random() * Math.min(200, WORDS.length))];
  return WORDS[Math.floor(Math.random() * WORDS.length)];
}

// ── one request ─────────────────────────────────────────────────────────────

async function hitWarmth(vu) {
  const headers = { "content-type": "application/json" };
  if (SPOOF) headers["x-forwarded-for"] = `10.${(vu >> 16) & 255}.${(vu >> 8) & 255}.${vu & 255}`;
  return fetch(`${URL_BASE}/warmth`, {
    method: "POST",
    headers,
    body: JSON.stringify({ secret: SECRET, guess: guess() }),
  });
}

async function hitStatic(vu) {
  const headers = {};
  if (SPOOF) headers["x-forwarded-for"] = `10.${(vu >> 16) & 255}.${(vu >> 8) & 255}.${vu & 255}`;
  return fetch(`${URL_BASE}/`, { headers });
}

const REQ = {
  warmth: hitWarmth,
  static: hitStatic,
  mixed: (vu) => (Math.random() < 0.25 ? hitStatic(vu) : hitWarmth(vu)),
}[STAGE];

if (!REQ) {
  console.error(`Unknown --stage "${STAGE}". Use: warmth | static | mixed`);
  process.exit(2);
}

// ── the ramp ────────────────────────────────────────────────────────────────

function pct(sorted, p) {
  if (!sorted.length) return 0;
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];
}

async function health() {
  try {
    const r = await fetch(`${URL_BASE}/healthz`);
    return await r.json();
  } catch {
    return null;
  }
}

/** Hold `conc` concurrent workers for `seconds`, each looping request→request. */
async function holdAt(conc, seconds) {
  const latencies = [];
  const status = new Map();
  const until = Date.now() + seconds * 1000;
  let errors = 0;

  const worker = async (vu) => {
    while (Date.now() < until) {
      const t0 = performance.now();
      try {
        const res = await REQ(vu);
        await res.arrayBuffer(); // drain, or sockets pile up
        latencies.push(performance.now() - t0);
        status.set(res.status, (status.get(res.status) ?? 0) + 1);
      } catch (e) {
        errors += 1;
        status.set(String(e.cause?.code ?? e.name ?? "ERR"), (status.get("ERR") ?? 0) + 1);
      }
    }
  };

  await Promise.all(Array.from({ length: conc }, (_, i) => worker(i + 1)));
  latencies.sort((a, b) => a - b);
  return {
    conc,
    n: latencies.length,
    rps: latencies.length / seconds,
    p50: pct(latencies, 50),
    p95: pct(latencies, 95),
    p99: pct(latencies, 99),
    errors,
    status: Object.fromEntries(status),
  };
}

const ms = (v) => `${v.toFixed(0)}ms`.padStart(7);

console.log(`\n  target   ${URL_BASE}`);
console.log(`  stage    ${STAGE}   secret "${SECRET}"   pool ${WORDS.length} words`);
console.log(`  ramp     ${STEP} → ${PEAK} concurrent, ${HOLD}s per step`);
console.log(`  spoof-ip ${SPOOF ? "on (local)" : "OFF — expect 429s from the per-IP limiter"}\n`);

const before = await health();
if (before) {
  console.log(
    `  before   rankVocab ${before.rankVocab}/${before.rankVocabExpected}` +
      `  cache ${before.cache?.size ?? "?"} (${before.cache?.hits ?? 0} hits / ${before.cache?.misses ?? 0} misses)` +
      `  ready=${before.ready ?? "n/a"}\n`,
  );
} else {
  console.log(`  ! /healthz unreachable — is the server running?\n`);
}

console.log("   conc      rps      p50      p95      p99   statuses");
console.log("   ────────────────────────────────────────────────────────────");

const rows = [];
for (let c = STEP; c <= PEAK; c += STEP) {
  const r = await holdAt(c, HOLD);
  rows.push(r);
  console.log(
    `  ${String(r.conc).padStart(5)}  ${r.rps.toFixed(1).padStart(7)}  ` +
      `${ms(r.p50)}  ${ms(r.p95)}  ${ms(r.p99)}   ${JSON.stringify(r.status)}`,
  );
}

const after = await health();
if (after) {
  const h = after.cache?.hits ?? 0;
  const m = after.cache?.misses ?? 0;
  const rate = h + m > 0 ? ((h / (h + m)) * 100).toFixed(1) : "n/a";
  console.log(
    `\n  after    cache ${after.cache?.size ?? "?"} entries, ${h} hits / ${m} misses (${rate}% hit rate)`,
  );
}

// The knee: the first step where p99 is more than 3x the calmest p99 seen.
const basis = Math.min(...rows.map((r) => r.p99));
const knee = rows.find((r) => r.p99 > basis * 3);
console.log(
  knee
    ? `  knee     p99 detaches at ~${knee.conc} concurrent (${knee.p99.toFixed(0)}ms vs ${basis.toFixed(0)}ms floor)`
    : `  knee     not reached by ${PEAK} concurrent — raise --peak`,
);
const anyRateLimited = rows.some((r) => r.status["429"]);
if (anyRateLimited) console.log(`  note     saw 429s — the limiter is shaping this, not the server`);
console.log("");
