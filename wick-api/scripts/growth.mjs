#!/usr/bin/env node
//
//  growth.mjs — the four growth counters from a Render log export.
//
//  /metrics is in-memory and resets on every deploy. The durable record is the
//  `[wick-event]` JSON lines the server writes to stdout, which Render keeps.
//  Download the logs (Render dashboard → Logs → download, or `render logs`)
//  and run:
//
//      node scripts/growth.mjs render-logs.txt            # all time
//      node scripts/growth.mjs render-logs.txt 2026-10-01 # since a date
//
//  Prints, split by platform: solve rate, average guesses to solve, share taps,
//  and arrivals from a race link, plus distinct players seen.
//

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const file = process.argv[2];
const since = process.argv[3] ? Date.parse(process.argv[3]) : 0;
if (!file) {
  console.error("usage: node scripts/growth.mjs <render-logs.txt> [since YYYY-MM-DD]");
  process.exit(1);
}

const PREFIX = "[wick-event]";
const SHARE = new Set(["share_grid", "share_map", "race_link_created"]);

function bucket() {
  return { start: 0, solve: 0, giveup: 0, solveGuesses: 0, shareTaps: 0, arrivals: 0, players: new Set() };
}
const by = { all: bucket(), web: bucket(), ios: bucket(), unknown: bucket() };

const rl = createInterface({ input: createReadStream(file) });
for await (const raw of rl) {
  const i = raw.indexOf(PREFIX);
  if (i < 0) continue;
  let ev;
  try { ev = JSON.parse(raw.slice(i + PREFIX.length).trim()); } catch { continue; }
  if (since && Date.parse(ev.ts) < since) continue;
  const p = ev.p === "web" || ev.p === "ios" ? ev.p : "unknown";
  for (const b of [by.all, by[p]]) {
    if (ev.id) b.players.add(ev.id);
    switch (ev.e) {
      case "daily_start": b.start++; break;
      case "daily_solve": b.solve++; if (typeof ev.g === "number") b.solveGuesses += ev.g; break;
      case "daily_giveup": b.giveup++; break;
      case "race_link_opened": b.arrivals++; break;
      default: if (SHARE.has(ev.e)) b.shareTaps++;
    }
  }
}

const pct = (n, d) => (d > 0 ? `${((n / d) * 100).toFixed(1)}%` : "n/a");
const avg = (n, d) => (d > 0 ? (n / d).toFixed(1) : "n/a");
for (const [name, b] of Object.entries(by)) {
  if (name !== "all" && b.start + b.solve + b.giveup + b.shareTaps + b.arrivals === 0) continue;
  console.log(`\n${name}`);
  console.log(`  players seen          ${b.players.size}`);
  console.log(`  dailies started       ${b.start}`);
  console.log(`  solve rate            ${pct(b.solve, b.solve + b.giveup)}  (${b.solve} solved / ${b.giveup} gave up)`);
  console.log(`  avg guesses to solve  ${avg(b.solveGuesses, b.solve)}`);
  console.log(`  share taps            ${b.shareTaps}`);
  console.log(`  arrivals via race link ${b.arrivals}`);
}
