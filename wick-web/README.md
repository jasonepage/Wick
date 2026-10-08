# wick-web — Wick browser client (phase 3, milestone 1)

A framework-free-ish **Vite + TypeScript** web client that plays a live Wick match
in the browser against `wick-api`. Part of the cross-platform plan in
`docs/wick/CROSS_PLATFORM.md` — one web build reaches Android, desktop, and anyone
with a link.

## Status
- **Milestone 1 (this):** full protocol loop + UX shell against the live server —
  Home → Searching → In-Match → Result, matchmaking (quick + friend code),
  opponent strip, result. Verified end-to-end in a headless browser.
- **Warmth is a labeled placeholder** (`src/game/warmth.ts`) — the browser can't
  compute real hot/cold without the secret or a semantic engine. **Milestone 2**
  adds server-computed warmth (`CROSS_PLATFORM.md` WD-1/WD-2); the client then just
  renders the server's value.

## Type sharing
`src/net/protocol.ts` re-exports the wire types **directly from `wick-api`** via the
`@server/*` tsconfig path alias (type-only, erased at build) — the client and server
can't drift on frame shapes.

## Run
```bash
npm install
npm run dev        # http://localhost:5173
```
The client holds no API key. It talks to a `wick-api` server, which is where the
Gemini key lives. Which server it uses, in priority order:

1. `?server=ws://host:port` on the page URL.
2. `VITE_WICK_SERVER` in `wick-web/.env` (copy `.env.example`, gitignored).
3. The same origin the page was served from (production: wick-api serves the built client).
4. On localhost with nothing set: `ws://localhost:8080`, a local `wick-api` (`npm run dev` there).

Open the page in **two tabs** to play both sides of a live match.

```bash
npm run build      # tsc + vite build → dist/  (static; host on GitHub Pages, C5)
npm run typecheck
```
