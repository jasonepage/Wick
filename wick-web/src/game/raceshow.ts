// SPDX-License-Identifier: MPL-2.0
//
//  raceshow.ts: Race Showdown presentation state (3.8).
//
//  Everything the race screen shows about the duel, worked out from public
//  match state only: each seat's best warmth, guess counts, solve flags, the
//  server's clock and the final result. No guessed word, question or exact
//  score of the other player ever comes in here, so none can go out.
//
//  Pure functions plus three small state holders (RaceShow, TrailRecorder,
//  RematchGate). Times are milliseconds on the caller's clock.
//
//  LOCKSTEP with Hunch/Live/RaceShowdown.swift: same names, same numbers.
//  tests/raceshow.test.ts and HunchTests/RaceShowdownTests.swift check the
//  same cases.
//

import { clamp, smoother, type WickDanceStyle } from "./wickmotion.ts";

// ── heat bands ──────────────────────────────────────────────────────────────

/** The public temperature of a seat, from its best warmth. Same cut points
 *  as the Wick moods (moodFor / KeeperMood.forScore): 18, 30, 45, 60, 100. */
export type HeatBand = "searching" | "trail" | "heating" | "close" | "danger" | "solved";
export const BANDS: readonly HeatBand[] = ["searching", "trail", "heating", "close", "danger", "solved"];

/** Warmth (0..1) as the server's whole-number score (0..100). Scores are
 *  integers, so this is the server's own comparison unit. */
export function pct(warmth: number): number {
  return Math.round(clamp(warmth, 0, 1) * 100);
}

export function heatBand(bestWarmth: number, solved = false): HeatBand {
  const s = pct(bestWarmth);
  if (solved || s >= 100) return "solved";
  if (s >= 60) return "danger";
  if (s >= 45) return "close";
  if (s >= 30) return "heating";
  if (s >= 18) return "trail";
  return "searching";
}

/** The localization key for each band's label. */
export const BAND_KEY: Record<HeatBand, string> = {
  searching: "raceBandSearching",
  trail: "raceBandTrail",
  heating: "raceBandHeating",
  close: "raceBandClose",
  danger: "raceBandDanger",
  solved: "raceBandSolved",
};

/** A score inside each band. The opponent Wick and the heat-trail dots are
 *  painted from this, never from the real score, so color shows the band and
 *  nothing finer. */
export const BAND_SCORE: Record<HeatBand, number> = {
  searching: 10, trail: 24, heating: 37, close: 52, danger: 75, solved: 100,
};

// ── lead ────────────────────────────────────────────────────────────────────

export type Lead = "you" | "them" | "tied";

/** Who leads, from each seat's BEST warmth (not the latest guess). Equal
 *  whole-number scores are a tie, the same way the server breaks a timeout
 *  (warmest best wins, an exact tie is a draw). */
export function leadOf(youBest: number, themBest: number): Lead {
  const a = pct(youBest), b = pct(themBest);
  return a > b ? "you" : a < b ? "them" : "tied";
}

export const LEAD_KEY: Record<Lead, string> = { you: "raceYouLead", them: "raceTheyLead", tied: "raceTied" };

// ── phases and the clock ────────────────────────────────────────────────────

/** The final minute starts where the race music lands on kiai. */
export const FINAL_MINUTE_MS = 60_000;
export const FINAL_15_MS = 15_000;
/** The big 5, 4, 3, 2, 1 numerals near the timer. */
export const FINAL_COUNT_MS = 5_000;

export type RacePhase = "opening" | "finalMinute" | "final15" | "expired" | "result";

/** The presentation phase from the server's remaining time. "expired" means
 *  time is up but the result has not arrived: nobody has won yet. */
export function racePhase(remainingMs: number, hasResult: boolean): RacePhase {
  if (hasResult) return "result";
  if (remainingMs <= 0) return "expired";
  if (remainingMs <= FINAL_15_MS) return "final15";
  if (remainingMs <= FINAL_MINUTE_MS) return "finalMinute";
  return "opening";
}

/** Which dance vocabulary each phase uses. null = hold still (expired or over). */
export function phaseDance(phase: RacePhase): WickDanceStyle | null {
  switch (phase) {
    case "opening": return "groove";
    case "finalMinute": return "swagger";
    case "final15": return "hype";
    default: return null;
  }
}

/** The last server clock and when (local time) it arrived. */
export interface ClockFix { elapsedMs: number; remainingMs: number; at: number }

/** The server clock carried forward to `now` between snapshots. */
export function clockAt(fix: ClockFix, now: number): { elapsedMs: number; remainingMs: number } {
  const d = Math.max(0, now - fix.at);
  return { elapsedMs: fix.elapsedMs + d, remainingMs: Math.max(0, fix.remainingMs - d) };
}

/** m:ss, rounded up so the clock reads 0:00 only when time is really up. */
export function fmtRaceClock(ms: number): string {
  const total = Math.ceil(Math.max(0, ms) / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

/** m:ss of race time used (rounded down), for the recap's finish time. */
export function fmtElapsed(ms: number): string {
  const total = Math.floor(Math.max(0, ms) / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

/** 5, 4, 3, 2, 1 in the last five seconds, else null. */
export function finalCount(remainingMs: number): number | null {
  return remainingMs > 0 && remainingMs <= FINAL_COUNT_MS ? Math.ceil(remainingMs / 1000) : null;
}

/** How much larger the timer is in the final 15 seconds (brief: 15 to 20%). */
export const TIMER_GROW = 1.18;
export const TIMER_PULSE_MS = 260;

/** One restrained pulse each time the final-15 timer ticks to a new second.
 *  Reduced Motion: no scale change, only a short brightness dip. */
export function timerPulse(remainingMs: number, rm: boolean): { scale: number; opacity: number } {
  if (remainingMs <= 0 || remainingMs > FINAL_15_MS) return { scale: 1, opacity: 1 };
  const since = (1000 - (remainingMs % 1000)) % 1000;
  const k = since < TIMER_PULSE_MS ? 1 - smoother(since / TIMER_PULSE_MS) : 0;
  return rm ? { scale: 1, opacity: 1 - 0.3 * k } : { scale: 1 + 0.06 * k, opacity: 1 };
}

// ── face-off ────────────────────────────────────────────────────────────────

/** The face-off plays over the first three seconds of the real race clock
 *  (the server starts timing at pairing). Input stays live the whole time. */
export const FACEOFF_MS = 3_000;
/** "GUESS" holds this long after 1. */
export const FACEOFF_GO_MS = 700;

/** 3, 2, 1, then 0 for "GUESS", then null when the face-off is over. */
export type FaceOffStep = 3 | 2 | 1 | 0 | null;

export function faceOffStep(elapsedMs: number): FaceOffStep {
  if (elapsedMs < 1000) return 3;
  if (elapsedMs < 2000) return 2;
  if (elapsedMs < FACEOFF_MS) return 1;
  if (elapsedMs < FACEOFF_MS + FACEOFF_GO_MS) return 0;
  return null;
}

/** Only a match first seen inside its opening three seconds gets the face-off
 *  (a resumed match does not replay it). */
export function faceOffEligible(firstElapsedMs: number): boolean {
  return firstElapsedMs < FACEOFF_MS;
}

/** A small pose added on top of a Wick's motion. Units match wickmotion.ts
 *  channels: gx pupils (face units), tip -1..1, sx and sy scale offsets. */
export interface Stance { gx: number; tip: number; sx: number; sy: number }

export const FACEOFF_GLANCE = 7;
export const FACEOFF_LEAN = 0.22;
export const FACEOFF_PULSE_MS = 220;

/** The face-off pose. `side` is the direction of the other Wick: +1 for the
 *  local seat (the opponent is on the right), -1 for the opponent seat.
 *  Pupils glance across and the tips lean in; each number lands with a
 *  planted squash (no lift, no slide). On GUESS both face forward again.
 *  Reduced Motion keeps only the glance, which is a face change. */
export function faceOffStance(elapsedMs: number, side: 1 | -1, rm: boolean): Stance {
  const out: Stance = { gx: 0, tip: 0, sx: 0, sy: 0 };
  if (elapsedMs < 0 || elapsedMs >= FACEOFF_MS + 200) return out;
  const w = smoother(elapsedMs / 250) * (1 - smoother((elapsedMs - FACEOFF_MS) / 200));
  out.gx = FACEOFF_GLANCE * side * w;
  if (rm) return out;
  out.tip = FACEOFF_LEAN * side * w;
  for (let k = 0; k <= 3; k++) {
    const e = elapsedMs - k * 1000;
    if (e >= 0 && e < FACEOFF_PULSE_MS) {
      const p = Math.sin((Math.PI * e) / FACEOFF_PULSE_MS);
      out.sx += 0.03 * p;
      out.sy -= 0.045 * p;
    }
  }
  return out;
}

/** The loser's one annoyed side-eye toward the winner (local seat). */
export const SIDE_EYE: Stance = { gx: 6, tip: 0, sx: 0, sy: 0 };

// ── momentum events and announcements ───────────────────────────────────────

export type Momentum = "youHotter" | "closingIn" | "deadHeat" | "suddenHeat" | "finalMinute" | "final15";

export const MOMENTUM_KEY: Record<Momentum, string> = {
  youHotter: "raceYoureHotter",
  closingIn: "raceClosingIn",
  deadHeat: "raceDeadHeat",
  suddenHeat: "raceSuddenHeat",
  finalMinute: "raceFinalMinute",
  final15: "race15Seconds",
};

/** When two events want the one slot, the higher rank keeps it. */
export const MOMENTUM_RANK: Record<Momentum, number> = {
  final15: 4, suddenHeat: 3, youHotter: 2, closingIn: 2, deadHeat: 2, finalMinute: 1,
};

/** On screen for 800 ms (brief: 650 to 900). */
export const MOMENTUM_SHOW_MS = 800;
/** At most one event every two seconds, start to start. */
export const MOMENTUM_GAP_MS = 2_000;
/** VoiceOver hears a lead change at most once every five seconds. */
export const VOICE_GAP_MS = 5_000;

export interface RaceInput {
  now: number;
  youBest: number;
  themBest: number;
  youSolved: boolean;
  themSolved: boolean;
  remainingMs: number;
  /** The authoritative result has arrived. */
  result: boolean;
}

export interface RaceFrame {
  lead: Lead;
  /** The lead changed on this update. */
  leadChanged: boolean;
  /** The Wick that just took the lead gets one attention accent. */
  accent: "you" | "them" | null;
  /** The momentum event on screen now, and when it started (null = none). */
  event: Momentum | null;
  eventAt: number;
  /** Localization keys to speak to screen readers on this update. */
  voice: string[];
  /** How many times the leader switched sides so far. */
  leadChanges: number;
}

/** True when a delayed event still describes the race. */
function stillTrue(ev: Momentum, lead: Lead, remainingMs: number): boolean {
  switch (ev) {
    case "youHotter": return lead === "you";
    case "closingIn": return lead === "them";
    case "deadHeat": return lead === "tied";
    case "final15": return remainingMs > 0;
    default: return true;
  }
}

/**
 * The race's momentum events, lead accents and screen-reader lines. Feed it
 * public state on every snapshot, every scored guess and every clock tick.
 * Deterministic: the same inputs at the same times give the same frames.
 */
export class RaceShow {
  private started = false;
  private lead: Lead = "tied";
  private lastLeader: "you" | "them" | null = null;
  private changes = 0;
  private suddenDone = false;
  private minuteDone = false;
  private fifteenDone = false;
  private show: { event: Momentum; at: number } | null = null;
  private lastShowAt = -Infinity;
  private pending: Momentum | null = null;
  private voicedLead: Lead = "tied";
  private lastVoiceAt = -Infinity;
  private over = false;

  private offer(ev: Momentum, now: number): void {
    if (!this.show && now - this.lastShowAt >= MOMENTUM_GAP_MS) {
      this.show = { event: ev, at: now };
      this.lastShowAt = now;
      return;
    }
    if (this.pending === null || MOMENTUM_RANK[ev] >= MOMENTUM_RANK[this.pending]) this.pending = ev;
  }

  update(inp: RaceInput): RaceFrame {
    const now = inp.now;
    const youB = inp.youSolved ? 1 : inp.youBest;
    const themB = inp.themSolved ? 1 : inp.themBest;
    const lead = leadOf(youB, themB);
    const voice: string[] = [];
    let leadChanged = false;
    let accent: "you" | "them" | null = null;

    // A solve or the result outranks everything: no more events after it.
    if (inp.result || inp.youSolved || inp.themSolved) this.over = true;
    if (this.over) {
      this.show = null;
      this.pending = null;
      this.lead = lead;
      return { lead, leadChanged: false, accent: null, event: null, eventAt: 0, voice, leadChanges: this.changes };
    }

    // Retire the event on screen, then let a waiting one in after the gap
    // (dropped if the race has moved on), then take this update's news.
    if (this.show && now - this.show.at >= MOMENTUM_SHOW_MS) this.show = null;
    if (!this.show && this.pending !== null && now - this.lastShowAt >= MOMENTUM_GAP_MS) {
      const ev = this.pending;
      this.pending = null;
      if (stillTrue(ev, lead, inp.remainingMs)) {
        this.show = { event: ev, at: now };
        this.lastShowAt = now;
      }
    }

    if (!this.started) {
      this.started = true;
      this.lead = lead;
      this.voicedLead = lead;
      if (lead !== "tied") this.lastLeader = lead;
    } else if (lead !== this.lead) {
      leadChanged = true;
      this.lead = lead;
      if (lead !== "tied") {
        accent = lead;
        if (this.lastLeader !== null && this.lastLeader !== lead) this.changes++;
        this.lastLeader = lead;
      }
      this.offer(lead === "you" ? "youHotter" : lead === "them" ? "closingIn" : "deadHeat", now);
    }

    if (!this.suddenDone && heatBand(youB) === "danger" && heatBand(themB) === "danger") {
      this.suddenDone = true;
      this.offer("suddenHeat", now);
    }

    const phase = racePhase(inp.remainingMs, false);
    if (!this.minuteDone && (phase === "finalMinute" || phase === "final15")) {
      this.minuteDone = true;
      // A match resumed inside the last 15 seconds skips straight to 15 SECONDS.
      if (phase === "finalMinute") { this.offer("finalMinute", now); voice.push(MOMENTUM_KEY.finalMinute); }
    }
    if (!this.fifteenDone && phase === "final15") {
      this.fifteenDone = true;
      this.offer("final15", now);
      voice.push(MOMENTUM_KEY.final15);
    }

    // Screen readers: the current lead, once it differs from the last one
    // spoken and five seconds have passed since then.
    if (lead !== this.voicedLead && now - this.lastVoiceAt >= VOICE_GAP_MS) {
      voice.unshift(LEAD_KEY[lead]);
      this.voicedLead = lead;
      this.lastVoiceAt = now;
    }

    return {
      lead, leadChanged, accent,
      event: this.show?.event ?? null, eventAt: this.show?.at ?? 0,
      voice, leadChanges: this.changes,
    };
  }
}

// ── heat trails ─────────────────────────────────────────────────────────────

/** Band transitions for both seats, this match only. Never scores. */
export class TrailRecorder {
  readonly you: HeatBand[] = [];
  readonly them: HeatBand[] = [];

  /** Record a seat's band (only once it has guessed at all). */
  push(side: "you" | "them", band: HeatBand, guessCount: number): void {
    if (guessCount <= 0) return;
    const t = side === "you" ? this.you : this.them;
    if (t[t.length - 1] !== band) t.push(band);
  }
}

export const TRAIL_CAP = 8;

/** At most eight nodes, the share card's way: the first, the last (kept, so a
 *  solve ends green) and the ones between spread evenly. */
export function capTrail(trail: readonly HeatBand[], n = TRAIL_CAP): HeatBand[] {
  if (trail.length <= n) return [...trail];
  const out: HeatBand[] = [];
  for (let i = 0; i < n; i++) out.push(trail[Math.round((i * (trail.length - 1)) / (n - 1))]!);
  out[n - 1] = trail[trail.length - 1]!;
  return out;
}

// ── the opponent seat ───────────────────────────────────────────────────────

/** What the opponent's seat may show. Built field by field from the public
 *  snapshot, so anything else on the object can never reach the screen. */
export interface OpponentSeat {
  band: HeatBand;
  guessCount: number;
  /** The score that paints the opponent Wick: its band's, or null before it
   *  has guessed (resting purple). */
  paintScore: number | null;
  solved: boolean;
  connected: boolean;
}

export function opponentSeat(o: { bestWarmth: number; guessCount: number; solved: boolean; connected: boolean }): OpponentSeat {
  const guessCount = Math.max(0, Math.floor(o.guessCount));
  const solved = o.solved === true;
  const band = heatBand(o.bestWarmth, solved);
  return {
    band,
    guessCount,
    paintScore: guessCount > 0 || solved ? BAND_SCORE[band] : null,
    solved,
    connected: o.connected !== false,
  };
}

// ── result and recap ────────────────────────────────────────────────────────

export type Outcome = "win" | "loss" | "draw" | "void";
/** Which headline copy to use. Solved races get the new 3.8 lines; every
 *  other ending keeps its existing copy. */
export type Headline = "turnedGreen" | "gotThereFirst" | "won" | "lost" | "draw" | "void";

export interface RecapPlayer { id: string; solvedAtMs: number | null; bestWarmth: number; guessCount: number }
export interface RecapResult {
  reason: "solved" | "timeout" | "forfeit" | "void";
  winner: string | null;
  draw: boolean;
  players: RecapPlayer[];
}

export interface Recap {
  outcome: Outcome;
  headline: Headline;
  /** Which Wicks end green. Only a seat the server marks solved. */
  youGreen: boolean;
  themGreen: boolean;
  youBand: HeatBand;
  themBand: HeatBand;
  youGuesses: number;
  themGuesses: number;
  /** The winning solve time, or null when nobody solved (time ran out). */
  finishMs: number | null;
}

/** The recap, from the server's result only. It never picks a winner itself. */
export function recapOf(r: RecapResult, myId: string): Recap {
  const me = r.players.find((p) => p.id === myId) ?? null;
  const them = r.players.find((p) => p.id !== myId) ?? null;
  const outcome: Outcome = r.reason === "void" ? "void"
    : r.draw || r.winner === null ? "draw"
    : r.winner === myId ? "win" : "loss";
  const youGreen = me?.solvedAtMs != null;
  const themGreen = them?.solvedAtMs != null;
  let headline: Headline;
  if (outcome === "void") headline = "void";
  else if (outcome === "draw") headline = "draw";
  else if (r.reason === "solved") headline = outcome === "win" ? "turnedGreen" : "gotThereFirst";
  else headline = outcome === "win" ? "won" : "lost";
  const winnerP = r.winner === null ? null : r.players.find((p) => p.id === r.winner) ?? null;
  return {
    outcome, headline, youGreen, themGreen,
    youBand: heatBand(me?.bestWarmth ?? 0, youGreen),
    themBand: heatBand(them?.bestWarmth ?? 0, themGreen),
    youGuesses: me?.guessCount ?? 0,
    themGuesses: them?.guessCount ?? 0,
    finishMs: r.reason === "solved" ? winnerP?.solvedAtMs ?? null : null,
  };
}

// ── rematch ─────────────────────────────────────────────────────────────────

/** One rematch request per recap: a second tap does nothing. */
export class RematchGate {
  private sent = false;
  get requested(): boolean { return this.sent; }
  /** True the first time; false for every tap after it. */
  request(): boolean {
    if (this.sent) return false;
    this.sent = true;
    return true;
  }
  reset(): void { this.sent = false; }
}

/** Every localization key this module names (the tests check each table). */
export const RACE_KEYS: readonly string[] = [
  "raceFaceOffTitle", "raceFaceOffGo", "raceFoundVoice",
  ...Object.values(BAND_KEY), ...Object.values(LEAD_KEY), ...Object.values(MOMENTUM_KEY),
  "raceYouTurnedGreen", "raceTheyGotThere", "raceSomeoneNew", "raceRematch", "raceSeatYou", "raceSeatOpponent",
  "raceReconnecting", "raceSeatVoice",
  "raceRecapFinish", "raceRecapGuesses", "raceRecapBest", "raceRecapLeadChanges",
  "raceRecapTrail", "raceShareResult", "raceShareWon", "raceShareLost", "raceShareDraw",
  "raceWaitingRematch", "raceConnLostTitle", "raceConnLostBody", "raceTimeUpWaiting",
];
