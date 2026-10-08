//
//  backdrop.ts — the living background behind every Wick screen.
//
//  Two moods, picked by the body theme class:
//
//    light — a drifting pastel mesh. This is a CSS port of the iOS
//            AnimatedMeshBackground.swift: same nine-colour temperature wash
//            (icy blue → lavender → mint → amber → peach → coral → violet), same
//            idea of corners staying anchored while the middle wanders. SwiftUI
//            gets MeshGradient; the web gets five soft radial blobs on long,
//            mutually non-harmonic drift loops, which lands in the same place.
//
//    dark  — the mesh recedes to three deep tinted glows and an ember/star field
//            rises through them. iOS dark mode is a flat static gradient, so
//            there was nothing to port; embers were chosen because Wick is a
//            flame, and a candle throws sparks.
//
//  All of the mesh lives in CSS (see "Animated backdrop" in style.css). The only
//  thing that needs script is the particle canvas, which is what this module is.
//
//  On top of the mesh sits the WARMTH WASH (`.heat`) — see setBackdropHeat below.
//  That is the port of iOS `HunchTheme.background(for:)`, which the earlier version
//  of this file wrongly described as "a flat static gradient, nothing to port".
//  It is not static: on iOS the whole screen is tinted by the player's best band.
//
//  Cheap on purpose: particle count scales with viewport area but is hard-capped,
//  the loop stops when the tab is hidden, and Reduce Motion gets a single static
//  frame instead of an animation.
//

interface Particle {
  kind: "star" | "ember";
  x: number; y: number; r: number;
  vx: number; vy: number;
  /** Phase offset so particles twinkle out of step with each other. */
  ph: number;
  /** Per-particle speed multiplier on the twinkle. */
  sp: number;
  hue?: "warm" | "cool";
  life?: number;
  max?: number;
}

function reduceMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/** Build the backdrop element and start the particle field. Idempotent. */
export function mountBackdrop(): void {
  if (document.querySelector(".backdrop")) return;

  const root = document.createElement("div");
  root.className = "backdrop";
  root.setAttribute("aria-hidden", "true");
  root.innerHTML =
    '<div class="base"></div>' +
    '<span class="blob b1"></span><span class="blob b2"></span><span class="blob b3"></span>' +
    '<span class="blob b4"></span><span class="blob b5"></span>' +
    '<div class="heat"></div>' +
    '<canvas class="embers"></canvas>' +
    '<div class="vignette"></div>';
  // Behind #app, but inside <body> so the theme class reaches it.
  document.body.prepend(root);

  const canvas = root.querySelector("canvas");
  if (canvas) mountEmbers(canvas);
}

function mountEmbers(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  let w = 0, h = 0, raf = 0, t = 0;
  let parts: Particle[] = [];

  function newEmber(scatter: boolean): Particle {
    return {
      kind: "ember",
      x: Math.random() * w,
      y: scatter ? Math.random() * h : h + 12,
      r: Math.random() * 1.9 + 0.9,
      vx: (Math.random() - 0.5) * 0.18,
      vy: -(0.14 + Math.random() * 0.32),
      ph: Math.random() * Math.PI * 2,
      sp: 0.5 + Math.random() * 0.8,
      life: 0,
      max: 420 + Math.random() * 520,
    };
  }

  /** Density follows viewport area, but capped — a 4K monitor should not quietly
   *  turn the homepage into a particle benchmark. */
  function seed(): void {
    const area = w * h;
    const stars = Math.min(90, Math.round(area / 15000));
    const embers = Math.min(22, Math.round(area / 60000));
    parts = [];
    for (let i = 0; i < stars; i++) {
      parts.push({
        kind: "star",
        x: Math.random() * w, y: Math.random() * h,
        r: Math.random() * 1.25 + 0.35,
        vx: (Math.random() - 0.5) * 0.05,
        vy: (Math.random() - 0.5) * 0.05,
        ph: Math.random() * Math.PI * 2,
        sp: 0.4 + Math.random() * 0.9,
        hue: Math.random() < 0.22 ? "warm" : "cool",
      });
    }
    for (let i = 0; i < embers; i++) parts.push(newEmber(true));
  }

  function resize(): void {
    // Cap DPR at 2: past that the extra pixels cost real time and buy nothing on
    // a field of soft 1px dots.
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    w = canvas.clientWidth; h = canvas.clientHeight;
    if (w === 0 || h === 0) return;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    ctx!.setTransform(dpr, 0, 0, dpr, 0, 0);
    seed();
  }

  function wrap(p: Particle): void {
    if (p.x < -4) p.x = w + 4; else if (p.x > w + 4) p.x = -4;
    if (p.y < -4) p.y = h + 4; else if (p.y > h + 4) p.y = -4;
  }

  function draw(animate: boolean): void {
    ctx!.clearRect(0, 0, w, h);
    for (const p of parts) {
      if (p.kind === "star") {
        const tw = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * 0.02 * p.sp + p.ph));
        ctx!.beginPath();
        ctx!.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx!.fillStyle = p.hue === "warm"
          ? `rgba(255, 214, 170, ${0.55 * tw})`
          : `rgba(214, 224, 255, ${0.5 * tw})`;
        ctx!.fill();
        if (animate) { p.x += p.vx; p.y += p.vy; wrap(p); }
      } else {
        const age = (p.life ?? 0) / (p.max ?? 1);
        // Quick fade in, long fade out — an ember flares then dies.
        const fade = age < 0.14 ? age / 0.14 : 1 - (age - 0.14) / 0.86;
        const a = Math.max(0, fade) * (0.5 + 0.5 * Math.sin(t * 0.05 * p.sp + p.ph));
        const g = ctx!.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 5);
        g.addColorStop(0, `rgba(255, 186, 120, ${0.85 * a})`);
        g.addColorStop(0.35, `rgba(237, 107, 46, ${0.35 * a})`);
        g.addColorStop(1, "rgba(237, 107, 46, 0)");
        ctx!.beginPath();
        ctx!.arc(p.x, p.y, p.r * 5, 0, Math.PI * 2);
        ctx!.fillStyle = g;
        ctx!.fill();
        if (animate) {
          p.life = (p.life ?? 0) + 1;
          p.x += p.vx + Math.sin(t * 0.01 + p.ph) * 0.14;
          p.y += p.vy;
          if (p.life > (p.max ?? 0) || p.y < -20) Object.assign(p, newEmber(false));
        }
      }
    }
  }

  function loop(): void { t++; draw(true); raf = requestAnimationFrame(loop); }
  function stop(): void { if (raf) cancelAnimationFrame(raf); raf = 0; }
  function start(): void {
    stop();
    if (reduceMotion()) { draw(false); return; }  // one still frame, no loop
    raf = requestAnimationFrame(loop);
  }

  if (typeof ResizeObserver !== "undefined") {
    new ResizeObserver(() => { resize(); draw(false); }).observe(canvas);
  } else {
    window.addEventListener("resize", () => { resize(); draw(false); });
  }
  resize();
  document.addEventListener("visibilitychange", () => (document.hidden ? stop() : start()));
  window.matchMedia("(prefers-reduced-motion: reduce)").addEventListener("change", start);
  start();
}

// ── the warmth wash ─────────────────────────────────────────────────────────

/** Band → palette custom property. Boundaries mirror `scoreColor` in wickface.ts
 *  and `HunchTheme.color(for:)` on iOS; all three must agree or the background
 *  will disagree with the guess row that caused it. */
function heatVar(score: number): string {
  if (score >= 100) return "--p-solved";
  if (score >= 60) return "--p-boiling";
  if (score >= 45) return "--p-hot";
  if (score >= 30) return "--p-warm";
  if (score >= 18) return "--p-cool";
  if (score >= 8) return "--p-cold";
  return "--p-freezing";
}

/** Tint the whole page by how warm the player is, 0..100 — the web port of iOS
 *  `HunchTheme.background(for: bestScore)`.
 *
 *  Pass `null` to fade the wash out (any screen that isn't a round). Setting the
 *  colour as a `background-color` behind a fixed mask, rather than baking it into
 *  a gradient, is deliberate: `background-color` interpolates, gradients do not,
 *  so the 0.6s ease that matches iOS comes free from CSS.
 *
 *  Safe to call before the backdrop mounts, and safe to call every render — the
 *  browser only transitions when the computed colour actually changes. */
export function setBackdropHeat(score: number | null): void {
  const root = document.querySelector<HTMLElement>(".backdrop");
  if (!root) return;
  if (score === null) {
    root.style.setProperty("--heat-a", "0");
    return;
  }
  root.style.setProperty("--heat", `var(${heatVar(score)})`);
  root.style.setProperty("--heat-a", "1");
}
