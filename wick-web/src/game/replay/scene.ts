//
//  scene.ts: Solve Replay (3.4) for the web: drawing one frame.
//
//  A port of Hunch/Replay/ReplayScene.swift to Canvas 2D. `draw(ctx, t)`
//  paints the frame for time t on a 1080 x 1920 canvas; the same moment always
//  gives the same picture. KEEP IN LOCKSTEP with the Swift file: same layout
//  numbers, same Wick, same effects.
//
//  The board keeps clear of the right edge and the bottom, where TikTok, Reels
//  and Shorts put their buttons and captions.
//
//  Keeper questions show their text in Wick's bubble on every round; only the
//  guessed words follow the spoiler rule.
//
//  Guessed words come from the timeline's tile labels, which are already
//  masked for a daily round (timeline.ts, SPOILER_RANK_LIMIT). The answer is
//  drawn only when the timeline's showAnswer flag is set AND the label is
//  present, so a daily replay never contains the answer in any frame.
//

import {
  type Band, type Board, type Rect, type Tile, type Timeline, type VerdictTone,
  beatEnd, beatIndex, bestRank, bestTile, boardFrame, bandForRank, duration,
  finalSlot, formatRank, guessesShown, landedCount, makeBoard, meterFill, slotCenter,
  slotRect, tileBand, totalGuesses, wickTravel,
} from "./timeline.ts";

export const W = 1080;
export const H = 1920;
/** Clear of the title bar above and of short-video app buttons and captions. */
const BOARD_AREA: Rect = { x: 120, y: 480, w: 840, h: 940 };

// Chinese fonts go last so zh captions do not fall back to boxes.
const FONT = "ui-rounded, 'SF Pro Rounded', -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, 'PingFang SC', 'Noto Sans SC', 'Microsoft YaHei', sans-serif";

/** Mirrors HunchTheme (Palette + rankColor) and RevealShareCard's inks. */
const C = {
  ink: "#0F121A",
  inkLift: "#1C1A26",
  wall: "#16151F",
  onInk: "#F2F2FA",
  onInkDim: "#9E9EB3",
  violet: "#7D5CEB",
  violetLight: "#B8A6F4",
  gold: "#EDB02E",
  goldLight: "#F6D896",
  neutral: "#737380",
  solved: "#4D9E47",
  cold: "#4585E6",
  cool: "#21A18C",
  warm: "#F2A624",
  hot: "#ED6B2E",
  boiling: "#E84236",
};

function bandColor(b: Band): string {
  return b === "solved" ? C.gold : C[b];
}

function verdictColor(tone: VerdictTone): string {
  return tone === "yes" ? C.solved : tone === "no" ? C.boiling : tone === "sortOf" ? C.warm : C.neutral;
}

/** Every piece of on-video text, already localized. */
export interface ReplayCopy {
  title: string;        // "Wick #1359"
  tagline: string;      // "Ask 20 questions, race to reveal the secret word"
  stats: string;        // "solved in 12"
  best: string;         // "Best"
  guessOf: (n: number, total: number) => string;
  fastForward: (n: number) => string;
  revealed: string;
  playFree: string;     // "Play free at"
  /** 3.5: "Can you beat 14? Play free at", only on a solved daily, where a
   *  viewer can play the same puzzle. Absent falls back to `playFree`. */
  challenge?: string;
  domain: string;       // "guesswick.com"
  bandName: (b: Band) => string;
  /** "The word was %@", for the practice end card. */
  answerWas: (word: string) => string;
}

/** Guess tiles narrower than this print the rank only. */
const MIN_TILE_FOR_WORD = 60;
/** Narrower still, and the tile is color only. */
const MIN_TILE_FOR_RANK = 52;
/** Three dots stand in for a masked word. */
const MASKED_WORD = "\u2022\u2022\u2022";

// ── easing ──────────────────────────────────────────────────────────────────

const clamp = (x: number): number => Math.min(1, Math.max(0, x));
const easeIn = (x: number): number => x * x;
const easeOut = (x: number): number => 1 - (1 - x) * (1 - x);
const easeInOut = (x: number): number => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2);
const easeOutBack = (x: number): number => {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
};

/** "#rrggbb" + alpha → rgba(). */
function alpha(hex: string, a: number): string {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
}

/** Darken a "#rrggbb" by factor k. */
function shade(hex: string, k: number): string {
  const n = parseInt(hex.slice(1), 16);
  const f = (v: number) => Math.round(v * k);
  return `rgb(${f((n >> 16) & 255)}, ${f((n >> 8) & 255)}, ${f(n & 255)})`;
}

/** Mix a "#rrggbb" toward white by f. */
function tint(hex: string, f: number): string {
  const n = parseInt(hex.slice(1), 16);
  const m = (v: number) => Math.round(v + (255 - v) * f);
  return `rgb(${m((n >> 16) & 255)}, ${m((n >> 8) & 255)}, ${m(n & 255)})`;
}

type Look = "idle" | "thinking" | "celebrating" | "defeated" | Band;

type Ctx = CanvasRenderingContext2D;

// ── the scene ───────────────────────────────────────────────────────────────

export class ReplayScene {
  readonly board: Board;
  readonly duration: number;
  private readonly wickSize: number;
  private boardCache: { settled: number; canvas: HTMLCanvasElement } | null = null;

  constructor(
    private readonly tl: Timeline,
    private readonly copy: ReplayCopy,
    private readonly maxRank: number,
  ) {
    this.board = makeBoard(tl.tiles.length, BOARD_AREA);
    this.wickSize = Math.min(160, Math.max(84, this.board.cell * 0.74));
    this.duration = duration(tl);
  }

  draw(ctx: Ctx, t: number): void {
    ctx.save();
    ctx.fillStyle = C.ink;
    ctx.fillRect(0, 0, W, H);
    const glow = ctx.createRadialGradient(540, 120, 0, 540, 120, 1100);
    glow.addColorStop(0, alpha(C.violet, 0.22));
    glow.addColorStop(1, alpha(C.violet, 0));
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);

    const shake = this.shakeOffset(t);
    ctx.save();
    ctx.translate(shake.x, shake.y);
    this.drawBoard(ctx, t, clamp((t - 0.2) / 0.5));
    this.drawRings(ctx, t);
    this.drawWickOnBoard(ctx, t);
    this.drawSparkBurst(ctx, t);
    this.drawKeeperBubble(ctx, t);
    ctx.restore();

    this.drawHUD(ctx, t, clamp(t / 0.45));
    this.drawFlash(ctx, t);
    this.drawBurstBadge(ctx, t);
    this.drawEndCard(ctx, t);
    ctx.restore();
  }

  // ── board ────────────────────────────────────────────────────────────────

  private drawBoard(ctx: Ctx, t: number, a: number): void {
    if (a <= 0) return;
    const settled = this.settledPrefix(t);
    let cache = this.boardCache;
    if (!cache || cache.settled !== settled) {
      cache = { settled, canvas: this.makeBoardImage(settled) };
      this.boardCache = cache;
    }
    ctx.save();
    ctx.globalAlpha = a;
    ctx.drawImage(cache.canvas, 0, 0);
    const landed = landedCount(this.tl, t);
    for (let s = settled; s < landed; s++) {
      const tile = this.tl.tiles[s]!;
      const dt = t - tile.landsAt;
      this.drawTile(ctx, tile, this.popScale(dt, this.isBig(tile)), this.glowAmount(tile, dt));
    }
    this.drawBestRing(ctx, t);
    this.drawSolveWave(ctx, t);
    ctx.restore();
  }

  private settledPrefix(t: number): number {
    let n = 0;
    for (const tile of this.tl.tiles) {
      if (tile.slot >= finalSlot(this.tl)) break;
      if (t < tile.landsAt + this.settleTime(tile)) break;
      n++;
    }
    return n;
  }

  private makeBoardImage(settled: number): HTMLCanvasElement {
    const canvas = document.createElement("canvas");
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext("2d")!;
    const cell = this.board.cell;
    const f = boardFrame(this.board);
    const pad = cell * 0.16;
    const wall: Rect = { x: f.x - pad, y: f.y - pad, w: f.w + pad * 2, h: f.h + pad * 2 };
    roundRect(ctx, wall, cell * 0.3);
    ctx.fillStyle = C.wall;
    ctx.fill();
    ctx.strokeStyle = alpha(C.violet, 0.38);
    ctx.lineWidth = Math.max(4, cell * 0.05);
    ctx.stroke();

    for (let slot = 0; slot < this.board.count; slot++) {
      const r = inset(slotRect(this.board, slot), cell * 0.07);
      roundRect(ctx, r, r.w * 0.2);
      ctx.fillStyle = C.inkLift;
      ctx.fill();
      if (slot === finalSlot(this.tl)) {
        roundRect(ctx, inset(r, r.w * 0.12), r.w * 0.16);
        ctx.strokeStyle = alpha(C.gold, 0.45);
        ctx.lineWidth = Math.max(3, cell * 0.04);
        ctx.stroke();
      } else {
        const d = Math.max(4, cell * 0.09);
        ctx.fillStyle = alpha(C.violet, 0.35);
        ctx.beginPath();
        ctx.arc(r.x + r.w / 2, r.y + r.h / 2, d / 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    for (let s = 0; s < settled; s++) this.drawTile(ctx, this.tl.tiles[s]!, 1, 0);
    return canvas;
  }

  private isBig(tile: Tile): boolean {
    return tile.kind === "answer" || tile.emphasis?.kind === "bigJump";
  }

  private settleTime(tile: Tile): number {
    return this.isBig(tile) ? 1.2 : 0.32;
  }

  private popScale(dt: number, big: boolean): number {
    if (dt <= 0) return 0;
    if (!big) return dt >= 0.32 ? 1 : easeOutBack(dt / 0.32);
    if (dt >= 0.6) return 1;
    const x = dt / 0.6;
    if (x < 0.35) return 1.45 * easeOut(x / 0.35);
    return 1 + 0.45 * (1 - easeInOut((x - 0.35) / 0.65));
  }

  private glowAmount(tile: Tile, dt: number): number {
    if (dt <= 0) return 0;
    if (tile.kind === "answer") return 0.65 + 0.35 * Math.sin((dt * 2 * Math.PI) / 1.2);
    if (tile.emphasis?.kind === "bigJump") return Math.max(0, 1 - dt / 1.2);
    return 0;
  }

  private drawTile(ctx: Ctx, tile: Tile, scale: number, glow: number): void {
    if (scale <= 0.01) return;
    const cell = slotRect(this.board, tile.slot);
    const base = inset(cell, cell.w * 0.07);
    const w = base.w * scale, h = base.h * scale;
    const r: Rect = { x: base.x + base.w / 2 - w / 2, y: base.y + base.h / 2 - h / 2, w, h };
    const radius = r.w * 0.2;
    const color = tile.kind === "answer" ? C.gold : tile.kind === "revealed" ? C.neutral : bandColor(tileBand(tile));

    // Darker lip along the bottom: reads as a crate.
    roundRect(ctx, r, radius);
    ctx.fillStyle = shade(color, 0.6);
    ctx.fill();

    const face: Rect = { x: r.x, y: r.y, w: r.w, h: r.h * 0.9 };
    ctx.save();
    if (glow > 0) {
      ctx.shadowColor = alpha(color, 0.9);
      ctx.shadowBlur = this.board.cell * 0.55 * glow;
    }
    roundRect(ctx, face, radius);
    ctx.fillStyle = color;
    ctx.fill();
    ctx.restore();

    const shine: Rect = { x: face.x + face.w * 0.1, y: face.y + face.h * 0.08, w: face.w * 0.8, h: face.h * 0.16 };
    roundRect(ctx, shine, shine.h / 2);
    ctx.fillStyle = "rgba(255,255,255,0.16)";
    ctx.fill();

    const cx = face.x + face.w / 2, cy = face.y + face.h / 2;
    const wordRoom = base.w >= MIN_TILE_FOR_WORD;
    // Two lines: the word (or what stands in for it) above, the rank below.
    const wordY = cy - face.h * 0.13, rankY = cy + face.h * 0.17;
    const maxW = base.w * 0.86 * scale;
    const wordSize = Math.max(14, base.w * 0.21) * scale;
    const minWordSize = Math.max(11, base.w * 0.12) * scale;
    const rankSize = Math.max(13, base.w * 0.19) * scale;

    if (tile.kind === "answer") {
      const word = this.tl.showAnswer ? tile.label : null;
      if (wordRoom && word) {
        this.fitText(ctx, word, cx, wordY, wordSize, minWordSize, 800, "#fff", maxW);
        starPath(ctx, cx, rankY, face.w * 0.14, 5);
      } else if (wordRoom) {
        this.checkmark(ctx, cx, wordY, face.w * 0.22 * scale);
        starPath(ctx, cx, rankY, face.w * 0.14, 5);
      } else {
        starPath(ctx, cx, cy, face.w * 0.26, 5);
      }
      ctx.fillStyle = "#fff";
      ctx.fill();
    } else if (tile.kind === "revealed") {
      const word = this.tl.showAnswer ? tile.label : null;
      if (wordRoom && word) {
        this.fitText(ctx, word, cx, wordY, wordSize, minWordSize, 800, "#fff", maxW);
        this.text(ctx, "?", cx, rankY, rankSize, 800, "#fff", "center", undefined, 0.9);
      } else if (base.w >= 40) {
        this.text(ctx, "?", cx, cy, base.w * 0.86 * 0.27 * 1.6 * scale, 800, "#fff", "center", undefined, 0.9);
      }
    } else if (wordRoom) {
      const word = tile.masked ? MASKED_WORD : tile.label;
      const under = tile.exact ? formatRank(tile.rank) : this.copy.bandName(tileBand(tile));
      if (word) {
        this.fitText(ctx, word, cx, wordY, wordSize, minWordSize, 800, "#fff", maxW);
        this.text(ctx, under, cx, rankY, rankSize, 700, "rgba(255,255,255,0.85)", "center", maxW);
      } else if (tile.exact) {
        this.text(ctx, formatRank(tile.rank), cx, cy, Math.max(16, base.w * 0.27) * scale, 800, "#fff", "center", maxW);
      }
    } else if (base.w >= MIN_TILE_FOR_RANK && tile.exact) {
      this.text(ctx, formatRank(tile.rank), cx, cy, Math.max(16, base.w * 0.27) * scale, 800, "#fff", "center", maxW);
    }
  }

  /** A simple check, centered on (cx, cy), about `size` wide. */
  private checkmark(ctx: Ctx, cx: number, cy: number, size: number): void {
    ctx.save();
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = Math.max(3, size * 0.2);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(cx - size * 0.5, cy + size * 0.02);
    ctx.lineTo(cx - size * 0.15, cy + size * 0.34);
    ctx.lineTo(cx + size * 0.5, cy - size * 0.3);
    ctx.stroke();
    ctx.restore();
  }

  private drawBestRing(ctx: Ctx, t: number): void {
    const tile = bestTile(this.tl, t);
    if (!tile || tile.rank <= 1) return;
    const r = inset(slotRect(this.board, tile.slot), this.board.cell * 0.03);
    roundRect(ctx, r, r.w * 0.24);
    ctx.strokeStyle = "rgba(255,255,255,0.6)";
    ctx.lineWidth = Math.max(3, this.board.cell * 0.035);
    ctx.stroke();
  }

  /** Solved: a wave of light runs along the path. */
  private drawSolveWave(ctx: Ctx, t: number): void {
    const last = this.tl.tiles[this.tl.tiles.length - 1];
    if (this.tl.outcome !== "solved" || !last) return;
    const start = last.landsAt + 0.15;
    if (t <= start) return;
    const n = Math.max(1, this.tl.tiles.length - 1);
    const step = Math.min(0.05, 1.2 / n);
    for (const tile of this.tl.tiles.slice(0, -1)) {
      const x = (t - start - tile.slot * step) / 0.35;
      if (x <= 0 || x >= 1) continue;
      const r = inset(slotRect(this.board, tile.slot), this.board.cell * 0.07);
      roundRect(ctx, r, r.w * 0.2);
      ctx.fillStyle = `rgba(246, 216, 150, ${0.55 * Math.sin(Math.PI * x)})`;
      ctx.fill();
    }
  }

  private drawRings(ctx: Ctx, t: number): void {
    for (const tile of this.tl.tiles) {
      if (!this.isBig(tile)) continue;
      const color = tile.kind === "answer" ? C.gold : bandColor(tileBand(tile));
      for (const delay of [0, 0.18]) {
        const e = (t - tile.landsAt - delay) / 0.9;
        if (e <= 0 || e >= 1) continue;
        const c = slotCenter(this.board, tile.slot);
        ctx.strokeStyle = alpha(color, 0.85 * (1 - e));
        ctx.lineWidth = 2 + 10 * (1 - e);
        ctx.beginPath();
        ctx.arc(c.x, c.y, this.board.cell * (0.5 + 1.9 * e), 0, Math.PI * 2);
        ctx.stroke();
      }
    }
  }

  private drawSparkBurst(ctx: Ctx, t: number): void {
    const last = this.tl.tiles[this.tl.tiles.length - 1];
    if (this.tl.outcome !== "solved" || !last) return;
    const dt = t - last.landsAt;
    if (dt <= 0 || dt >= 1.4) return;
    const c = slotCenter(this.board, last.slot);
    const e = dt / 1.4;
    for (let i = 0; i < 16; i++) {
      const angle = (i / 16) * 2 * Math.PI + 0.3;
      const speed = 260 + ((i * 37) % 5) * 40;
      const dist = speed * easeOut(e);
      sparklePath(ctx, c.x + Math.cos(angle) * dist, c.y + Math.sin(angle) * dist + 120 * e * e, 22 * (1 - e) + 6);
      ctx.fillStyle = alpha(C.gold, 1 - e);
      ctx.fill();
    }
  }

  private shakeOffset(t: number): { x: number; y: number } {
    for (let i = this.tl.tiles.length - 1; i >= 0; i--) {
      const tile = this.tl.tiles[i]!;
      if (!this.isBig(tile)) continue;
      const dt = t - tile.landsAt;
      if (dt < 0) continue;
      if (dt >= 0.45) break;
      const amp = 16 * (1 - dt / 0.45);
      return { x: Math.sin(dt * 70) * amp, y: Math.cos(dt * 55) * amp * 0.6 };
    }
    return { x: 0, y: 0 };
  }

  // ── Wick on the board ────────────────────────────────────────────────────

  private wickLook(t: number): Look {
    const last = this.tl.tiles[this.tl.tiles.length - 1];
    if (last && t >= last.landsAt) return this.tl.outcome === "solved" ? "celebrating" : "defeated";
    const beat = this.tl.beats[beatIndex(this.tl, t)];
    if (beat?.kind.kind === "keeper") return "thinking";
    const best = bestRank(this.tl, t);
    return best === null ? "idle" : bandForRank(best);
  }

  private placement(t: number): { gx: number; gy: number; lift: number; squash: number; dir: number } {
    const travel = wickTravel(this.tl, t);
    const a = slotCenter(this.board, travel.from), b = slotCenter(this.board, travel.to);
    const p = easeInOut(travel.progress);
    const footDrop = this.board.cell * 0.2;
    let gx = a.x + (b.x - a.x) * p;
    let gy = a.y + (b.y - a.y) * p + footDrop;
    let lift = 0;
    let squash = 1;
    const dir = travel.from === travel.to ? 0 : Math.sign(b.x - a.x);

    if (travel.from !== travel.to) {
      lift = Math.sin(Math.PI * travel.progress) * Math.max(26, this.board.cell * 0.42);
    } else {
      for (const tile of this.tl.tiles) {
        const lead = tile.landsAt - t;
        if (lead > 0 && lead <= 0.12) { squash = 1 - 0.14 * (1 - lead / 0.12); break; }
        const after = t - (tile.landsAt + tile.hop);
        if (tile.hop > 0 && after >= 0 && after < 0.14) squash = 1 - 0.12 * (1 - after / 0.14);
      }
    }

    if (t < 1.2) {
      lift = (1 - easeIn(clamp((t - 0.5) / 0.45))) * 460;
      if (t >= 0.95) squash = 1 - 0.18 * Math.sin(Math.PI * clamp((t - 0.95) / 0.25));
      const c0 = slotCenter(this.board, 0);
      gx = c0.x;
      gy = c0.y + footDrop;
    }

    const last = this.tl.tiles[this.tl.tiles.length - 1];
    if (last) {
      const dt = t - last.landsAt;
      if (dt > 0) {
        lift += this.popScale(dt, this.isBig(last)) * this.board.cell * 0.08;
        if (this.tl.outcome === "solved") lift += Math.max(0, Math.sin((dt * 2 * Math.PI) / 0.8)) * this.board.cell * 0.12;
      }
    }
    return { gx, gy, lift, squash, dir };
  }

  private drawWickOnBoard(ctx: Ctx, t: number): void {
    if (t < 0.5) return;
    const p = this.placement(t);
    const s = this.wickSize;
    const shrink = 1 - Math.min(0.5, p.lift / 400);
    ctx.fillStyle = "rgba(0,0,0,0.42)";
    ctx.beginPath();
    ctx.ellipse(p.gx, p.gy, (s * 0.62 * shrink) / 2, (s * 0.16 * shrink) / 2, 0, 0, Math.PI * 2);
    ctx.fill();
    this.drawWick(ctx, p.gx, p.gy - p.lift, s, this.wickLook(t), t, p.squash, p.dir, p.lift < 1);
  }

  // ── Wick ─────────────────────────────────────────────────────────────────

  private bodyColor(look: Look): string {
    if (look === "idle" || look === "thinking") return C.violet;
    if (look === "celebrating" || look === "solved") return C.solved;
    if (look === "defeated") return C.neutral;
    return bandColor(look);
  }

  private bobPeriod(look: Look): number {
    switch (look) {
      case "idle": case "thinking": return 1.8;
      case "celebrating": case "solved": case "hot": return 0.8;
      case "defeated": return 2.8;
      case "cold": return 2.6;
      case "cool": return 2.2;
      case "warm": return 1.2;
      case "boiling": return 0.55;
    }
  }

  /** Wick with his feet at (fx, fy). Same proportions as KeeperView. */
  private drawWick(ctx: Ctx, fx: number, fy: number, s: number, look: Look, t: number,
    squash: number, dir: number, standing: boolean): void {
    const h = s * 1.18;
    const period = this.bobPeriod(look);
    const bob = standing ? Math.sin((t * 2 * Math.PI) / period) * s * 0.03 : 0;
    const flicker = 0.5 + 0.5 * Math.sin((t * 2 * Math.PI) / (period * 0.8));
    const body = this.bodyColor(look);

    ctx.save();
    ctx.translate(fx, fy + bob);
    ctx.scale(1 + (1 - squash) * 0.9, squash);

    const rect: Rect = { x: -s / 2, y: -h, w: s, h };
    // Glow.
    ctx.save();
    ctx.shadowColor = alpha(body.startsWith("#") ? body : C.violet, look === "defeated" ? 0.1 : 0.6);
    ctx.shadowBlur = s * 0.35;
    flamePath(ctx, rect, flicker);
    ctx.fillStyle = body;
    ctx.fill();
    ctx.restore();

    // Body gradient, lighter at the tip.
    const g = ctx.createLinearGradient(0, -h, 0, 0);
    g.addColorStop(0, tint(body, 0.12));
    g.addColorStop(1, shade(body, 0.88));
    flamePath(ctx, rect, flicker);
    ctx.fillStyle = g;
    ctx.fill();

    // Inner core highlight.
    flamePath(ctx, { x: (-s * 0.55) / 2, y: -h * 0.55 - s * 0.04, w: s * 0.55, h: h * 0.55 }, flicker);
    ctx.fillStyle = `rgba(255,255,255,${look === "defeated" ? 0.08 : 0.22})`;
    ctx.fill();

    // Face.
    const faceY = -h / 2 + s * 0.16;
    const eyeY = faceY - s * 0.115;
    const mouthY = faceY + s * 0.0925;
    const gaze = dir * s * 0.03;
    const ew = s * 0.115;
    const blinking = (t + 0.7) % 3.3 < 0.12 && look !== "celebrating" && look !== "defeated";
    for (const side of [-1, 1]) this.drawEye(ctx, side * s * 0.1375 + gaze, eyeY, ew, look, blinking);
    this.drawMouth(ctx, gaze * 0.5, mouthY, s, look);

    if (look === "celebrating") {
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * 2 * Math.PI;
        const phase = (Math.sin((t * 2 * Math.PI) / 0.6 - i * 0.75) + 1) / 2;
        sparklePath(ctx, Math.cos(a) * s * 0.62, -h / 2 + Math.sin(a) * s * 0.62, s * 0.07);
        ctx.fillStyle = alpha(C.gold, 0.25 + 0.75 * phase);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  private drawEye(ctx: Ctx, x: number, y: number, ew: number, look: Look, blinking: boolean): void {
    ctx.fillStyle = "#fff";
    const oval = (w: number, hh: number, dx = 0, dy = 0) => {
      ctx.beginPath();
      ctx.ellipse(x + dx, y + dy, w / 2, hh / 2, 0, 0, Math.PI * 2);
      ctx.fill();
    };
    if (look === "celebrating") { starPath(ctx, x, y, ew * 0.85, 5); ctx.fill(); }
    else if (look === "defeated") oval(ew, ew * 0.22);
    else if (look === "thinking") oval(ew, blinking ? ew * 0.18 : ew, ew * 0.18, -ew * 0.22);
    else if (look === "cold") oval(ew, blinking ? ew * 0.18 : ew * 0.45);
    else if (look === "hot" || look === "boiling") oval(ew * 1.18, blinking ? ew * 0.18 : ew * 1.18);
    else oval(ew, blinking ? ew * 0.18 : ew);
  }

  private drawMouth(ctx: Ctx, x: number, y: number, s: number, look: Look): void {
    const mw = s * 0.16;
    const white = "rgba(255,255,255,0.9)";
    const arc = (radius: number, a: number, b: number, dy: number) => {
      ctx.beginPath();
      ctx.arc(x, y + dy, radius, a, b);
      ctx.strokeStyle = white;
      ctx.lineWidth = s * 0.028;
      ctx.lineCap = "round";
      ctx.stroke();
    };
    if (look === "celebrating" || look === "boiling" || look === "solved") {
      // Open, delighted: the lower half of a disc.
      ctx.beginPath();
      ctx.arc(x, y - mw * 0.1, mw / 2, 0, Math.PI);
      ctx.closePath();
      ctx.fillStyle = white;
      ctx.fill();
    } else if (look === "hot" || look === "warm") arc(mw / 2, 0.15 * Math.PI, 0.85 * Math.PI, -mw * 0.25);
    else if (look === "cold" || look === "cool") arc(mw * 0.4, 1.15 * Math.PI, 1.85 * Math.PI, mw * 0.35);
    else if (look === "thinking") {
      ctx.beginPath();
      ctx.arc(x + mw * 0.22, y, mw * 0.17, 0, Math.PI * 2);
      ctx.fillStyle = white;
      ctx.fill();
    } else if (look === "defeated") {
      ctx.fillStyle = "rgba(255,255,255,0.7)";
      ctx.fillRect(x - mw * 0.35, y - s * 0.0125, mw * 0.7, s * 0.025);
    } else arc(mw * 0.4, 0.2 * Math.PI, 0.8 * Math.PI, -mw * 0.2);
  }

  // ── Keeper bubble ────────────────────────────────────────────────────────

  private drawKeeperBubble(ctx: Ctx, t: number): void {
    const beat = this.tl.beats[beatIndex(this.tl, t)];
    if (!beat || beat.kind.kind !== "keeper") return;
    const verdicts = beat.kind.verdicts;
    const local = t - beat.start;
    const appear = local < 0.2 ? easeOutBack(local / 0.2) : 1;
    const fade = clamp((beatEnd(beat) - t) / 0.15);
    if (appear <= 0.01 || fade <= 0) return;

    // One row per question: the text, then its verdict chip. Rounds saved
    // before question text travelled show chips only, in one row.
    const chipH = 64, gap = 14, pad = 20, textChipGap = 18, textMax = 560;
    const shown = verdicts.slice(0, 3);
    const extra = verdicts.length > 3 ? `+${verdicts.length - 3}` : null;
    const hasText = shown.some((v) => !!v.question);
    ctx.font = `800 36px ${FONT}`;
    const chipW = (label: string): number => ctx.measureText(label).width + 44;
    const rows: { question: string | null; chip: string; color: string; chipW: number; textW: number }[] = shown.map((v) => {
      const chip = v.label.toUpperCase();
      const q = v.question ? this.fitted(ctx, v.question, 34, 24, 600, textMax) : null;
      return { question: q?.text ?? null, chip, color: verdictColor(v.tone), chipW: chipW(chip), textW: q?.width ?? 0 };
    });
    if (extra) rows.push({ question: null, chip: extra, color: C.neutral, chipW: chipW(extra), textW: 0 });
    let bw: number, bh: number;
    if (hasText) {
      bw = Math.max(...rows.map((r) => (r.question ? r.textW + textChipGap : 0) + r.chipW)) + pad * 2;
      bh = rows.length * chipH + (rows.length - 1) * gap + pad * 2;
    } else {
      bw = rows.reduce((a, r) => a + r.chipW, 0) + gap * Math.max(0, rows.length - 1) + pad * 2;
      bh = chipH + pad * 2;
    }

    const p = this.placement(t);
    const headTop = p.gy - p.lift - this.wickSize * 1.18;
    let above = true;
    let by = headTop - 30 - bh;
    if (by < BOARD_AREA.y - 40) { above = false; by = p.gy + 34; }
    const bx = Math.min(Math.max(60, p.gx - bw / 2), W - 60 - bw);
    const bubble: Rect = { x: bx, y: by, w: bw, h: bh };

    ctx.save();
    ctx.globalAlpha *= fade;
    const ax = p.gx, ay = above ? by + bh : by;
    ctx.translate(ax, ay);
    ctx.scale(appear, appear);
    ctx.translate(-ax, -ay);

    const fill = "#22203A";
    const tx = Math.min(Math.max(bx + 40, p.gx), bx + bw - 40);
    ctx.beginPath();
    if (above) {
      ctx.moveTo(tx - 18, by + bh - 2); ctx.lineTo(tx, by + bh + 22); ctx.lineTo(tx + 18, by + bh - 2);
    } else {
      ctx.moveTo(tx - 18, by + 2); ctx.lineTo(tx, by - 22); ctx.lineTo(tx + 18, by + 2);
    }
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    roundRect(ctx, bubble, 28);
    ctx.fill();
    ctx.strokeStyle = alpha(C.violet, 0.55);
    ctx.lineWidth = 3;
    ctx.stroke();

    if (hasText) {
      rows.forEach((row, i) => {
        const y = by + pad + i * (chipH + gap);
        let x = bx + pad;
        if (row.question) {
          this.text(ctx, row.question, x, y + chipH / 2, 34, 600, C.onInk, "left", textMax);
          x += row.textW + textChipGap;
        }
        roundRect(ctx, { x, y, w: row.chipW, h: chipH }, chipH / 2);
        ctx.fillStyle = row.color;
        ctx.fill();
        this.text(ctx, row.chip, x + row.chipW / 2, y + chipH / 2, 36, 800, "#fff", "center");
      });
    } else {
      let x = bx + pad;
      for (const row of rows) {
        roundRect(ctx, { x, y: by + pad, w: row.chipW, h: chipH }, chipH / 2);
        ctx.fillStyle = row.color;
        ctx.fill();
        this.text(ctx, row.chip, x + row.chipW / 2, by + pad + chipH / 2, 36, 800, "#fff", "center");
        x += row.chipW + gap;
      }
    }
    ctx.restore();
  }

  // ── HUD ──────────────────────────────────────────────────────────────────

  private drawHUD(ctx: Ctx, t: number, a: number): void {
    if (a <= 0) return;
    ctx.save();
    ctx.globalAlpha = a;
    const left = 120, right = 960;
    this.text(ctx, this.copy.title, left, 268, 60, 800, C.onInk, "left", 520);
    const shown = guessesShown(this.tl, t);
    if (shown > 0) {
      this.text(ctx, this.copy.guessOf(shown, totalGuesses(this.tl)), right, 272, 36, 600, C.onInkDim, "right", 300);
    }

    const rowY = 352;
    const best = bestRank(this.tl, t);
    if (best !== null) {
      const band = bandForRank(best);
      const c = bandColor(band);
      const exact = bestTile(this.tl, t)?.exact ?? true;
      let x = left;
      x += this.text(ctx, this.copy.best, x, rowY, 36, 600, C.onInkDim, "left") + 16;
      if (exact) x += this.text(ctx, formatRank(best), x, rowY - 2, 50, 800, c, "left") + 16;
      x += this.text(ctx, this.copy.bandName(band), x, rowY, 36, 600, c, "left");
      const last = this.tl.tiles[this.tl.tiles.length - 1];
      if (this.tl.outcome === "revealed" && last && t >= last.landsAt) {
        x += this.text(ctx, "·  " + this.copy.revealed, x + 16, rowY, 36, 600, C.onInkDim, "left", right - x - 16) + 16;
      }
      // Practice only: Wick stands on the final tile, so the answer goes up
      // here too once that tile lands. Both the flag and the word must be set.
      if (last && t >= last.landsAt && this.tl.showAnswer && this.tl.answer) {
        this.text(ctx, "·  " + this.tl.answer, x + 16, rowY, 40, 800, C.goldLight, "left", right - x - 16);
      }
      this.drawMeter(ctx, t, best, c);
    } else {
      this.text(ctx, this.copy.tagline, left, rowY, 38, 500, C.onInkDim, "left", right - left);
    }
    this.text(ctx, this.copy.domain, 540, 1488, 32, 600, C.violetLight, "center", undefined, 0.75);
    ctx.restore();
  }

  private drawMeter(ctx: Ctx, t: number, best: number, color: string): void {
    const track: Rect = { x: 120, y: 404, w: 840, h: 14 };
    roundRect(ctx, track, 7);
    ctx.fillStyle = "rgba(255,255,255,0.10)";
    ctx.fill();
    let fill = meterFill(best, this.maxRank);
    const setter = bestTile(this.tl, t);
    if (setter) {
      const prev = bestRank(this.tl, setter.landsAt - 0.0001);
      const from = prev === null ? 0 : meterFill(prev, this.maxRank);
      fill = from + (fill - from) * easeOut(clamp((t - setter.landsAt) / 0.4));
    }
    roundRect(ctx, { ...track, w: Math.max(14, track.w * fill) }, 7);
    ctx.fillStyle = color;
    ctx.fill();
  }

  /** "COLD → HOT" over the board when a big jump lands. */
  private drawFlash(ctx: Ctx, t: number): void {
    for (const tile of this.tl.tiles) {
      if (tile.emphasis?.kind !== "bigJump") continue;
      const dt = t - tile.landsAt;
      if (dt <= 0 || dt >= 1.5) continue;
      const to = tileBand(tile);
      const text = `${this.copy.bandName(tile.emphasis.from).toUpperCase()}  →  ${this.copy.bandName(to).toUpperCase()}`;
      const scale = dt < 0.25 ? easeOutBack(dt / 0.25) : 1;
      const cx = 540, cy = BOARD_AREA.y + BOARD_AREA.h / 2;
      ctx.font = `800 84px ${FONT}`;
      const w = Math.min(980, ctx.measureText(text).width + 80);
      ctx.save();
      ctx.globalAlpha *= clamp((1.5 - dt) / 0.3);
      ctx.translate(cx, cy);
      ctx.scale(scale, scale);
      ctx.translate(-cx, -cy);
      const pill: Rect = { x: cx - w / 2, y: cy - 70, w, h: 140 };
      roundRect(ctx, pill, 70);
      ctx.fillStyle = alpha(C.ink, 0.82);
      ctx.fill();
      ctx.strokeStyle = alpha(bandColor(to), 0.9);
      ctx.lineWidth = 4;
      ctx.stroke();
      this.text(ctx, text, cx, cy, 84, 800, bandColor(to), "center", w - 60);
      ctx.restore();
    }
  }

  /** "» +8 guesses" while a fast-forward burst plays. */
  private drawBurstBadge(ctx: Ctx, t: number): void {
    const beat = this.tl.beats[beatIndex(this.tl, t)];
    if (!beat || beat.kind.kind !== "place" || beat.kind.slots.length < 2) return;
    const a = Math.min(clamp((t - beat.start) / 0.15), clamp((beatEnd(beat) - t) / 0.15));
    const text = this.copy.fastForward(beat.kind.slots.length);
    ctx.font = `700 36px ${FONT}`;
    const w = ctx.measureText(text).width + 104;
    const pill: Rect = { x: 540 - w / 2, y: 432, w, h: 60 };
    ctx.save();
    ctx.globalAlpha *= a;
    roundRect(ctx, pill, 30);
    ctx.fillStyle = alpha(C.violet, 0.9);
    ctx.fill();
    ctx.fillStyle = "#fff";
    for (let k = 0; k < 2; k++) {
      const x0 = pill.x + 26 + k * 18, my = pill.y + 30;
      ctx.beginPath();
      ctx.moveTo(x0, my - 12); ctx.lineTo(x0 + 18, my); ctx.lineTo(x0, my + 12);
      ctx.closePath();
      ctx.fill();
    }
    this.text(ctx, text, pill.x + 80, pill.y + 30, 36, 700, "#fff", "left");
    ctx.restore();
  }

  // ── end card ─────────────────────────────────────────────────────────────

  private drawEndCard(ctx: Ctx, t: number): void {
    const beat = this.tl.beats[this.tl.beats.length - 1];
    if (!beat || beat.kind.kind !== "endCard" || t < beat.start) return;
    const local = t - beat.start;
    ctx.fillStyle = alpha(C.ink, 0.95 * clamp(local / 0.45));
    ctx.fillRect(0, 0, W, H);
    const a = clamp((local - 0.25) / 0.4);
    if (a <= 0) return;
    ctx.save();
    ctx.globalAlpha = a;
    const g = ctx.createRadialGradient(540, 740, 0, 540, 740, 420);
    g.addColorStop(0, alpha(C.violet, 0.35));
    g.addColorStop(1, alpha(C.violet, 0));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    const rise = (1 - easeOut(clamp((local - 0.25) / 0.5))) * 60;
    this.drawWick(ctx, 540, 880 + rise, 230, this.tl.outcome === "solved" ? "celebrating" : "idle", t, 1, 0, true);
    this.text(ctx, this.copy.challenge ?? this.copy.playFree, 540, 1010, 62, 600, C.onInk, "center", 900);
    this.text(ctx, this.copy.domain, 540, 1120, 108, 800, C.violetLight, "center", 940);
    this.text(ctx, `${this.copy.title}  ·  ${this.copy.stats}`, 540, 1232, 40, 500, C.onInkDim, "center", 900);
    // Practice only: the answer. Both the flag and the word must be set.
    if (this.tl.showAnswer && this.tl.answer) {
      this.text(ctx, this.copy.answerWas(this.tl.answer), 540, 1330, 52, 700, C.goldLight, "center", 900);
    }
    ctx.restore();
  }

  // ── text ─────────────────────────────────────────────────────────────────

  /** One line, vertically centered on y, shrunk to fit maxWidth. Returns width. */
  private text(ctx: Ctx, s: string, x: number, y: number, size: number, weight: number, color: string,
    align: CanvasTextAlign, maxWidth?: number, a = 1): number {
    if (!s) return 0;
    ctx.save();
    ctx.font = `${weight} ${size}px ${FONT}`;
    let w = ctx.measureText(s).width;
    let k = 1;
    if (maxWidth !== undefined && w > maxWidth && w > 0) k = maxWidth / w;
    ctx.globalAlpha *= a;
    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = "middle";
    ctx.translate(x, y);
    ctx.scale(k, k);
    ctx.fillText(s, 0, 0);
    ctx.restore();
    w *= k;
    return w;
  }

  /** A word on a tile: shrink the font from `size` down to `minSize` until it
   *  fits `maxWidth`; if it still does not fit, cut it and add an ellipsis.
   *  Works for wide Chinese characters the same as for long Latin words. */
  private fitText(ctx: Ctx, s: string, x: number, y: number, size: number, minSize: number,
    weight: number, color: string, maxWidth: number): void {
    if (!s) return;
    const f = this.fitted(ctx, s, size, minSize, weight, maxWidth);
    this.text(ctx, f.text, x, y, f.size, weight, color, "center", maxWidth);
  }

  /** The text and font size that fit `maxWidth`: shrink first, then cut with
   *  an ellipsis. Returns the measured width too. */
  private fitted(ctx: Ctx, s: string, size: number, minSize: number, weight: number, maxWidth: number):
    { text: string; size: number; width: number } {
    ctx.save();
    const width = (str: string, px: number): number => {
      ctx.font = `${weight} ${px}px ${FONT}`;
      return ctx.measureText(str).width;
    };
    let px = size;
    while (px > minSize && width(s, px) > maxWidth) px = Math.max(minSize, px - Math.max(1, size * 0.06));
    let shown = s;
    if (width(shown, px) > maxWidth) {
      const chars = Array.from(s);
      let n = chars.length - 1;
      while (n > 1 && width(chars.slice(0, n).join("") + "\u2026", px) > maxWidth) n--;
      shown = chars.slice(0, Math.max(1, n)).join("") + "\u2026";
    }
    const w = Math.min(maxWidth, width(shown, px));
    ctx.restore();
    return { text: shown, size: px, width: w };
  }
}

// ── shapes ──────────────────────────────────────────────────────────────────

function inset(r: Rect, d: number): Rect {
  return { x: r.x + d, y: r.y + d, w: r.w - d * 2, h: r.h - d * 2 };
}

function roundRect(ctx: Ctx, r: Rect, radius: number): void {
  const rad = Math.max(0, Math.min(radius, Math.min(r.w, r.h) / 2));
  ctx.beginPath();
  ctx.moveTo(r.x + rad, r.y);
  ctx.arcTo(r.x + r.w, r.y, r.x + r.w, r.y + r.h, rad);
  ctx.arcTo(r.x + r.w, r.y + r.h, r.x, r.y + r.h, rad);
  ctx.arcTo(r.x, r.y + r.h, r.x, r.y, rad);
  ctx.arcTo(r.x, r.y, r.x + r.w, r.y, rad);
  ctx.closePath();
}

/** KeeperFlameShape's curve. Keep in step with KeeperView.swift. */
function flamePath(ctx: Ctx, r: Rect, flicker: number): void {
  const w = r.w, h = r.h;
  const lean = (flicker - 0.5) * 0.22 * w;
  const X = (v: number) => r.x + v, Y = (v: number) => r.y + v;
  ctx.beginPath();
  ctx.moveTo(X(w * 0.5), Y(h));
  ctx.bezierCurveTo(X(w * 0.16), Y(h * 0.98), X(w * 0.07), Y(h * 0.78), X(w * 0.07), Y(h * 0.52));
  ctx.bezierCurveTo(X(w * 0.07), Y(h * 0.22), X(w * 0.32 + lean * 0.6), Y(h * 0.1), X(w * 0.5 + lean), Y(0));
  ctx.bezierCurveTo(X(w * 0.68 + lean * 0.6), Y(h * 0.1), X(w * 0.93), Y(h * 0.22), X(w * 0.93), Y(h * 0.52));
  ctx.bezierCurveTo(X(w * 0.93), Y(h * 0.78), X(w * 0.84), Y(h * 0.98), X(w * 0.5), Y(h));
  ctx.closePath();
}

function starPath(ctx: Ctx, cx: number, cy: number, radius: number, points: number): void {
  ctx.beginPath();
  for (let i = 0; i < points * 2; i++) {
    const r = i % 2 === 0 ? radius : radius * 0.45;
    const a = -Math.PI / 2 + (i * Math.PI) / points;
    const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.closePath();
}

function sparklePath(ctx: Ctx, cx: number, cy: number, r: number): void {
  const k = r * 0.28;
  ctx.beginPath();
  ctx.moveTo(cx, cy - r);
  ctx.quadraticCurveTo(cx + k, cy - k, cx + r, cy);
  ctx.quadraticCurveTo(cx + k, cy + k, cx, cy + r);
  ctx.quadraticCurveTo(cx - k, cy + k, cx - r, cy);
  ctx.quadraticCurveTo(cx - k, cy - k, cx, cy - r);
  ctx.closePath();
}

