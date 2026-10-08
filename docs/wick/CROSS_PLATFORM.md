# Cross-Platform & Web Client — Wick (Phase 3 design note)

**Version:** 0.1 (draft) · **Date:** 2026-07-11 · **Author:** Nathan Page
**Status:** Forward-looking design note. **Not scheduled, not built.** Extends SRS/SDS v0.2; supersedes nothing.
**Companions:** [SRS.md](SRS.md) (§5 currently lists Android/web clients as *out of scope for v1* — this note plans bringing them in as a later phase), [SDS.md](SDS.md), [UI.md](UI.md), [README.md](README.md).

> Phase 1 (free iOS live multiplayer — **deployed**) and phase 2 (Pro: cloud Keeper + ranked + cosmetics — planned) are **unchanged** by this note. This describes a possible **phase 3**: letting non-iOS players — Android and mobile/desktop **web** — into the same live matches, so anyone with a link (an Android user, a friend, a parent) can play against an iOS player.

---

## 1. Why this is feasible now

The Render service (`wick-api`) is **transport- and platform-neutral**. It is JSON frames over a WebSocket plus a little HTTP. Nothing in `room.ts`, `matchmaker.ts`, or `protocol.ts` assumes iOS. The same server that powers the iOS app can serve *any* client that speaks the protocol.

The server was never the blocker. **The client is the work.** Standing up the backend (phase 1) is exactly what unlocks cross-platform — but each new platform needs a client that can (a) speak the WS protocol and (b) actually play the game.

## 2. What a Wick client actually needs

Every client rests on three pillars. Two are easy to port; one is the real dependency.

| Pillar | What it does | Where it lives today | Portability |
|---|---|---|---|
| Guessing UI | Board, input, warmth bar, opponent strip, result | SwiftUI (iOS) | Straightforward re-build per platform; UI.md's "two flames, one word" translates directly |
| **Warmth engine** | Turns a guess into a hot/cold closeness value (semantic similarity to the secret) | On-device embedding model (iOS) | **The heavy one** — see §3 |
| Keeper | Answers in-match questions (Yes/No/Sort of) | Deterministic `WordAttributes` (~78%) + Apple Intelligence + offline fallback (iOS) | Deterministic part is **already ported to Python** (`debug/wick_tracer.py`), which proves the rules port cleanly to any language |

The Keeper's deterministic core being already mirrored in Python is a big tailwind: a web/Android client can reuse those same rules in JS/Kotlin for the ~78% it answers locally, and defer the rest (to the phase-2 cloud Keeper, or to a server call).

## 3. The warmth engine — the one real dependency

iOS computes warmth on-device from an embedding model. Off-iOS there are two ways to get warmth:

- **Option A — in-client.** Ship the embedding model to the client (WASM/ONNX in the browser; a native model on Android). Keeps clients self-contained and offline-capable, but is a heavy download and **must match the iOS model** or cross-platform matches feel unfair.
- **Option B — server-computed.** The server holds the semantic engine; the client sends its guess text and gets back `{ warmth, solved }`. The client needs no model at all.

**Recommendation: Option B for web/Android.** A multiplayer web/Android player is *already online* (the match is server-mediated), so computing their warmth on the server costs nothing in user experience and brings three bonus properties:

1. **It solves the hidden-secret problem** (flagged in phase 1). The client never receives the secret, so it cannot cheat by reading it — it only ever sends guesses and receives warmth.
2. **It makes the server authoritative for warmth** (C8). This *closes the one competitive-integrity gap* noted in phase 1: today the 5-minute timeout tie-break relies on client-reported warmth. With server-computed warmth, even the tie-break is cheat-proof.
3. **It reuses phase-2 infrastructure.** The server already grows a "smart" adjudication tier in phase 2 (the cloud Keeper); a server-side warmth endpoint sits naturally alongside it.

The cost is real but bounded: the server must run the semantic engine (compute + the word/vocabulary data). It can host the same model the app uses, or a compatible one.

> **Fairness constraint (WD-1):** a cross-platform match must compute *both* players' warmth the same way, or an iOS-vs-web race feels unfair. Simplest rule: **for any match that contains a non-iOS client, compute both players' warmth server-side.** Pure iOS-vs-iOS matches keep using on-device warmth. (An alternative is to always server-compute warmth for *all* multiplayer, unifying the path and maximizing anti-cheat, at the cost of more server compute — see WD-2.)

## 4. Anti-abuse across platforms

The `attest` gate in `hub.ts` is already an **abstraction seam** — phase 1 ships it as an allow-all stub precisely so real, per-platform verification drops in without touching match logic (FR-16).

| Platform | Integrity mechanism | Notes |
|---|---|---|
| iOS | Apple **App Attest** | The phase-1/2 plan; strongest guarantee |
| Android | Google **Play Integrity API** (a.k.a. App Check) | Direct analogue of App Attest; verify the token server-side |
| Web | **No device attestation exists** | Use layered defenses instead: origin checks, short-lived **signed session tokens** issued by the server, per-token rate limits, and optionally a challenge (Cloudflare Turnstile / hCaptcha) before matchmaking |

Web is inherently weaker on integrity than a signed native app — accept that for **free casual** play (the bot-fill and server-authoritative scoring already bound the damage), and keep the higher-stakes surfaces (phase-2 **ranked**, the cloud Keeper) gated more tightly (native attestation and/or StoreKit-equivalent entitlement).

## 5. Recommended platform sequence

1. **Web first.** One build reaches Android, iPhone Safari, desktop, and anyone with a link — no app store, no review latency, instant "tap to play." Best return on effort, and it's the universal answer to "can my dad / an Android user play?"
2. **Native Android** only if web proves insufficient (e.g. you want push notifications, Play Store presence, or offline single-player on Android). Most effort; revisit after web ships.

## 6. Web client architecture sketch

- **Shares TypeScript with the server.** `protocol.ts` and the room `state`/`result` types can be a shared package — the web client imports the exact frame definitions the server emits. This is the quiet superpower of having built the backend in TS.
- **Deterministic Keeper in JS.** Port the rules already captured in `debug/wick_tracer.py` to TS for the ~78% answerable locally; defer the rest.
- **Warmth via Option B** (server) for consistency and anti-cheat (§3).
- **Same match flow as iOS.** Open `WSS /match`, send `queue`, render `state`/`paired`/`result` — identical to the iOS `MatchClient`. The warmth-bar / opponent-strip / calm-clock UX from UI.md ports directly.
- **Dare + `/d/:code` already work in a browser** — they're just links and an OG page; nothing new needed there.

## 7. Server changes phase 3 would add

- **Formalize the attestation verifier** per platform (the seam exists).
- **Server-side warmth/adjudication** (an endpoint or in-match computation) — reuses the phase-2 cloud-adjudication infrastructure; needs the semantic engine + vocab data server-side.
- **Nail the multiplayer word/board contract** (already flagged in phase 1). With server-computed warmth this gets *simpler*: the server fully owns the secret and the client only sends guesses.
- **CORS** for browser origins; **WSS** (Render terminates TLS already).
- **Cross-platform matchmaking:** the pool stays **platform-blind** — a bigger shared pool means faster matches (same rationale as FR-15). Optionally tag platform for telemetry, but never for pairing.

## 8. Constraints — still satisfied

- **C1 (moat):** preserved. The moat is that the *iOS single-player daily game* stays 100% on-device, offline, private. Online multiplayer — on any platform — is already opt-in and server-mediated; server-computed warmth for online play never touches single-player.
- **C2 (no accounts):** preserved. Web identity is an **ephemeral, server-issued session token**, not a login — same "no account" spirit as the iOS App Attest key id.
- **C8 (server-authoritative):** strengthened (server-computed warmth closes the tie-break gap).
- **C9 (honesty):** unchanged — bots stay disclosed; the platform of an opponent is never misrepresented.
- **C7 (localization):** a web client needs the same 5-language strings (EN/ES/FR/IT/DE) with format-specifier parity.

## 9. Open decisions (phase 3)

| # | Decision | Recommended default |
|---|---|---|
| WD-1 | Warmth fairness in mixed matches | Compute **both** players' warmth server-side whenever a match contains a non-iOS client |
| WD-2 | Warmth engine location | **Server (Option B)** for web/Android; consider always-server for all multiplayer to unify + max anti-cheat |
| WD-3 | Web anti-abuse | Origin check + short-lived signed session token + rate limit; optional Turnstile/hCaptcha before matchmaking |
| WD-4 | Web identity without accounts | Ephemeral server-issued session id (no login) |
| WD-5 | Platform sequence | **Web before Android** |
| WD-6 | Server vs app embedding model | Prefer the **same** model server-side; if not, validate that cross-platform warmth stays close enough to feel fair |
| WD-7 | Deterministic-Keeper parity on web | **Yes** — port `wick_tracer.py` rules to TS so web matches iOS answers |

## 10. Out of scope (phase 3)

Native Android app (later), offline web play (web is online-first by design), porting the iOS single-player daily game to web, and any app-store presence for the web client.

## 11. Effect on what's already built

**None.** Phase 1 (deployed) and phase 2 (planned) are untouched. This is purely additive and starts from the same Render service — which is exactly why standing up the backend was the unlock.

## Document status

**v0.1 draft (2026-07-11).** Captures the cross-platform / web-client direction so it is scoped and remembered for when work begins. The authoritative specs remain SRS/SDS v0.2; promote the load-bearing decisions here (WD-1…WD-7) into those docs if and when phase 3 is greenlit.
