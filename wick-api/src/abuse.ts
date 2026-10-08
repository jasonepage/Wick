//
//  abuse.ts — transport-layer anti-abuse helpers (FR-16/FR-23).
//
//  The live service is public and cross-platform, so App Attest can't gate web
//  (docs/wick/CROSS_PLATFORM.md §4). Until cryptographic attestation lands, the
//  active defenses are: per-IP rate limits (ratelimit.ts, wired in server.ts) and
//  the origin check below. Pure + dependency-free so it's unit-testable.
//

/**
 * Is this WebSocket handshake origin allowed?
 *
 * Browsers send an `Origin` header on the WS handshake; native apps
 * (URLSessionWebSocketTask on iOS) do NOT. So:
 *   • No Origin  → a native client. Allowed here; App Attest gates it later (FR-16).
 *   • An Origin  → a browser. It MUST be in the allow-list (or a localhost dev
 *                  origin), which blocks any other website from opening a
 *                  cross-origin socket to our match server.
 *
 * A malformed Origin is denied.
 */
export function isAllowedOrigin(origin: string | undefined, allowed: readonly string[]): boolean {
  if (!origin) return true; // native client — no Origin header
  if (allowed.includes(origin)) return true;
  try {
    const host = new URL(origin).hostname;
    if (host === "localhost" || host === "127.0.0.1") return true; // local dev
  } catch {
    return false; // unparseable Origin → deny
  }
  return false;
}

/** Parse a comma-separated allow-list env var into a clean string array. */
export function parseOrigins(csv: string | undefined, fallback: readonly string[]): string[] {
  const parsed = (csv ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return parsed.length > 0 ? parsed : [...fallback];
}
