//
//  ratelimit.ts — a small token-bucket rate limiter (FR-23, anti-abuse).
//
//  The Gemini-backed endpoints (/warmth, /keeper) and the live guess/ask actions
//  cost real money per call, and the service is public + cross-platform (so App
//  Attest can't gate web). A per-identity token bucket is the honest first line
//  of defence: it bounds how fast any one caller (by IP or connection) can burn
//  Gemini, without affecting real play.
//
//  Pure and clock-injected so it's unit-testable; the server injects Date.now.
//

interface Bucket {
  tokens: number;
  last: number; // epoch ms of the last refill
}

export class RateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  /**
   * @param capacity   Max burst (bucket size).
   * @param refillPerSec  Sustained rate (tokens added per second).
   * @param now        Clock (epoch ms).
   */
  constructor(
    private readonly capacity: number,
    private readonly refillPerSec: number,
    private readonly now: () => number,
  ) {}

  /** Try to spend `cost` tokens for `key`. Returns true if allowed. */
  take(key: string, cost = 1): boolean {
    const t = this.now();
    let b = this.buckets.get(key);
    if (!b) {
      b = { tokens: this.capacity, last: t };
      this.buckets.set(key, b);
    } else {
      const elapsedSec = Math.max(0, (t - b.last) / 1000);
      b.tokens = Math.min(this.capacity, b.tokens + elapsedSec * this.refillPerSec);
      b.last = t;
    }
    if (b.tokens >= cost) {
      b.tokens -= cost;
      return true;
    }
    return false;
  }

  /** Drop buckets untouched for `maxIdleMs` to bound memory. */
  sweep(maxIdleMs = 600_000): void {
    const t = this.now();
    for (const [k, b] of this.buckets) {
      if (t - b.last > maxIdleMs) this.buckets.delete(k);
    }
  }

  /** Number of tracked keys (ops/tests). */
  size(): number {
    return this.buckets.size;
  }
}
