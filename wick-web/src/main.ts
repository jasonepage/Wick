//
//  main.ts — Wick web client (phase 3), styled to match Wick iOS.
//
//  Home menu (Today's puzzle #, Duel/Live Match, Practice, …) → then either a
//  single-player screen (daily / practice, resolved locally with the SAME daily
//  engine as iOS) or the live-match flow (Searching → Match → Result).
//
//  Warmth is REAL and server-computed: single-player calls /warmth (Gemini
//  embeddings) and live matches get the server's authoritative `scored` frame.
//  (game/warmth.ts is a leftover placeholder module, no longer used.) The daily
//  WORD, puzzle number, and win detection are real too — the web plays the exact
//  same daily puzzle as iOS.
//

import { WickMatchClient } from "./net/client.ts";
import type { MatchMode, OpponentKind, StateSnapshot, MatchResult } from "./net/protocol.ts";
import { mascotSVG, ringSVG, scoreLabel, scoreColor, scoreColorA } from "./game/wickface.ts";
import { todaysDaily, randomPracticeAt, practiceAt, wordText, pastPuzzles } from "./game/daily.ts";
import type { DailyWord, PastPuzzle } from "./game/daily.ts";
import { fetchWarmth, httpBaseFrom, askKeeper, fetchReveal, fetchLiveCounts } from "./net/api.ts";
import type { RevealPointDTO, WarmthResult } from "./net/api.ts";
import { computeStats } from "./game/stats.ts";
import { revealSVG, shareRevealCard } from "./game/revealcard.ts";
import { initEvents, track } from "./net/events.ts";
import { buildRun, encodeRun, decodeRun, runDuration, fmtDuration } from "./game/ghost.ts";
import type { GhostRun } from "./game/ghost.ts";
import { mountBackdrop, setBackdropHeat } from "./game/backdrop.ts";
import { dailyStarters, starterText, type StarterItem } from "./game/starters.ts";
import { play as playSound, playGuessTone, soundEnabled, setSoundEnabled, armAudioUnlock } from "./game/sound.ts";
import { t, getLang, setLang, LANGS, LANG_LABEL } from "./i18n.ts";
import type { Lang } from "./i18n.ts";
import { toDataURL as qrToDataURL } from "qrcode";

// Which wick-api to talk to, in priority order:
//   1. `?server=ws://host:port` on the URL (handy for one-off testing).
//   2. VITE_WICK_SERVER from wick-web/.env (see .env.example), baked in at build.
//   3. When served by wick-api itself (production), the same origin.
//   4. During `npm run dev` on localhost, a local wick-api on port 8080.
function defaultServer(): string {
  const fromEnv = (import.meta.env.VITE_WICK_SERVER as string | undefined)?.trim();
  if (fromEnv) return fromEnv;
  const host = location.hostname;
  if (host === "localhost" || host === "127.0.0.1") return "ws://localhost:8080";
  return `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}`;
}
const serverBase = new URLSearchParams(location.search).get("server")?.trim() || defaultServer();
const httpBase = httpBaseFrom(serverBase);

interface Guess {
  word: string;
  /** 0..1 warmth, or null while the server is still scoring it. */
  warmth: number | null;
  /** Contexto rank (iOS convention: 1 = answer, 2 = closest word), when provided. */
  rank?: number | null;
  correct: boolean;
  /** Ms into the round when this was submitted. Drives Ghost Race — see
   *  PLAN_RACE_GHOST. Optional because live-match guesses aren't raceable and
   *  rounds saved before this shipped simply don't have it. */
  at?: number;
  /** Monotonic per-round counter, shared with SoloReply, so the two arrays can
   *  be interleaved back into the true action order. */
  seq?: number;
}

/** Heat readout for a guess: "#N" when close (top 100), else the heat word. */
function heatText(g: Guess): string {
  if (g.warmth === null) return "…";
  if (g.correct) return "Solved!";
  if (g.rank != null && g.rank <= 100) return `#${g.rank}`;
  return scoreLabel(g.warmth * 100).label;
}

// ── single-player state ──
interface SoloReply { question: string; verdict: string; reply: string; at?: number; seq?: number }
const sp = {
  mode: "daily" as "daily" | "practice",
  secret: "",
  puzzleNumber: 0,
  guesses: [] as Guess[],
  replies: [] as SoloReply[],
  solved: false,
  revealed: false, // gave up → the word is shown, round ends
  /** Ms of ACTIVE play so far, with idle gaps clamped (see stampAction). */
  elapsedMs: 0,
  /** Wall clock of the last action, for measuring the next gap. */
  lastAt: 0,
  /** Next action's sequence number. */
  seq: 0,
  /** The run being raced, if this round came from a ?r= link. */
  ghost: null as GhostRun | null,
  /** Wall clock when the race started (after the countdown). 0 = not racing.
   *  The race uses REAL elapsed time — you cannot pause a race — while the
   *  recording keeps using the idle-clamped clock, so a shared run is still
   *  sane if the player wanders off. */
  raceStartAt: 0,
  /** Pool index of the practice word, so a practice round can be raced.
   *  -1 when this isn't a practice round. */
  practiceIndex: -1,
};

/** A player who wanders off mid-round shouldn't produce a ghost that stands
 *  still for four minutes — and a round resumed the next day shouldn't record a
 *  20-hour gap. Any single pause longer than this counts as this much. */
const IDLE_CAP_MS = 45_000;

/** Stamp an action with its position in the round. Call once, at the moment the
 *  player commits a guess or a question. */
function stampAction(): { at: number; seq: number } {
  const now = Date.now();
  if (sp.lastAt > 0) sp.elapsedMs += Math.min(Math.max(0, now - sp.lastAt), IDLE_CAP_MS);
  sp.lastAt = now;
  return { at: sp.elapsedMs, seq: sp.seq++ };
}

/** Begin (or resume) timing a round. Resuming keeps the elapsed time already
 *  banked and restarts the gap clock from now, so the pause isn't counted. */
function startRoundClock(elapsedMs = 0, seq = 0): void {
  sp.elapsedMs = elapsedMs;
  sp.lastAt = Date.now();
  sp.seq = seq;
}

// Round-log order (persisted UI pref): newest-first vs hottest-first.
let soloSortHottest = false;
try { soloSortHottest = localStorage.getItem("wick.solo.sort") === "hottest"; } catch { /* storage off */ }
function setSoloSort(hottest: boolean): void {
  soloSortHottest = hottest;
  try { localStorage.setItem("wick.solo.sort", hottest ? "hottest" : "recent"); } catch { /* ignore */ }
}

// ── daily persistence (localStorage) — your daily round survives a reload/exit ──
function dailyKey(n: number): string { return `wick.daily.${n}`; }
function saveDaily(): void {
  if (sp.mode !== "daily") return;
  try {
    // Keep every day's progress (today AND past puzzles) so the archive can show
    // status and any round resumes — the blobs are tiny and bounded by days played.
    localStorage.setItem(
      dailyKey(sp.puzzleNumber),
      JSON.stringify({
        guesses: sp.guesses, replies: sp.replies, solved: sp.solved, revealed: sp.revealed,
        elapsedMs: sp.elapsedMs, seq: sp.seq,
      }),
    );
  } catch { /* storage full/disabled — play continues without persistence */ }
}

/** Archive row status for a puzzle number, from its saved round (if any). */
function dailyStatus(n: number): "solved" | "revealed" | "playing" | "none" {
  const saved = loadDaily(n);
  if (!saved) return "none";
  if (saved.solved) return "solved";
  if (saved.revealed) return "revealed";
  return saved.guesses.length > 0 || saved.replies.length > 0 ? "playing" : "none";
}
function loadDaily(n: number): {
  guesses: Guess[]; replies: SoloReply[]; solved: boolean; revealed: boolean;
  elapsedMs: number; seq: number;
} | null {
  try {
    const raw = localStorage.getItem(dailyKey(n));
    if (!raw) return null;
    const o = JSON.parse(raw) as {
      guesses?: unknown; replies?: unknown; solved?: unknown; revealed?: unknown;
      elapsedMs?: unknown; seq?: unknown;
    };
    if (!Array.isArray(o.guesses)) return null;
    const guesses = o.guesses as Guess[];
    const replies = Array.isArray(o.replies) ? (o.replies as SoloReply[]) : [];
    return {
      guesses,
      replies,
      solved: !!o.solved,
      revealed: !!o.revealed,
      elapsedMs: typeof o.elapsedMs === "number" ? o.elapsedMs : 0,
      // Rounds saved before this shipped have no seq. Carry on past the actions
      // they do have so a resumed round can't reuse a number.
      seq: typeof o.seq === "number" ? o.seq : guesses.length + replies.length,
    };
  } catch { return null; }
}

// ── live-match state ──
const live = {
  kid: persistentKid(),
  client: null as WickMatchClient | null,
  opponentKind: null as OpponentKind | null,
  snapshot: null as StateSnapshot | null,
  guesses: [] as Guess[],
  replies: [] as { question: string; verdict: string; reply: string; pending: boolean }[],
  opponentLeft: false,
  mode: "casual" as MatchMode,
  friendCode: undefined as string | undefined,
  /** True when THIS tab created the invite (so we show the Share affordance). */
  hosting: false,
  /** 3.3 shared start: when the next race starts (local clock ms), or null. */
  startsAt: null as number | null,
};

let clockTimer: number | null = null;
/** A run parsed from a ?r= link, waiting for the ghost strip (phase 3) to show
 *  it. Held rather than acted on so a link is inert until the UI exists. */
let pendingGhost: GhostRun | null = null;
/** Drives the ghost strip while a race is on. */
let ghostTimer: number | null = null;
/** Polls GET /live while the Race chooser is on screen ("N racing now"). */
let liveCountTimer: number | null = null;
/** Arms the Searching screen's fallback ("race a flame now") after a wait. */
let searchFallbackTimer: number | null = null;
const app = document.querySelector<HTMLDivElement>("#app")!;

// ── DOM helpers ──
function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Partial<HTMLElementTagNameMap[K]> & { class?: string } = {},
  children: (Node | string)[] = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  const { class: className, ...rest } = props;
  if (className) node.className = className;
  Object.assign(node, rest);
  for (const c of children) node.append(c);
  return node;
}
function raw(className: string, markup: string): HTMLDivElement {
  const d = document.createElement("div");
  d.className = className;
  d.innerHTML = markup;
  return d;
}
// ── theme (light / dark / auto) ──
type ThemePref = "auto" | "light" | "dark";
function themePref(): ThemePref {
  const v = localStorage.getItem("wick.theme");
  return v === "light" || v === "dark" ? v : "auto";
}
function resolvedTheme(): "light" | "dark" {
  const p = themePref();
  if (p !== "auto") return p;
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}
function applyTheme(): void {
  document.body.className = `theme-${resolvedTheme()}`;
}
function cycleTheme(): void {
  const order: ThemePref[] = ["auto", "light", "dark"];
  const next = order[(order.indexOf(themePref()) + 1) % order.length]!;
  if (next === "auto") localStorage.removeItem("wick.theme");
  else localStorage.setItem("wick.theme", next);
  applyTheme();
}
function themeLabel(): string {
  switch (themePref()) {
    case "light": return "☀️ Light";
    case "dark": return "🌙 Dark";
    default: return "🌗 Auto";
  }
}
// Live-update when following the system and the OS theme flips.
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
  if (themePref() === "auto") applyTheme();
});
function setThemePref(p: ThemePref): void {
  try {
    if (p === "auto") localStorage.removeItem("wick.theme");
    else localStorage.setItem("wick.theme", p);
  } catch { /* storage off */ }
  applyTheme();
}

// ── daily reminder (best-effort local Notification while Wick is open) ─────────
//  A plain web page can't wake a closed tab, so a genuine cross-session reminder
//  needs web-push (service worker + push server) — out of scope here. What this
//  does honestly: while Wick is open, fire ONE local notification at the chosen
//  time if today's puzzle isn't done. The Settings copy states this limit plainly.
let reminderTimer: number | null = null;

function reminderOn(): boolean {
  try { return localStorage.getItem("wick.reminder.on") === "1"; } catch { return false; }
}
function reminderTime(): string {
  try { return localStorage.getItem("wick.reminder.time") || "19:00"; } catch { return "19:00"; }
}
function setReminder(on: boolean, time?: string): void {
  try {
    if (on) localStorage.setItem("wick.reminder.on", "1");
    else localStorage.removeItem("wick.reminder.on");
    if (time) localStorage.setItem("wick.reminder.time", time);
  } catch { /* storage off */ }
  scheduleReminder();
}
/** True once today's daily is solved or revealed (so we don't nag after playing). */
function playedToday(): boolean {
  const s = dailyStatus(todaysDaily().puzzleNumber);
  return s === "solved" || s === "revealed";
}
/** Arm a one-shot timer for today's reminder time if it's still upcoming and the
 *  puzzle isn't done. Called on boot and whenever the setting changes. */
function scheduleReminder(): void {
  if (reminderTimer !== null) { window.clearTimeout(reminderTimer); reminderTimer = null; }
  if (!reminderOn()) return;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
  const parts = reminderTime().split(":");
  const h = parseInt(parts[0] ?? "", 10);
  const m = parseInt(parts[1] ?? "", 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return;
  const target = new Date();
  target.setHours(h, m, 0, 0);
  const delay = target.getTime() - Date.now();
  if (delay <= 0) return; // already past today — caught tomorrow on next open
  reminderTimer = window.setTimeout(() => {
    if (reminderOn() && !playedToday() && Notification.permission === "granted") {
      try { new Notification("Wick", { body: t("reminderBody") }); } catch { /* ignore */ }
    }
  }, delay);
}

/** Language selector for the Settings screen — switches the whole UI on change. */
function langPicker(): HTMLSelectElement {
  const sel = el("select", { class: "field" });
  for (const l of LANGS) sel.append(el("option", { value: l, selected: l === getLang() }, [LANG_LABEL[l]]));
  sel.addEventListener("change", () => { setLang(sel.value as Lang); rerender(screenSettings); });
  return sel;
}

function screenSettings(): void {
  clear("dark");
  const themeBtn = (p: ThemePref, label: string): HTMLElement =>
    el("button", {
      class: `seg ${themePref() === p ? "on" : ""}`,
      onclick: () => { setThemePref(p); rerender(screenSettings); },
    }, [label]);

  const soundToggle = el("button", {
    class: `toggle ${soundEnabled() ? "on" : ""}`,
    onclick: () => { setSoundEnabled(!soundEnabled()); rerender(screenSettings); },
  }, [soundEnabled() ? t("setOn") : t("setOff")]);

  const notifSupported = typeof Notification !== "undefined";
  const timeInput = el("input", { class: "field time", type: "time", value: reminderTime() });
  timeInput.addEventListener("change", () => setReminder(reminderOn(), timeInput.value));

  const reminderToggle = el("button", {
    class: `toggle ${reminderOn() ? "on" : ""}`,
    onclick: () => {
      if (reminderOn()) { setReminder(false); rerender(screenSettings); return; }
      if (!notifSupported) { toast(t("notifUnsupported")); return; }
      if (Notification.permission === "granted") { setReminder(true, timeInput.value); rerender(screenSettings); return; }
      void Notification.requestPermission().then((perm) => {
        if (perm === "granted") setReminder(true, timeInput.value);
        else toast(t("notifDenied"));
        rerender(screenSettings);
      });
    },
  }, [reminderOn() ? t("setOn") : t("setOff")]);

  const children: (Node | string)[] = [
    el("div", { class: "solo-head" }, [
      el("button", { class: "icon-btn dark", onclick: goHome, title: "Home" }, ["←"]),
      el("span", { class: "solo-title dark" }, [t("settings")]),
      el("span", {}, [""]),
    ]),
    el("div", { class: "lbl" }, [t("setAppearance")]),
    el("div", { class: "seg-row" }, [themeBtn("auto", t("setAuto")), themeBtn("light", t("setLight")), themeBtn("dark", t("setDark"))]),
    el("div", { class: "lbl" }, [t("setSound")]),
    el("div", { class: "set-row" }, [el("span", { class: "set-label" }, [t("setSoundFx")]), soundToggle]),
    el("p", { class: "hint" }, [t("setSoundHint")]),
    el("div", { class: "lbl" }, [t("langLabel")]),
    langPicker(),
    el("div", { class: "lbl" }, [t("setReminder")]),
    el("div", { class: "set-row" }, [el("span", { class: "set-label" }, [t("setRemindMe")]), reminderToggle]),
  ];
  if (reminderOn()) {
    children.push(el("div", { class: "set-row" }, [el("span", { class: "set-label" }, [t("setTime")]), timeInput]));
  }
  children.push(
    el("p", { class: "hint" }, [t("setReminderHint")]),
    el("div", { class: "lbl" }, [t("setAbout")]),
    el("button", { class: "btn secondary", onclick: () => toast('How to play: guess words to warm up to the hidden word. Blue = cold, red = boiling, green = solved! Type a question like "Is it alive?" to ask Wick.') }, [t("howToPlay")]),
    el("a", { class: "btn secondary linkbtn", href: APP_STORE_URL, target: "_blank", rel: "noopener" }, [t("setGetApp")]),
    el("p", { class: "hint" }, [`Server: ${serverBase} · You are "${live.kid}".`]),
  );
  app.append(el("main", { class: "card" }, children));
}

function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/** Direction of the NEXT screen change:
 *   1 — deeper into the app; the new screen enters from the right (default)
 *  -1 — back out; it enters from the left
 *   0 — the same screen re-rendering itself; crossfade, no slide
 *  clear() consumes this and resets it to 1, so a screen only ever has to opt
 *  out of the default. */
let navDir: 1 | -1 | 0 = 1;

/** Go back to the home hub — used by every back arrow and "Back home" button. */
function goHome(): void { navDir = -1; screenHome(); }

/** Re-draw the screen you are already on (a settings toggle, a theme flip)
 *  without it looking like you navigated somewhere. */
function rerender(fn: () => void): void { navDir = 0; fn(); }

/** Clear the screen. The per-screen light/dark hint is now overridden by the
 *  user's global theme preference (auto follows the OS).
 *
 *  The outgoing screen is not simply dropped: it is moved into a fixed ghost
 *  layer and animated away, so the incoming screen can slide in over it. The
 *  nodes are being discarded anyway, so re-parenting them is free. */
function clear(_hint?: "light" | "dark"): void {
  if (clockTimer !== null) {
    window.clearInterval(clockTimer);
    clockTimer = null;
  }
  if (ghostTimer !== null) {
    window.clearInterval(ghostTimer);
    ghostTimer = null;
  }
  if (liveCountTimer !== null) {
    window.clearInterval(liveCountTimer);
    liveCountTimer = null;
  }
  if (searchFallbackTimer !== null) {
    window.clearTimeout(searchFallbackTimer);
    searchFallbackTimer = null;
  }
  applyTheme();
  // Every screen starts cold; the round renderers set it again immediately, so
  // only screens that aren't a round actually stay washed out.
  setBackdropHeat(null);

  const outgoing = Array.from(app.childNodes);
  if (outgoing.length > 0 && navDir !== 0 && !prefersReducedMotion()) {
    const ghost = el("div", { class: `screen-ghost ${navDir > 0 ? "out-left" : "out-right"}` });
    ghost.append(...outgoing);          // this also empties #app
    document.body.append(ghost);
    ghost.addEventListener("animationend", () => ghost.remove(), { once: true });
    window.setTimeout(() => ghost.remove(), 600);   // in case animationend never fires
  } else {
    app.replaceChildren();
  }

  app.classList.remove("nav-fwd", "nav-back", "nav-same");
  void app.offsetWidth;                 // force reflow so the animation restarts
  app.classList.add(navDir > 0 ? "nav-fwd" : navDir < 0 ? "nav-back" : "nav-same");
  navDir = 1;
}
function normalize(w: string): string {
  return w.normalize("NFC").trim().replace(/\s+/g, " ").toLocaleLowerCase();
}

// ── invite links (3.1) ───────────────────────────────────────────────────────
//  Create → share a tappable link → tap to join, replacing the old "both invent and
//  type the same code" flow. Codes are app-generated (server-guaranteed unique); the
//  link opens the iOS app (Universal Link) or lands here in the web client to play.

const APP_STORE_URL = "https://apps.apple.com/app/id6777743483";

/** Per-tab identity, persisted so a reload — or a link opening a new tab — keeps the
 *  same id (reconnect parity with iOS's stored kid). */
function persistentKid(): string {
  const fresh = () => "web-" + Math.random().toString(36).slice(2, 10);
  try {
    const saved = localStorage.getItem("wick.kid");
    if (saved) return saved;
    const id = fresh();
    localStorage.setItem("wick.kid", id);
    return id;
  } catch {
    return fresh();
  }
}

/** App-generated invite code: short + unambiguous (no I/L/O/0/1). The server also
 *  guarantees uniqueness — a collision comes back as `code_taken` and we regenerate. */
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
function genCode(len = 5): string {
  let s = "";
  for (let i = 0; i < len; i++) {
    s += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)]!;
  }
  return s;
}

/** The tappable invite URL — opens the iOS app via the Universal Link, or lands in
 *  this web client to play. Same origin, so it's guesswick.com in production. */
function inviteURL(code: string, mode: "race"): string {
  return `${location.origin}/p/${code}?m=${mode}`;
}

/** Share the invite via the native share sheet, falling back to the clipboard. */
/** A QR code of an invite URL — lets a friend in the same room scan to join, no
 *  typing. Filled asynchronously so the DOM node can be returned synchronously. */
function qrImage(url: string, size = 168): HTMLImageElement {
  const img = el("img", { class: "qr", width: size, height: size, alt: "Scan to join" });
  qrToDataURL(url, { margin: 1, width: size * 2 })
    .then((d) => { img.src = d; })
    .catch(() => { /* QR is a bonus; the link + code still work */ });
  return img;
}

async function shareInvite(url: string, text: string): Promise<void> {
  if (typeof navigator.share === "function") {
    try {
      await navigator.share({ text, url });
      return;
    } catch (e) {
      if ((e as { name?: string }).name === "AbortError") return; // user cancelled
    }
  }
  try {
    await navigator.clipboard.writeText(url);
    toast("Invite link copied — send it to your friend!");
  } catch {
    toast("Couldn't copy — long-press the link to copy it.");
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HOME MENU
// ════════════════════════════════════════════════════════════════════════════

function screenHome(): void {
  clear("light");
  const today = todaysDaily();

  const tile = (
    cls: string,
    icon: string,
    title: string,
    sub: string,
    onclick: () => void,
  ): HTMLElement =>
    el("button", { class: `tile ${cls}`, onclick: () => { void playSound("tap"); onclick(); } }, [
      el("div", { class: "tile-icon" }, [icon]),
      el("div", { class: "tile-title" }, [title]),
      el("div", { class: "tile-sub" }, [sub]),
    ]);

  app.append(
    el("main", { class: "home-wrap" }, [
      el("h1", { class: "home-title" }, ["Wick"]),

      // Today's puzzle hero card
      el("button", { class: "today-card", onclick: () => { void playSound("tap"); startDaily(); } }, [
        raw("today-mascot", mascotSVG({ score: null, size: 92, id: "today" })),
        el("div", { class: "today-text" }, [
          el("div", { class: "today-num" }, [`#${today.puzzleNumber}`]),
          el("div", { class: "today-h" }, [t("todaysPuzzle")]),
          el("div", { class: "today-sub" }, [t("homeGuessWord")]),
        ]),
        el("div", { class: "today-play" }, ["▶"]),
      ]),

      // grid
      el("div", { class: "menu-grid" }, [
        tile("duel", "🏁", t("duelRace"), t("homeRaceSub"), screenDuel),
        tile("practice", "🎲", t("practice"), t("homePlayAnytime"), startPractice),
        tile("past", "🕓", t("pastPuzzles"), t("homeReplayAnyDay"), screenArchive),
        tile("stats", "📊", t("statsTitle"), t("statsChip"), screenStats),
      ]),

      el("div", { class: "home-foot" }, [
        el("button", { class: "foot-btn", onclick: () => rerender(() => { cycleTheme(); screenHome(); }) }, [themeLabel()]),
        el("button", { class: "foot-btn", onclick: () => toast("How to play: guess words to warm up to the hidden word. Blue = cold, red = boiling, green = solved!") }, [t("howToPlay")]),
        el("a", { class: "foot-btn", href: APP_STORE_URL, target: "_blank", rel: "noopener" }, [t("getApp")]),
        el("button", { class: "foot-btn", onclick: screenSettings }, [t("settings")]),
        el("a", { class: "foot-btn", href: "https://github.com/jasonepage/Wick", target: "_blank", rel: "noopener" }, [t("sourceCode")]),
      ]),
    ]),
  );
}

function toast(msg: string): void {
  const t = el("div", { class: "toast" }, [msg]);
  app.append(t);
  window.setTimeout(() => t.classList.add("show"), 10);
  window.setTimeout(() => {
    t.classList.remove("show");
    window.setTimeout(() => t.remove(), 300);
  }, 3200);
}

// ════════════════════════════════════════════════════════════════════════════
//  SINGLE PLAYER (daily / practice)
// ════════════════════════════════════════════════════════════════════════════

/** Enter a daily puzzle (today OR an archived past day — same board, same
 *  per-puzzle persistence, keyed by puzzle number). */
function enterDailyPuzzle(puzzleNumber: number, word: DailyWord): void {
  track("daily_start", { n: puzzleNumber });
  sp.mode = "daily";
  sp.secret = wordText(word, "en");
  sp.puzzleNumber = puzzleNumber;
  const saved = loadDaily(sp.puzzleNumber);
  sp.guesses = saved?.guesses ?? [];
  sp.replies = saved?.replies ?? [];
  sp.solved = saved?.solved ?? false;
  startRoundClock(saved?.elapsedMs ?? 0, saved?.seq ?? 0);
  sp.ghost = null;
  sp.raceStartAt = 0;
  sp.practiceIndex = -1;
  sp.revealed = saved?.revealed ?? false;
  screenSolo();
  // Finish scoring any guess that was still "…" when the tab closed.
  for (const g of sp.guesses) {
    if (!g.correct && g.warmth === null) {
      fetchWarmth(httpBase, sp.secret, g.word).then((r) => applyGuessWarmth(g, r));
    }
  }
}

function startDaily(): void {
  const today = todaysDaily();
  enterDailyPuzzle(today.puzzleNumber, today.word);
}

function startArchivePuzzle(p: PastPuzzle): void {
  enterDailyPuzzle(p.puzzleNumber, p.word);
}

/** Apply a fetched warmth result to a guess. A non-word (typo/keyboard mash) is
 *  rejected: the guess is removed and Wick shrugs — matching iOS, which can't
 *  score a word it doesn't know. */
function applyGuessWarmth(
  g: Guess,
  result: WarmthResult | "not_a_word" | null,
  /** Only a guess the player just typed should make a noise. Resuming a saved
   *  puzzle re-scores every unfinished guess at once, and that must stay silent. */
  announce = false,
): void {
  if (result === "not_a_word") {
    const i = sp.guesses.indexOf(g);
    if (i >= 0) sp.guesses.splice(i, 1);
    toast("Hmm — that's not a word I know. Try another.");
  } else if (result === null) {
    g.warmth = 0;
  } else {
    g.warmth = Math.max(0, Math.min(1, result.score / 100));
    g.rank = result.rank; // enables the "#N" rank readout (parity with iOS)
    // Answer with the matching rung of the iOS pitch ladder: cold guesses reply
    // low, boiling ones reply high.
    if (announce) playGuessTone(g.warmth);
  }
  saveDaily();
  renderSolo();
}

function startPractice(): void {
  track("practice_start");
  const picked = randomPracticeAt();
  const w: DailyWord = picked.word;
  sp.mode = "practice";
  sp.secret = wordText(w, "en");
  sp.puzzleNumber = 0;
  sp.guesses = [];
  sp.replies = [];
  startRoundClock();
  sp.ghost = null;
  sp.raceStartAt = 0;
  sp.practiceIndex = picked.index;
  sp.solved = false;
  sp.revealed = false;
  screenSolo();
}

function looksLikeQuestion(s: string): boolean {
  if (s.endsWith("?")) return true;
  return /^(is|are|does|do|can|could|will|would|has|have|had|was|were|should|am|whats|what|why|how|who|whom|where|when|which|any)\b/i.test(s);
}

function showKeeper(verdict: string, reply: string): void {
  const box = document.querySelector<HTMLDivElement>("#keeper");
  if (!box) return;
  const kind = verdict.toLowerCase().replace(/[^a-z]/g, "");
  const children: (Node | string)[] = [];
  if (verdict) children.push(el("span", { class: `kbadge ${kind}` }, [verdict]));
  children.push(el("span", { class: "kreply" }, [reply]));
  // A rejected / invalid input ("Won't say") gets the unimpressed grey "-_-" Wick;
  // anything else gets the normal resting Wick.
  const neutral = kind === "wontsay";
  const wick = raw("kwick", mascotSVG({ score: null, neutral, size: 40, id: "kw" }));
  box.replaceChildren(wick, el("span", { class: "kbody" }, children));
  box.classList.add("show");
}

// ════════════════════════════════════════════════════════════════════════════
//  ARCHIVE (past puzzles) — replay any past daily, newest first, like iOS
// ════════════════════════════════════════════════════════════════════════════

function screenArchive(): void {
  clear("dark");
  const puzzles = pastPuzzles();
  const dateFmt = (d: Date) => d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });

  const rows = puzzles.map((p) => {
    const status = dailyStatus(p.puzzleNumber);
    const mark =
      status === "solved"
        ? el("span", { class: "arch-status solved", title: "Solved" }, ["✓"])
        : status === "revealed"
          ? el("span", { class: "arch-status revealed", title: "Revealed" }, ["⚑"])
          : status === "playing"
            ? el("span", { class: "arch-status playing", title: "In progress" }, ["•"])
            : el("span", { class: "arch-status none", title: "Not played" }, ["›"]);
    return el("button", { class: "arch-row", onclick: () => startArchivePuzzle(p) }, [
      el("div", { class: "arch-text" }, [
        el("div", { class: "arch-num" }, [t("dailyTitle", p.puzzleNumber)]),
        el("div", { class: "arch-date" }, [dateFmt(p.date)]),
      ]),
      mark,
    ]);
  });

  app.append(
    el("main", { class: "card" }, [
      el("div", { class: "solo-head" }, [
        el("button", { class: "icon-btn", onclick: goHome, title: "Home" }, ["←"]),
        el("span", { class: "solo-title" }, [t("pastPuzzles")]),
        el("span", {}, [""]),
      ]),
      puzzles.length === 0
        ? el("p", { class: "hint center" }, [t("archiveEmpty")])
        : el("div", { class: "arch-list" }, rows),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  STATISTICS (local daily stats — parity with iOS StatsView)
// ════════════════════════════════════════════════════════════════════════════

function screenStats(): void {
  clear("dark");
  const s = computeStats(todaysDaily().puzzleNumber);

  const statTile = (num: string, cap: string): HTMLElement =>
    el("div", { class: "stat-tile" }, [
      el("div", { class: "stat-num" }, [num]),
      el("div", { class: "stat-cap" }, [cap]),
    ]);

  const distRows = s.distribution.map((b) => {
    const bar = el("i");
    bar.style.width = `${Math.round((b.count / s.maxBucketCount) * 100)}%`;
    return el("div", { class: "dist-row" }, [
      el("span", { class: "dist-lbl" }, [b.label]),
      el("span", { class: "dist-bar" }, [bar]),
      el("span", { class: "dist-count" }, [String(b.count)]),
    ]);
  });

  app.append(
    el("main", { class: "card" }, [
      el("div", { class: "solo-head" }, [
        el("button", { class: "icon-btn dark", onclick: goHome, title: "Home" }, ["←"]),
        el("span", { class: "solo-title dark" }, [t("statsTitle")]),
        el("span", {}, [""]),
      ]),
      el("div", { class: "stats-grid" }, [
        statTile(String(s.played), t("statsPlayed")),
        statTile(`${s.winPct}%`, t("statsWinRate")),
        statTile(String(s.currentStreak), t("statsCurStreak")),
        statTile(String(s.maxStreak), t("statsMaxStreak")),
      ]),
      s.wins > 0
        ? el("div", { class: "dist-wrap" }, [
            el("div", { class: "lbl" }, [t("statsDist")]),
            ...distRows,
          ])
        : el("p", { class: "hint center" }, [t("statsEmpty")]),
    ]),
  );
}

/** Prebuilt yes/no questions the player can tap instead of typing (parity with iOS). */
/** How many suggestions are visible at once when the panel is open. Four fits
 *  without pushing the give-up link and the log below the fold, and a short list
 *  reads as a prompt rather than a menu to study. */
const SUGGEST_VISIBLE = 4;
/** How many the day draws from. Re-opening the panel walks a window through
 *  these, so a player who does not like this four can ask for another four. */
const SUGGEST_POOL = 10;

/** Collapsed by default — the suggestions are a safety net for a stuck player,
 *  not the main event, and six permanent chips made the empty board look like a
 *  menu. Matches the iOS "Need ideas to ask Wick?" disclosure. */
let suggestOpen = false;
/** Advances every time the panel is opened, so each open shows a fresh four. */
let suggestOffset = 0;

/** The day seed for the starter set. `dayIndex = puzzleNumber + 8000` mirrors
 *  WordBank.dailyNumber(), so a given calendar day seeds the same way here as it
 *  does in the app. Practice rounds seed off the pool index instead, so a
 *  practice word does not silently inherit today's daily set. */
function starterSeed(): number {
  return sp.mode === "daily" ? sp.puzzleNumber + 8000 : 500_000 + sp.practiceIndex;
}

/** Ask Wick a question in the solo round (shared by the input and the suggestion chips). */
function askSolo(text: string): void {
  const q = text.trim();
  if (!q || sp.solved || sp.revealed) return;
  const r: SoloReply = { question: q, verdict: "", reply: "Wick is thinking…", ...stampAction() };
  sp.replies.unshift(r);
  showKeeper("", "Wick is thinking…");
  renderSolo();
  askKeeper(httpBase, sp.secret, q).then((ans) => {
    if (ans) { r.verdict = ans.verdict; r.reply = ans.reply; showKeeper(ans.verdict, ans.reply); }
    else { r.reply = "Wick is quiet right now."; showKeeper("", "Wick is quiet right now."); }
    saveDaily();
    renderSolo();
  });
}

/** Tappable suggested questions, behind a disclosure. Questions already asked
 *  retire from the pool; the whole block disappears once the round is over. */
function renderSuggest(over: boolean): void {
  const box = document.querySelector<HTMLDivElement>("#suggest");
  if (!box) return;
  if (over) { box.replaceChildren(); suggestOpen = false; return; }

  const asked = new Set(sp.replies.map((r) => normalize(r.question)));
  const pool: StarterItem[] = dailyStarters(starterSeed(), SUGGEST_POOL)
    .filter((q) => !asked.has(normalize(q.full)));
  if (pool.length === 0) { box.replaceChildren(); return; }

  const toggle = el("button", {
    class: `suggest-toggle${suggestOpen ? " open" : ""}`,
    onclick: () => {
      // Opening advances the window, so the second look is not the first four
      // again. Closing leaves it alone.
      if (!suggestOpen) suggestOffset += SUGGEST_VISIBLE;
      suggestOpen = !suggestOpen;
      void playSound("tap");
      renderSuggest(false);
    },
  }, [
    el("span", { class: "suggest-bulb" }, ["\u{1F4A1}"]),
    el("span", { class: "suggest-toggle-lbl" }, [t("needIdeas")]),
    el("span", { class: "suggest-chevron" }, ["\u{25BE}"]),
  ]);

  if (!suggestOpen) { box.replaceChildren(toggle); return; }

  // Window into the day's pool, wrapping — so it never runs out, and asking a
  // question shrinks the pool under the window rather than emptying the panel.
  const start = ((suggestOffset % pool.length) + pool.length) % pool.length;
  const shown: StarterItem[] = [];
  for (let i = 0; i < Math.min(SUGGEST_VISIBLE, pool.length); i++) {
    shown.push(pool[(start + i) % pool.length]!);
  }

  box.replaceChildren(
    toggle,
    el("div", { class: "suggest-list" }, shown.map((q) =>
      // Shown localised, SENT in English — see game/starters.ts.
      el("button", {
        class: "suggest-chip",
        onclick: () => { void playSound("tap"); askSolo(q.full); },
      }, [starterText(q, getLang())]))),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  THE REVEAL — post-round semantic map (server-computed layout via /reveal)
// ════════════════════════════════════════════════════════════════════════════

/** Build the spoiler-free card and hand it to the share sheet (or save it).
 *  The word and the guess labels are withheld inside revealcard.ts, not here —
 *  one flag, one place, so a future caller can't leak the answer by forgetting. */
async function shareMap(points: RevealPointDTO[]): Promise<void> {
  track("share_map", { n: sp.puzzleNumber });
  const daily = sp.mode === "daily";
  const outcome = await shareRevealCard(
    points,
    {
      puzzleNumber: daily ? sp.puzzleNumber : 0,
      badge: daily ? `#${sp.puzzleNumber}` : t("practice"),
      resultLine: sp.solved ? t("revealShareSolved", sp.guesses.length) : t("revealShareUnsolved"),
      host: location.host,
    },
    dailyShareText(),
  );
  if (outcome === "downloaded") toast(t("revealShareSaved"));
  else if (outcome === "failed") toast(t("revealShareFail"));
}

async function screenReveal(): Promise<void> {
  clear("dark");
  const word = sp.secret;
  const solvedCount = sp.solved ? sp.guesses.length : 0;
  const guesses = [...sp.guesses].reverse()
    .filter((g) => g.warmth !== null)
    .map((g) => ({ word: g.word, score: g.correct ? 100 : (g.warmth as number) * 100 }));

  const host = el("div", { id: "reveal-host" }, [el("p", { class: "center muted" }, [t("revealBuilding")])]);
  app.append(el("main", { class: "card" }, [
    el("div", { class: "solo-head" }, [
      el("button", { class: "icon-btn dark", onclick: screenSolo, title: t("back") }, ["←"]),
      el("span", { class: "solo-title dark" }, [t("revealTitle")]),
      el("span", {}, [""]),
    ]),
    host,
  ]));

  const points = guesses.length ? await fetchReveal(httpBase, guesses) : [];
  if (!points) {
    host.replaceChildren(
      el("p", { class: "center muted" }, [t("revealFail")]),
      el("button", { class: "btn secondary", onclick: screenSolo }, [t("back")]),
    );
    return;
  }
  const kids: (Node | string)[] = [];
  if (solvedCount > 0) kids.push(el("h2", {}, [t("revealFound", word, solvedCount)]));
  track("reveal_view", { n: sp.puzzleNumber });
  kids.push(raw("reveal-plot", revealSVG(points, word)));
  kids.push(el("p", { class: "hint" }, [t("revealCaption")]));
  if (points.length > 0) {
    kids.push(el("button", {
      class: "btn primary",
      onclick: () => { void playSound("tap"); void shareMap(points); },
    }, [t("revealShare")]));
  }
  host.replaceChildren(...kids);
}

/** Someone sent you a race link. Shown instead of Home so the challenge is the
 *  first thing you see, with an explicit opt-out into a normal round. */
function isIOS(): boolean {
  const ua = navigator.userAgent;
  // iPadOS 13+ reports itself as Macintosh; the touch-point count is what tells
  // the two apart.
  return /iPad|iPhone|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
}

function screenChallenge(run: GhostRun): void {
  clear("dark");
  track("race_link_opened", run.mode === "daily" ? { n: run.ref } : {});
  const kids: (Node | string)[] = [
    raw("mascot-wrap", mascotSVG({ score: null, size: 108, id: "chal" })),
    el("h2", {}, [t("raceChallengeTitle")]),
    el("p", { class: "center muted" }, [
      run.mode === "practice"
        ? t("raceChallengeBlurbPractice", run.actions.length)
        : t("raceChallengeBlurb", run.ref, run.actions.length),
    ]),
    el("button", { class: "btn primary", onclick: () => { void playSound("tap"); startGhostRace(run); } }, [t("raceStart")]),
    el("button", { class: "btn secondary", onclick: () => { pendingGhost = null; goHome(); } }, [t("raceDecline")]),
  ];
  // A Universal Link only fires when it is tapped from another app. Typed into
  // Safari's address bar, tapped from a page already on guesswick.com, or opened
  // while iOS holds a stale association, it does not — so someone who owns the app
  // can still land here. The custom scheme has none of those rules.
  if (isIOS()) {
    kids.push(el("a", { class: "btn ghost", href: `wick://r/${encodeRun(run)}` }, [t("raceOpenApp")]));
  }
  app.append(el("main", { class: "card" }, kids));
}

/** Enter the challenged puzzle, then count in. The race clock does not start
 *  until the countdown finishes — otherwise you lose seconds to reading. */
function startGhostRace(run: GhostRun): void {
  pendingGhost = null;

  if (run.mode === "practice") {
    const w = practiceAt(run.ref);
    if (!w) { toast(t("raceUnavailable")); goHome(); return; }
    sp.mode = "practice";
    sp.secret = wordText(w, "en");
    sp.puzzleNumber = 0;
    sp.guesses = [];
    sp.replies = [];
    sp.solved = false;
    sp.revealed = false;
    startRoundClock();
    sp.practiceIndex = run.ref;
  } else {
    const today = todaysDaily();
    const word = today.puzzleNumber === run.ref
      ? today.word
      : pastPuzzles().find((p) => p.puzzleNumber === run.ref)?.word;
    if (!word) { toast(t("raceUnavailable")); goHome(); return; }
    const saved = loadDaily(run.ref);
    // Already finished this day? Don't drop them into a spent board — they have
    // a time already, so the race resolves right now for free.
    if (saved && (saved.solved || saved.revealed)) {
      enterDailyPuzzle(run.ref, word);
      sp.ghost = run;
      sp.raceStartAt = Date.now() - Math.max(0, saved.elapsedMs);
      screenSolo();
      return;
    }
    enterDailyPuzzle(run.ref, word);   // resets sp.ghost, so set it after
  }

  sp.ghost = run;
  sp.raceStartAt = 0;
  screenSolo();
  countIn(() => { sp.raceStartAt = Date.now(); });
}

/** 3 · 2 · 1 · Go. */
function countIn(done: () => void): void {
  const steps = ["3", "2", "1", t("raceGo")];
  const overlay = el("div", { class: "countdown" });
  const n = el("div", { class: "countdown-n" });
  overlay.append(n);
  document.body.append(overlay);
  let i = 0;
  const tick = (): void => {
    if (i >= steps.length) { overlay.remove(); done(); return; }
    n.textContent = steps[i]!;
    n.classList.remove("pop");
    void n.offsetWidth;
    n.classList.add("pop");
    void playSound("tap", 0.6);
    i++;
    window.setTimeout(tick, 700);
  };
  tick();
}

function screenSolo(): void {
  clear("dark");
  // A new board starts closed, on a fresh window into the day's pool.
  suggestOpen = false;
  suggestOffset = 0;
  const input = el("input", { class: "field", placeholder: t("guessOrAskPlaceholder"), autocomplete: "off", spellcheck: false });
  const submit = () => {
    const text = input.value.trim();
    if (!text || sp.solved || sp.revealed) return;

    // A question → ask the Keeper (Gemini). A word → a guess.
    if (looksLikeQuestion(text) && normalize(text) !== normalize(sp.secret)) {
      input.value = "";
      askSolo(text);
      return;
    }

    const correct = normalize(text) === normalize(sp.secret);
    const g: Guess = { word: text, warmth: correct ? 1 : null, correct, ...stampAction() }; // null = scoring…
    sp.guesses.unshift(g);
    if (correct) {
      sp.solved = true;
      void playSound("solved");
      if (sp.mode === "daily") track("daily_solve", { n: sp.puzzleNumber, g: sp.guesses.length });
    }
    input.value = "";
    renderSolo();
    saveDaily();
    if (!correct) {
      fetchWarmth(httpBase, sp.secret, text).then((r) => applyGuessWarmth(g, r, true));
    }
  };
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });

  app.append(
    el("main", { class: "card" }, [
      el("div", { class: "solo-head" }, [
        el("button", { class: "icon-btn", onclick: goHome, title: "Home" }, ["←"]),
        el("span", { class: "solo-title" }, [sp.mode === "daily" ? t("dailyTitle", sp.puzzleNumber) : t("practice")]),
        el("span", {}, [""]),
      ]),
      ...(sp.ghost ? [el("div", { id: "ghost-strip", class: "opp-strip ghost-strip" })] : []),
      el("div", { id: "hero", class: "hero" }),
      el("div", { id: "latest", class: "latest" }),
      el("div", { id: "keeper", class: "keeper" }),
      el("div", { class: "guess-row", id: "grow" }, [
        input,
        el("button", { class: "send", onclick: submit, title: "Guess or ask" }, ["↑"]),
      ]),
      el("p", { class: "hint" }, [t("guessOrAskHint")]),
      el("div", { id: "suggest", class: "suggest" }),
      el("div", { id: "giveup-slot", class: "giveup-slot" }),
      el("div", { id: "solo-log-head", class: "log-head" }),
      el("ul", { id: "my-guesses", class: "guesses" }),
    ]),
  );
  input.focus();
  renderSolo();
  if (sp.ghost) {
    renderGhostStrip();
    ghostTimer = window.setInterval(renderGhostStrip, 250);
    if (sp.solved || sp.revealed) track("race_finished", { g: sp.guesses.length });
  }
}

/** The headline after a raced round. Time decides it — you cannot pause a race —
 *  and an unsolved round always loses to a solved one. Their time is withheld
 *  until this moment on purpose: knowing the target from move one kills it. */
function raceBanner(): HTMLElement | null {
  const run = sp.ghost;
  if (!run) return null;
  const mine = raceElapsed();
  const theirs = runDuration(run);
  const drew = sp.solved && run.solved && Math.abs(mine - theirs) < 1000;
  const won = !drew && sp.solved && (!run.solved || mine < theirs);
  const headline = drew ? t("raceDraw") : won ? t("raceWon") : sp.solved ? t("raceLost") : t("raceUnsolved");
  return el("div", { class: `race-result ${won ? "win" : drew ? "draw" : "loss"}` }, [
    el("div", { class: "race-head" }, [headline]),
    el("div", { class: "race-times" }, [
      el("span", {}, [`${t("raceYou")} ${sp.solved ? fmtDuration(mine) : "—"}`]),
      el("span", { class: "race-vs" }, ["vs"]),
      el("span", {}, [`${t("raceThem")} ${run.solved ? fmtDuration(theirs) : "—"}`]),
    ]),
  ]);
}

/** Where the ghost stands right now: the last action whose timestamp has been
 *  reached. Returns -1 before their first move. */
function ghostIndexAt(run: GhostRun, elapsedMs: number): number {
  let i = -1;
  for (let k = 0; k < run.actions.length; k++) {
    if (run.actions[k]!.t <= elapsedMs) i = k; else break;
  }
  return i;
}

/** Elapsed race time in ms, or 0 when not racing. */
function raceElapsed(): number {
  return sp.raceStartAt > 0 ? Date.now() - sp.raceStartAt : 0;
}

// Canonical band TOKENS, not display strings — they key into "heat.*" in
// i18n.ts, the same table the guess rows use. Never render one directly.
const BAND_LABEL = ["Freezing", "Cold", "Cool", "Warm", "Hot", "Boiling", "Solved!"];
const BAND_SCORE = [4, 12, 22, 36, 50, 75, 100]; // a representative score per band, for colour

/** Paint the opponent strip from the recording. Same markup and classes as a
 *  live match, because a ghost should look exactly like an opponent — that is
 *  the whole point of it being the on-ramp to live Race. */
function renderGhostStrip(): void {
  const strip = document.querySelector<HTMLDivElement>("#ghost-strip");
  if (!strip || !sp.ghost) return;
  const run = sp.ghost;
  const over = sp.solved || sp.revealed;
  const elapsed = over ? runDuration(run) + 1 : raceElapsed();
  const idx = ghostIndexAt(run, elapsed);
  const cur = idx >= 0 ? run.actions[idx]! : null;
  const band = cur ? cur.band : 0;
  const done = idx >= run.actions.length - 1 && run.solved;

  const bar = el("i");
  bar.style.width = `${cur ? Math.round(((band + 1) / 7) * 100) : 0}%`;
  bar.style.background = scoreColor(cur ? BAND_SCORE[band]! : null);

  // One pip per action they have taken so far. Filled = it improved their best,
  // hollow = it didn't, ? = they asked Wick. Never shows the future.
  const pips = run.actions.slice(0, idx + 1).map((a) =>
    el("span", { class: `gpip ${a.kind === 1 ? "q" : a.improved ? "up" : "flat"}` }, [a.kind === 1 ? "?" : ""]),
  );

  strip.replaceChildren(
    el("div", { class: "opp-info" }, [
      el("div", { class: "opp-top" }, [
        el("span", { class: "tag ghost" }, ["👻 " + t("ghostRival")]),
        el("span", { class: "opp-count" }, [
          done ? t("ghostFinished", fmtDuration(runDuration(run)))
               : cur ? t("heat." + BAND_LABEL[band]!) : t("ghostWaiting"),
        ]),
      ]),
      el("div", { class: "mini-bar" }, [bar]),
      el("div", { class: "gpips" }, pips),
    ]),
  );
}

/** A "race me on this word" link for the round just played, or null if the round
 *  predates the action recorder (nothing to replay). Carries numbers only — see
 *  game/ghost.ts.
 *  Exported rather than wired to a button on purpose: the strip that gives a
 *  link meaning lands in phase 3, and shipping the share action before it would
 *  hand people a link that does almost nothing. */
function raceLink(): string | null {
  const practice = sp.mode === "practice";
  if (practice && sp.practiceIndex < 0) return null; // round predates the index
  const run = buildRun(
    practice ? "practice" : "daily",
    practice ? sp.practiceIndex : sp.puzzleNumber,
    sp.solved, sp.guesses, sp.replies,
  );
  if (!run) return null;
  // Path form, not ?r= — Universal Links match on PATH only, so this is what
  // lets an installed iOS app receive the link. The SPA fallback already serves
  // index.html for any path, so nothing server-side changes.
  return `${location.origin}/r/${encodeRun(run)}`;
}

/** Share the round as a challenge. Numbers only — see game/ghost.ts. */
async function shareRace(): Promise<void> {
  const url = raceLink();
  if (!url) { toast(t("raceNothingToShare")); return; }
  track("race_link_created", sp.mode === "daily" ? { n: sp.puzzleNumber } : {});
  const mine = sp.ghost ? raceElapsed() : sp.elapsedMs;
  const text = sp.solved ? t("raceShareSolved", fmtDuration(mine)) : t("raceShareUnsolved");
  if (typeof navigator.share === "function") {
    try { await navigator.share({ text, url }); return; }
    catch (e) { if ((e as { name?: string }).name === "AbortError") return; }
  }
  try { await navigator.clipboard.writeText(`${text} ${url}`); toast(t("raceLinkCopied")); }
  catch { toast(t("raceLinkFailed")); }
}

/** Reveal the word and end the round (parity with iOS "Give up"). */
function giveUpSolo(): void {
  if (sp.solved || sp.revealed) return;
  sp.revealed = true;
  void playSound("gaveup");
  if (sp.mode === "daily") track("daily_giveup", { n: sp.puzzleNumber, g: sp.guesses.length });
  saveDaily();
  renderSolo();
}

/** Best score so far on a 0..100 scale, or null if nothing is scored yet.
 *  Mirrors iOS `GameViewModel.bestScore` — BEST, not latest, so the background
 *  only ever warms within a round. */
function bestScore(gs: Guess[]): number | null {
  let best: number | null = null;
  for (const g of gs) {
    if (g.warmth === null) continue;
    const s = g.warmth * 100;
    if (best === null || s > best) best = s;
  }
  return best;
}

function renderSolo(): void {
  const latest = sp.guesses[0];
  const over = sp.solved || sp.revealed;
  setBackdropHeat(sp.revealed ? null : bestScore(sp.guesses));
  renderHero("#hero", "solo", latest, sp.revealed);
  const latestEl = document.querySelector<HTMLDivElement>("#latest");
  if (latestEl) {
    if (sp.solved) {
      // The map goes FIRST. It is the only artifact of ours that nobody else has;
      // the emoji grid is the same shape as every Wordle clone since 2022 and
      // earns no clicks. Leading with the grid at the moment of the win was
      // spending our best surface on our most generic asset.
      // (PLAN_3.2 decided against auto-opening the map — this promotes the
      // button instead, which respects that call.)
      const actions: HTMLElement[] = [];
      const hasMap = sp.guesses.some((g) => g.warmth !== null);
      const banner = sp.ghost ? raceBanner() : null;
      if (raceLink()) {
        actions.push(el("button", {
          class: "btn primary",
          onclick: () => { void playSound("tap"); void shareRace(); },
        }, [sp.ghost ? t("raceThemBack") : t("raceAFriend")]));
      }
      if (hasMap) {
        actions.push(el("button", { class: "btn secondary", onclick: () => { void screenReveal(); } }, [t("revealSeeMap")]));
      }
      if (sp.mode === "daily") {
        actions.push(el("button", { class: `btn ${hasMap ? "secondary" : "primary"}`, onclick: () => { void shareDaily(); } }, ["📋 " + t("shareResult")]));
        actions.push(el("button", { class: "btn secondary", onclick: screenStats }, ["📊 " + t("statsTitle")]));
        actions.push(el("button", { class: "btn secondary", onclick: goHome }, [t("backHome")]));
      } else {
        actions.push(el("button", { class: `btn ${hasMap ? "secondary" : "primary"}`, onclick: startPractice }, [t("newWord")]));
      }
      latestEl.replaceChildren(
        el("span", { class: "word" }, [`${t("solvedTitle")} ${t("theWordWas")} "${sp.secret}".`]),
        ...(banner ? [banner] : []),
        el("div", { class: "row-actions" }, actions),
      );
    } else if (sp.revealed) {
      // The map goes FIRST. It is the only artifact of ours that nobody else has;
      // the emoji grid is the same shape as every Wordle clone since 2022 and
      // earns no clicks. Leading with the grid at the moment of the win was
      // spending our best surface on our most generic asset.
      // (PLAN_3.2 decided against auto-opening the map — this promotes the
      // button instead, which respects that call.)
      const actions: HTMLElement[] = [];
      const hasMap = sp.guesses.some((g) => g.warmth !== null);
      const banner = sp.ghost ? raceBanner() : null;
      if (raceLink()) {
        actions.push(el("button", {
          class: "btn primary",
          onclick: () => { void playSound("tap"); void shareRace(); },
        }, [sp.ghost ? t("raceThemBack") : t("raceAFriend")]));
      }
      if (hasMap) {
        actions.push(el("button", { class: "btn secondary", onclick: () => { void screenReveal(); } }, [t("revealSeeMap")]));
      }
      if (sp.mode === "daily") {
        actions.push(el("button", { class: `btn ${hasMap ? "secondary" : "primary"}`, onclick: () => { void shareDaily(); } }, ["📋 " + t("shareResult")]));
        actions.push(el("button", { class: "btn secondary", onclick: screenStats }, ["📊 " + t("statsTitle")]));
        actions.push(el("button", { class: "btn secondary", onclick: goHome }, [t("backHome")]));
      } else {
        actions.push(el("button", { class: `btn ${hasMap ? "secondary" : "primary"}`, onclick: startPractice }, [t("newWord")]));
      }
      latestEl.replaceChildren(
        el("span", { class: "word reveal" }, [`${t("theWordWas")} "${sp.secret}".`]),
        ...(banner ? [banner] : []),
        el("div", { class: "row-actions" }, actions),
      );
    } else {
      renderLatestChip(latestEl, latest);
    }
  }
  // Input row + give-up button only while the round is live.
  const grow = document.querySelector<HTMLDivElement>("#grow");
  if (grow) grow.style.display = over ? "none" : "";
  renderSuggest(over);
  renderGiveUpSlot(over);
  renderSoloLog();
}

/** The "Give up" affordance (parity with iOS): a small button while the round is
 *  live, replaced by an inline confirm on the first tap so it can't misfire. */
function renderGiveUpSlot(over: boolean): void {
  const slot = document.querySelector<HTMLDivElement>("#giveup-slot");
  if (!slot) return;
  if (over) { slot.replaceChildren(); return; }
  const showButton = () =>
    slot.replaceChildren(
      el("button", { class: "giveup-btn", onclick: showConfirm }, [t("giveUp")]),
    );
  const showConfirm = () =>
    slot.replaceChildren(
      el("span", { class: "giveup-ask" }, [t("giveUpTitle")]),
      el("button", { class: "giveup-yes", onclick: giveUpSolo }, [t("revealBtn")]),
      el("button", { class: "giveup-no", onclick: showButton }, [t("keepTrying")]),
    );
  showButton();
}

/** Populate a "YOUR ROUND" log head with the shared Recent/Hottest toggle. Used by
 *  the solo board, the live match, and the dare — the sort pref is one setting. */
function renderSortHead(headSel: string, hasLog: boolean, rerender: () => void): void {
  const head = document.querySelector<HTMLDivElement>(headSel);
  if (!head) return;
  if (!hasLog) { head.replaceChildren(); return; }
  const chip = (hottest: boolean, label: string) =>
    el("button", {
      class: `sortchip ${soloSortHottest === hottest ? "on" : ""}`,
      onclick: () => { if (soloSortHottest !== hottest) { setSoloSort(hottest); rerender(); } },
    }, [label]);
  head.replaceChildren(
    el("span", { class: "log-title" }, [t("roundLog")]),
    el("div", { class: "sorttoggle" }, [chip(false, t("sortRecent")), chip(true, t("sortClosest"))]),
  );
}

/** The solo round log: asked questions + guesses, with a Recent/Hottest toggle. */
function renderSoloLog(): void {
  const hasLog = sp.guesses.length > 0 || sp.replies.length > 0;
  renderSortHead("#solo-log-head", hasLog, renderSolo);
  const gs = soloSortHottest ? sortGuessesHottest(sp.guesses) : sp.guesses;
  const list = document.querySelector<HTMLUListElement>("#my-guesses");
  if (list) list.replaceChildren(...sp.replies.map(questionRowEl), ...gs.map(guessRowEl));
}

/** Emoji square for a warmth score (0..100) — the shareable grid, warm→cold. */
function warmthSquare(score: number): string {
  if (score >= 100) return "🟩"; // solved
  if (score >= 60) return "🟥";  // boiling
  if (score >= 45) return "🟧";  // hot
  if (score >= 30) return "🟨";  // warm
  if (score >= 8) return "🟦";   // cool / cold
  return "⬜";                    // freezing
}

/** Wordle-style shareable result for today's daily (mirrors iOS shareText). */
function dailyShareText(): string {
  const title = `Wick #${sp.puzzleNumber}`;
  // Oldest → newest, scored guesses only; the winning guess is 🟩.
  const known = [...sp.guesses].reverse().filter((g) => g.warmth !== null);
  const squares = known.map((g) => warmthSquare(g.correct ? 100 : g.warmth! * 100));
  const grid: string[] = [];
  for (let i = 0; i < squares.length; i += 10) grid.push(squares.slice(i, i + 10).join(""));
  let stats = sp.solved ? `solved in ${sp.guesses.length}` : "unsolved";
  if (sp.replies.length > 0) stats += ` · ${sp.replies.length} question${sp.replies.length === 1 ? "" : "s"}`;
  return `${title} — ${stats}\n${grid.join("\n")}\nPlay at ${location.origin}`;
}

async function shareDaily(): Promise<void> {
  track("share_grid", { n: sp.puzzleNumber });
  const text = dailyShareText();
  if (typeof navigator.share === "function") {
    try { await navigator.share({ text }); return; }
    catch (e) { if ((e as { name?: string }).name === "AbortError") return; } // cancelled
  }
  try {
    await navigator.clipboard.writeText(text);
    toast("Result copied — paste it anywhere!");
  } catch {
    toast("Couldn't copy automatically — long-press to select the result.");
  }
}

function sortGuessesHottest(gs: Guess[]): Guess[] {
  return [...gs].sort((a, b) => {
    if (a.warmth === null && b.warmth === null) return 0;
    if (a.warmth === null) return -1; // still-scoring floats to the top
    if (b.warmth === null) return 1;
    return b.warmth - a.warmth;
  });
}

function questionRowEl(r: SoloReply): HTMLElement {
  const kind = r.verdict.toLowerCase().replace(/[^a-z]/g, "");
  return el("li", { class: "qrow" }, [
    el("div", { class: "qtop" }, [
      r.verdict ? el("span", { class: `kbadge ${kind}` }, [r.verdict]) : el("span", { class: "qmark" }, ["🔥"]),
      el("span", { class: "qtext" }, [r.question]),
    ]),
    ...(r.reply ? [el("div", { class: "qreply" }, [r.reply])] : []),
  ]);
}

/** Shared hero (ring + mascot). Handles a pending (null-warmth) guess with a
 *  neutral "Scoring…" state so there's no misleading placeholder flash. */
function renderHero(sel: string, id: string, latest: Guess | undefined, revealed = false): void {
  const hero = document.querySelector<HTMLDivElement>(sel);
  if (!hero) return;
  if (revealed) {
    // Gave up: a defeated, unimpressed grey Wick — no warmth ring reading.
    hero.replaceChildren(
      el("div", { class: "gauge" }, [
        raw("", ringSVG(0, scoreColor(null))),
        el("div", { class: "gauge-label" }, [
          el("span", { class: "big" }, ["Revealed"]),
          el("span", { class: "small" }, ["the word is below"]),
        ]),
      ]),
      raw("mascot-wrap", mascotSVG({ score: null, neutral: true, size: 116, id })),
    );
    return;
  }
  const pending = !!latest && latest.warmth === null;
  const w = latest && latest.warmth !== null ? latest.warmth : null;
  const score = w !== null ? w * 100 : null;
  const rankBig = latest && latest.rank != null && latest.rank <= 100 ? `#${latest.rank}` : null;
  const big = !latest ? t("ready") : pending ? t("scoringBig") : latest.correct ? "Solved!" : rankBig ?? scoreLabel(score!).label;
  const small = !latest ? t("makeGuess") : pending ? t("oneSec") : scoreLabel(score!).hint;
  hero.replaceChildren(
    el("div", { class: "gauge" }, [
      raw("", ringSVG(w ?? 0, scoreColor(score))),
      el("div", { class: "gauge-label" }, [
        el("span", { class: "big" }, [big]),
        el("span", { class: "small" }, [small]),
      ]),
    ]),
    raw("mascot-wrap", mascotSVG({ score, size: 116, id })),
  );
}

function renderLatestChip(latestEl: HTMLDivElement, latest: Guess | undefined): void {
  if (!latest) {
    latestEl.replaceChildren(el("span", { class: "muted" }, [t("firstGuessHint")]));
    return;
  }
  if (latest.warmth === null) {
    latestEl.replaceChildren(el("span", { class: "word" }, [latest.word]), el("span", { class: "muted" }, [t("scoringDots")]));
    return;
  }
  const score = latest.warmth * 100;
  const chip = el("span", { class: "chip" }, [scoreLabel(score).label]);
  chip.style.background = scoreColorA(score, 0.18);
  chip.style.color = scoreColor(score);
  latestEl.replaceChildren(el("span", { class: "word" }, [latest.word]), chip);
}

// ════════════════════════════════════════════════════════════════════════════
//  LIVE MATCH
// ════════════════════════════════════════════════════════════════════════════

function screenDuel(): void {
  track("duel_open");
  clear("dark");
  // Launch-week ordering: live racing is the hero (bigger, first, with a real
  // player count); the friend's-ghost race stays, as the quieter second option.
  // "Race a friend" opens today's daily: a finished board already shows the
  // Race a friend share button, an unfinished one is where the run starts.
  const count = el("div", { class: "live-count" }, [""]);
  const hero = el("button", { class: "duel-hero live", onclick: () => { void playSound("tap"); screenLobby(); } }, [
    el("div", { class: "duel-hero-icon" }, ["⚡"]),
    el("div", { class: "duel-hero-title" }, [t("raceStrangerTitle")]),
    el("div", { class: "duel-hero-sub" }, [t("liveRaceBlurb")]),
    count,
    el("div", { class: "duel-hero-cta" }, [t("liveRaceNow")]),
  ]);
  const ghost = el("button", { class: "duel-choice race secondary", onclick: () => { void playSound("tap"); startDaily(); } }, [
    el("div", { class: "duel-choice-icon" }, ["🏁"]),
    el("div", { class: "duel-choice-text" }, [
      el("div", { class: "duel-choice-title" }, [t("raceAFriend")]),
      el("div", { class: "duel-choice-sub" }, [t("raceFriendBlurb")]),
    ]),
  ]);
  app.append(
    el("main", { class: "card" }, [
      el("div", { class: "solo-head" }, [
        el("button", { class: "icon-btn dark", onclick: goHome, title: "Home" }, ["←"]),
        el("span", { class: "solo-title dark" }, [t("duelRace")]),
        el("span", {}, [""]),
      ]),
      el("div", { class: "duel-choices" }, [hero, ghost]),
    ]),
  );
  // Honest numbers only: humans racing, humans waiting, or "no one", never an
  // implied opponent. Polled every 10 s; the route is cached 5 s server-side.
  const refresh = () => {
    fetchLiveCounts(httpBase).then((c) => {
      if (!count.isConnected) return;
      if (!c) { count.textContent = ""; return; }
      count.textContent =
        c.racing > 0 ? t("liveRacingNow", c.racing)
        : c.waiting > 0 ? t("liveOneWaiting")
        : t("liveNobodyQueueing");
    });
  };
  refresh();
  liveCountTimer = window.setInterval(refresh, 10_000);
}

function screenLobby(): void {
  clear("light");
  const codeInput = el("input", { class: "field", placeholder: "have a code? enter it", spellcheck: false });
  const join = () => {
    const c = codeInput.value.trim();
    if (!c) return toast("Enter the code your friend sent.");
    startLive("casual", c, false); // JOIN an existing invite
  };
  codeInput.addEventListener("keydown", (e) => { if (e.key === "Enter") join(); });
  app.append(
    el("main", { class: "card" }, [
      el("div", { class: "solo-head" }, [
        el("button", { class: "icon-btn dark", onclick: goHome, title: "Home" }, ["←"]),
        el("span", { class: "solo-title dark" }, ["Race"]),
        el("span", {}, [""]),
      ]),
      raw("mascot-wrap", mascotSVG({ score: null, size: 96, id: "lobby" })),
      el("p", { class: "center muted" }, ["Race someone to warm up to the same hidden word."]),
      el("button", { class: "btn primary", onclick: () => startLive("casual") }, ["⚡ Quick Match"]),
      el("button", { class: "btn secondary", onclick: hostRace }, ["👋 Invite a friend"]),
      el("div", { class: "lbl" }, ["Have a code?"]),
      el("div", { class: "row" }, [codeInput, el("button", { class: "btn secondary join", onclick: join }, ["Join"])]),
      el("p", { class: "hint" }, ["Invite makes a link to send. Quick Match finds anyone (or a practice flame)."]),
    ]),
  );
}

/** Host a Race: generate a code, host it, and offer the share link on the next screen. */
function hostRace(): void {
  startLive("casual", genCode(), true);
}

function startLive(mode: MatchMode, friendCode?: string, create?: boolean, opts?: { fillNow?: boolean }): void {
  live.opponentKind = null;
  live.snapshot = null;
  live.guesses = [];
  live.replies = [];
  live.opponentLeft = false;
  live.mode = mode;
  live.friendCode = friendCode;
  live.hosting = create === true;
  live.startsAt = null;
  live.client?.close();
  live.client = new WickMatchClient({
    serverBase,
    kid: live.kid,
    // "Race a flame now": the server expedites this queue so the next tick
    // bot-fills it instead of waiting for the shared start.
    query: opts?.fillNow ? { fill: "now" } : undefined,
    handlers: {
      onOpen: () => live.client?.queue(mode, friendCode, create),
      onPaired: (f) => { live.opponentKind = f.opponentKind; screenMatch(); },
      // Use the duration, not the server's wall time, so a skewed clock can't
      // show a countdown that is already over or an hour long.
      onQueued: (f) => { live.startsAt = Date.now() + f.waitMs; if (!live.snapshot) screenSearching(); },
      onState: (f) => { live.snapshot = f.state; if (document.querySelector("#hero")) renderMatch(); },
      onScored: (f) => {
        if (f.notAWord) {
          const i = live.guesses.findIndex((x) => normalize(x.word) === normalize(f.guess) && x.warmth === null);
          if (i >= 0) {
            live.guesses.splice(i, 1); // a non-word never counted — drop it
            toast("Hmm — that's not a word I know. Try another.");
            renderMatch();
          }
          return;
        }
        const g = live.guesses.find((x) => normalize(x.word) === normalize(f.guess) && x.warmth === null);
        if (g) { g.warmth = Math.max(0, Math.min(1, f.score / 100)); g.rank = f.rank ?? null; renderMatch(); }
      },
      onAnswer: (f) => {
        const r = live.replies.find((x) => x.question === f.question && x.pending);
        if (r) { r.verdict = f.verdict; r.reply = f.reply; r.pending = false; renderMatch(); }
      },
      onResult: (f) => screenResult(f.result, f.word),
      onOpponentLeft: () => { live.opponentLeft = true; renderMatch(); },
      onError: (e) => handleLiveError(e, create),
      onClose: ({ clean }) => { if (!clean && !live.snapshot) showError("Lost connection to the server."); },
    },
  });
  screenSearching();
  live.client.connect();
}

/** 3.1 invite errors: a code collision while hosting → regenerate + re-host (silent,
 *  astronomically rare); a dead/expired invite while joining → a friendly nudge. */
function handleLiveError(e: { code: string; message: string }, create?: boolean): void {
  if (e.code === "code_taken" && create) {
    startLive("casual", genCode(), true);
    return;
  }
  if (e.code === "no_such_invite") {
    toast("That invite's expired — ask your friend for a new link.");
    leaveLive();
    return;
  }
  showError(e.message);
}

function screenSearching(): void {
  clear("dark");
  const code = live.friendCode;
  const kids: (Node | string)[] = [
    raw("mascot-wrap", mascotSVG({ score: null, size: 128, id: "search" })),
    el("h2", {}, [live.hosting ? "Waiting for your friend…" : code ? "Joining…" : "Finding an opponent…"]),
  ];
  if (code && live.hosting) {
    kids.push(el("p", { class: "code" }, [code]));
    kids.push(
      el("button", { class: "btn primary", onclick: () => shareInvite(inviteURL(code, "race"), "Race me in Wick!") }, ["📤 Share invite link"]),
    );
    kids.push(el("p", { class: "hint" }, ["Send the link — your friend taps it to join. Or they can type the code."]));
    kids.push(qrImage(inviteURL(code, "race")));
    kids.push(el("p", { class: "hint" }, ["Or scan the code."]));
  } else if (code) {
    kids.push(el("p", { class: "code" }, [code]));
  } else if (live.startsAt !== null) {
    // 3.3 shared start: everyone in Quick Match counts down to the same
    // moment, so two people a minute apart still race each other. If someone
    // shows up sooner the server pairs early and `paired` replaces this screen.
    const clock = el("p", { class: "code" }, [fmtCountdown(live.startsAt)]);
    kids.push(el("p", { class: "center muted" }, [t("liveNextRaceIn")]));
    kids.push(clock);
    kids.push(el("p", { class: "center muted" }, [t("livePracticeFlameSteps")]));
    clockTimer = window.setInterval(() => { clock.textContent = fmtCountdown(live.startsAt ?? Date.now()); }, 250);
  } else {
    kids.push(el("p", { class: "center muted" }, [t("livePracticeFlameSteps")]));
  }
  // Never a dead-end spinner. After 15 s (20 s when hosting, since a friend
  // may still be tapping the link) offer two ways out: a bot race right now, or
  // the friend's-ghost race. Both leave this queue.
  const fallback = el("div", { class: "search-fallback", hidden: true }, [
    el("p", { class: "center muted" }, [t("searchStillLooking")]),
    el("button", { class: "btn primary", onclick: () => { void playSound("tap"); startLive("casual", undefined, undefined, { fillNow: true }); } }, [t("searchRaceFlame")]),
    el("button", { class: "btn secondary", onclick: () => { void playSound("tap"); live.client?.close(); live.client = null; startDaily(); } }, [t("searchRaceGhost")]),
  ]);
  kids.push(fallback);
  searchFallbackTimer = window.setTimeout(() => { fallback.removeAttribute("hidden"); }, live.hosting ? 20_000 : 15_000);
  kids.push(el("button", { class: "btn ghost", onclick: leaveLive }, ["Cancel"]));
  app.append(el("main", { class: "card" }, kids));
}

/** m:ss until `at`, clamped at 0:00. */
function fmtCountdown(at: number): string {
  const s = Math.max(0, Math.ceil((at - Date.now()) / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function screenMatch(): void {
  clear("dark");
  const input = el("input", { class: "field", placeholder: t("guessOrAskPlaceholder"), autocomplete: "off", spellcheck: false });
  const submit = () => {
    const text = input.value.trim();
    if (!text) return;
    // A question (space or "?") → ask Wick; the server answers on the room
    // secret and replies via `answer`. A single bare word → a guess.
    if (looksLikeQuestion(text)) {
      live.replies.unshift({ question: text, verdict: "", reply: "Wick is thinking…", pending: true });
      live.client?.ask(text);
      input.value = "";
      renderMatch();
      return;
    }
    // Warmth is scored by the server (authoritative); show "scoring…" until the
    // `scored` frame arrives — no misleading placeholder number.
    live.guesses.unshift({ word: text, warmth: null, correct: false });
    live.client?.guess(text);
    input.value = "";
    renderMatch();
  };
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
  app.append(
    el("main", { class: "card" }, [
      el("div", { id: "opp-strip", class: "opp-strip" }),
      el("div", { id: "hero", class: "hero" }),
      el("div", { id: "latest", class: "latest" }),
      el("div", { id: "clock", class: "clock" }),
      el("div", { id: "banner", class: "banner" }),
      el("div", { class: "guess-row" }, [
        input,
        el("button", { class: "send", onclick: submit, title: "Guess or ask" }, ["↑"]),
      ]),
      el("div", { id: "keeper", class: "keeper" }),
      el("div", { id: "live-log-head", class: "log-head" }),
      el("ul", { id: "my-guesses", class: "guesses" }),
    ]),
  );
  input.focus();
  renderMatch();
  clockTimer = window.setInterval(() => {
    const c = document.querySelector<HTMLDivElement>("#clock");
    if (c && live.snapshot) c.textContent = "⏱ " + fmtClock(Math.max(0, live.snapshot.clock.remainingMs));
  }, 250);
}

function renderMatch(): void {
  const snap = live.snapshot;
  const strip = document.querySelector<HTMLDivElement>("#opp-strip");
  if (strip) {
    const kind = live.opponentKind ?? "human";
    const label = kind === "human" ? t("liveLiveOpponent")
                : kind === "bot" ? t("livePracticeFlame")
                : t("liveGhost");
    const oppW = snap ? snap.opponent.bestWarmth : 0;
    const oppG = snap ? snap.opponent.guessCount : 0;
    const oppScore = oppG > 0 ? oppW * 100 : null;
    const bar = el("i");
    bar.style.width = `${Math.round(oppW * 100)}%`;
    bar.style.background = scoreColor(oppScore);
    strip.replaceChildren(
      raw("mini", mascotSVG({ score: oppScore, size: 46, id: "opp" })),
      el("div", { class: "opp-info" }, [
        el("div", { class: "opp-top" }, [
          el("span", { class: `tag ${kind}` }, [label]),
          el("span", { class: "opp-count" }, [t("liveGuessesCount", oppG)]),
        ]),
        el("div", { class: "mini-bar" }, [bar]),
      ]),
    );
  }
  const latest = live.guesses[0];
  setBackdropHeat(bestScore(live.guesses));
  renderHero("#hero", "you", latest);
  const latestEl = document.querySelector<HTMLDivElement>("#latest");
  if (latestEl) renderLatestChip(latestEl, latest);
  // Wick's most recent in-match answer (if any).
  const reply = live.replies[0];
  if (reply) showKeeper(reply.verdict, reply.reply);
  renderSortHead("#live-log-head", live.guesses.length > 0, renderMatch);
  renderGuessList("#my-guesses", soloSortHottest ? sortGuessesHottest(live.guesses) : live.guesses);
  const banner = document.querySelector<HTMLDivElement>("#banner");
  if (banner && live.opponentLeft) {
    banner.textContent = t("liveOppLeftHangTight");
    banner.classList.add("show");
  }
}

function screenResult(result: MatchResult, word?: string): void {
  clear("dark");
  const me = result.players.find((p) => p.id === live.kid);
  const youWon = result.winner === live.kid;
  const headline = result.draw ? "A friendly draw" : youWon ? "You warmed up first!" : "So close — they got there first.";
  const reason: Record<MatchResult["reason"], string> = {
    solved: "Solved the word",
    timeout: "Time ran out — decided on warmth",
    forfeit: "Opponent left",
    void: "Match voided",
  };

  // Winner → green happy Wick; loser → grey "-_-" deadpan Wick (never the blue
  // sad face); draw → resting purple.
  const mascot = result.draw
    ? mascotSVG({ score: null, size: 128, id: "result" })
    : youWon
      ? mascotSVG({ score: 100, size: 128, id: "result" })
      : mascotSVG({ score: null, neutral: true, size: 128, id: "result" });

  // The word is revealed to BOTH players — winner in green, loser in red.
  const revealColor = result.draw ? "rgb(125,92,235)" : youWon ? "rgb(77,158,71)" : "rgb(232,66,54)";
  const reveal = el("div", { class: "reveal" }, [
    el("p", { class: "center muted reveal-label" }, [t("theWordWas")]),
  ]);
  if (word) {
    const w = el("p", { class: "reveal-word" }, [word]);
    w.style.color = revealColor;
    reveal.append(w);
  }

  app.append(
    el("main", { class: "card" }, [
      raw("mascot-wrap", mascot),
      el("h2", {}, [headline]),
      el("p", { class: "center muted" }, [reason[result.reason]]),
      me
        ? el("p", { class: "center" }, [
            me.solvedAtMs !== null
              ? `You solved in ${(me.solvedAtMs / 1000).toFixed(1)}s, ${me.guessCount} guesses.`
              : `${me.guessCount} guesses, best warmth ${Math.round(me.bestWarmth * 100)}%.`,
          ])
        : el("p", { class: "center muted" }, ["Match over."]),
      ...(word ? [reveal] : []),
      el("button", { class: "btn primary", onclick: () => startLive(live.mode, live.friendCode) }, [live.friendCode ? "Rematch" : "Play again"]),
      el("button", { class: "btn ghost", onclick: () => { leaveLive(); } }, ["Home"]),
    ]),
  );

  if (youWon && !result.draw) launchConfetti();
}

/** A generous confetti burst over the whole viewport (winner celebration). */
function launchConfetti(count = 160): void {
  const layer = document.createElement("div");
  layer.className = "confetti-layer";
  const colors = ["#4d9e47", "#e84236", "#ed6b2e", "#f2a624", "#7d5ceb", "#f0b030", "#59bdb5"];
  for (let i = 0; i < count; i++) {
    const bit = document.createElement("i");
    bit.className = "confetti-bit";
    const size = 6 + Math.random() * 9;
    bit.style.left = Math.random() * 100 + "vw";
    bit.style.width = size + "px";
    bit.style.height = size * (0.4 + Math.random() * 0.8) + "px";
    bit.style.background = colors[Math.floor(Math.random() * colors.length)]!;
    bit.style.opacity = String(0.75 + Math.random() * 0.25);
    bit.style.animationDuration = 1.8 + Math.random() * 2.0 + "s";
    bit.style.animationDelay = Math.random() * 0.7 + "s";
    layer.appendChild(bit);
  }
  document.body.appendChild(layer);
  window.setTimeout(() => layer.remove(), 5000);
}

function leaveLive(): void {
  live.client?.close();
  live.client = null;
  screenHome();
}

function showError(message: string): void {
  clear("dark");
  app.append(
    el("main", { class: "card" }, [
      raw("mascot-wrap", mascotSVG({ score: 5, size: 120, id: "err" })),
      el("h2", {}, ["Something went sideways"]),
      el("p", { class: "center muted" }, [message]),
      el("button", { class: "btn primary", onclick: goHome }, [t("back")]),
    ]),
  );
}

// ── shared ──
function guessRowEl(g: Guess): HTMLElement {
  const pending = g.warmth === null;
  const fill = el("i");
  fill.style.width = pending ? "0%" : `${Math.round(g.warmth! * 100)}%`;
  if (!pending) fill.style.background = scoreColor(g.warmth! * 100);
  return el("li", { class: "guess-item" }, [
    el("span", { class: "gw" }, [g.word]),
    el("span", { class: "gb" }, [fill]),
    el("span", { class: pending ? "gp muted" : "gp" }, [heatText(g)]),
  ]);
}
function renderGuessList(sel: string, guesses: Guess[]): void {
  const list = document.querySelector<HTMLUListElement>(sel);
  if (!list) return;
  list.replaceChildren(...guesses.map(guessRowEl));
}

function fmtClock(ms: number): string {
  const total = Math.ceil(ms / 1000);
  return `${Math.floor(total / 60)}:${(total % 60).toString().padStart(2, "0")}`;
}

// ── boot ──
//  A shared invite link lands at guesswick.com/p/<code>?m=… , which the server
//  redirects to "/?p=<code>&m=…". Read that here and drop straight into the match.
//  No app needed; anyone with the link can play. Dare links (m=dare) were retired
//  in 3.3: they land on Home with a short note instead of a dead match.
function boot(): void {
  mountBackdrop();
  initEvents(httpBase, live.kid);
  // Browsers refuse to start audio outside a user gesture, so the AudioContext
  // is only built on the first real tap or keypress.
  armAudioUnlock();
  scheduleReminder();
  const params = new URLSearchParams(location.search);

  // A ghost-race link. Parsed and held; the strip that renders it lands in the
  // next phase, so a link is currently inert rather than broken.
  // Accept both: /r/<run> (current, app-openable) and ?r=<run> (older links).
  const pathRun = /^\/r\/(.+)$/.exec(location.pathname)?.[1];
  const r = (pathRun ?? params.get("r") ?? "").trim();
  if (r) {
    pendingGhost = decodeRun(r);
    // "/" not location.pathname: for a /r/<run> link the pathname IS the run, so
    // reusing it would leave the whole payload sitting in the address bar.
    history.replaceState(null, "", "/");
    if (pendingGhost) {
      screenChallenge(pendingGhost);
      return;
    } else {
      console.warn("[wick] ghost link was malformed — ignored");
    }
  }

  const code = params.get("p")?.trim();
  const m = params.get("m");
  if (code) {
    // Clean the URL so a refresh doesn't try to rejoin a now-consumed invite.
    history.replaceState(null, "", location.pathname);
    if (m === "dare") {
      screenHome();
      toast(t("dareRetired"));
      return;
    }
    startLive("casual", code, false);
    return;
  }
  screenHome();
}
boot();
