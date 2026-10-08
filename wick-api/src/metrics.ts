//
//  metrics.ts — tiny in-memory counters for the invite funnel (3.1 telemetry).
//
//  The 3.1 redesign replaced "invent + type a code" with links; these counters let
//  us SEE whether it converts — created → joined — and where it leaks (expired,
//  code_taken, no_such_invite). Pure + dependency-free. The server holds one
//  instance and exposes a snapshot on /healthz and /metrics.
//
//  Single-instance / in-memory: counts reset on redeploy and don't survive a scale-
//  out. That's fine for a DIRECTIONAL read (is the join-rate healthy?), not billing.
//

/** The invite lifecycle we track. */
export type InviteEvent = "created" | "joined" | "expired" | "code_taken" | "no_such_invite";

export class Metrics {
  private readonly counts = new Map<string, number>();

  inc(key: string, by = 1): void {
    this.counts.set(key, (this.counts.get(key) ?? 0) + by);
  }

  /** Record an invite-funnel event — bumps both the total and the per-kind counter,
   *  e.g. `invite.created` AND `invite.created.race`. */
  invite(event: InviteEvent, kind: "race" | "dare"): void {
    this.inc(`invite.${event}`);
    this.inc(`invite.${event}.${kind}`);
  }

  get(key: string): number {
    return this.counts.get(key) ?? 0;
  }

  /** 3.3: feed a product event into the four growth counters. Keys:
   *  `daily.start`, `daily.solve`, `daily.giveup`, `daily.solveGuesses` (sum),
   *  `share.taps` (grid + map + race link created), `arrivals.raceLink`. */
  event(name: string, guesses?: number): void {
    switch (name) {
      case "daily_start": this.inc("daily.start"); break;
      case "daily_solve":
        this.inc("daily.solve");
        if (typeof guesses === "number") this.inc("daily.solveGuesses", guesses);
        break;
      case "daily_giveup": this.inc("daily.giveup"); break;
      case "share_grid":
      case "share_map":
      case "race_link_created": this.inc("share.taps"); break;
      case "race_link_opened": this.inc("arrivals.raceLink"); break;
    }
  }

  /** The four numbers the growth plan asks for, derived from the counters.
   *  Solve rate is over finished rounds (solve + give up), since an unfinished
   *  daily is not a loss yet. null = not enough data. */
  growth(): { solveRate: number | null; avgGuessesToSolve: number | null; shareTaps: number; raceLinkArrivals: number } {
    const solve = this.get("daily.solve");
    const done = solve + this.get("daily.giveup");
    return {
      solveRate: done > 0 ? Math.round((solve / done) * 1000) / 10 : null,
      avgGuessesToSolve: solve > 0 ? Math.round((this.get("daily.solveGuesses") / solve) * 10) / 10 : null,
      shareTaps: this.get("share.taps"),
      raceLinkArrivals: this.get("arrivals.raceLink"),
    };
  }

  /** A stable, sorted plain object for JSON exposure. */
  snapshot(): Record<string, number> {
    return Object.fromEntries([...this.counts].sort(([a], [b]) => a.localeCompare(b)));
  }
}
