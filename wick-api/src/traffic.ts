// SPDX-License-Identifier: MPL-2.0
//
//  traffic.ts: is an unusual number of people playing right now?
//
//  "Unusual" is judged against the same hour of the week over the past seven
//  days, because Wick has a daily rhythm and a weekly one: a Sunday evening
//  crowd is normal on Sunday evening and news on a Tuesday morning.
//
//  How it counts. Every player action (`seen`) marks that player as active;
//  `activeNow` is how many distinct players acted in the last ten minutes.
//  Once a minute (`tick`) the monitor records the highest active count seen in
//  the current hour of the week. When the hour changes, that peak is filed
//  under its hour slot, keeping the last seven (one per week day). The
//  expected level for now is the average of those peaks for this hour slot.
//
//  It is unusual when active players reach `ratio` times the expected level
//  and at least `floor` players, so an empty first week does not fire on two
//  friends. All in memory; a restart starts the week over.
//

export interface TrafficConfig {
  /** How long a player counts as active after an action. */
  windowMs: number;
  /** How many past values per hour slot to average (one per day). */
  history: number;
  /** Active must reach this many times the expected level. */
  ratio: number;
  /** And at least this many players, whatever the history says. */
  floor: number;
}

export const DEFAULT_TRAFFIC_CONFIG: TrafficConfig = {
  windowMs: 10 * 60_000,
  history: 7,
  ratio: 3,
  floor: 4,
};

const HOUR_MS = 3_600_000;
const SLOTS = 24 * 7;

/** The hour-of-week slot (0 is Sunday 00:00 UTC) for an epoch time. */
export function hourOfWeek(epochMs: number): number {
  // 1970-01-01 was a Thursday, four days after Sunday.
  const hours = Math.floor(epochMs / HOUR_MS) + 4 * 24;
  return ((hours % SLOTS) + SLOTS) % SLOTS;
}

export class TrafficMonitor {
  private readonly cfg: TrafficConfig;
  private readonly lastSeen = new Map<string, number>();
  private readonly peaks: number[][] = Array.from({ length: SLOTS }, () => []);
  private currentSlot: number;
  private currentPeak = 0;

  constructor(private readonly now: () => number, cfg: Partial<TrafficConfig> = {}) {
    this.cfg = { ...DEFAULT_TRAFFIC_CONFIG, ...cfg };
    this.currentSlot = hourOfWeek(this.now());
  }

  /** A player did something (connected, queued, guessed, sent an event). */
  seen(playerId: string): void {
    this.lastSeen.set(playerId, this.now());
  }

  /** Distinct players active in the last window. Also forgets the stale ones. */
  activeNow(): number {
    const cutoff = this.now() - this.cfg.windowMs;
    for (const [id, t] of this.lastSeen) if (t < cutoff) this.lastSeen.delete(id);
    return this.lastSeen.size;
  }

  /** The usual peak for this hour of the week, or null with no history yet. */
  expected(): number | null {
    const h = this.peaks[hourOfWeek(this.now())]!;
    if (h.length === 0) return null;
    return h.reduce((a, b) => a + b, 0) / h.length;
  }

  /** The number of players it would take to count as unusual right now. */
  threshold(): number {
    const e = this.expected() ?? 0;
    return Math.max(this.cfg.floor, Math.ceil(e * this.cfg.ratio));
  }

  isUnusual(): boolean {
    return this.activeNow() >= this.threshold();
  }

  /** Call about once a minute: files the hour's peak and rolls the hour over. */
  tick(): void {
    const slot = hourOfWeek(this.now());
    if (slot !== this.currentSlot) {
      const h = this.peaks[this.currentSlot]!;
      h.push(this.currentPeak);
      if (h.length > this.cfg.history) h.shift();
      this.currentSlot = slot;
      this.currentPeak = 0;
    }
    this.currentPeak = Math.max(this.currentPeak, this.activeNow());
  }
}
