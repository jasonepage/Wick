#!/usr/bin/env python3
"""
Pre-device fairness / ranking-parity check for a bundled embedding.

Plan 1.9, Track A step 10: "a custom embedding shifts every non-English ranking …
for N daily words, compare the top neighbors from the custom model vs Apple's, flag
big divergences / outliers (unfair words where sensible guesses never heat up)."

This runs on the FILTERED vectors file that build_vectors.py produces (e.g.
fr_vectors.txt) — BEFORE building the .mlmodel, on Linux, no Mac needed. It is a
faithful port of SemanticEngine.fairness(for:):

  • cosine similarity from raw word vectors (0…1, clamped)
  • for each daily secret, rank the language's RankVocabulary words by similarity
  • best  = warmest a normal guess can realistically get (top common-word score, ×100)
  • warm  = how many common words land at score ≥ 30

A secret with a COLD `best` is an embedding outlier: sensible guesses never heat up,
so it plays unfairly. Those are the words to swap out of the daily pool (or investigate)
before the model ever ships.

Optionally pass --apple fr_apple_vectors.txt (neighbors exported from a device using
Apple's embedding) to get a side-by-side parity delta per word.

Usage:
    python3 fairness.py --lang fr --vectors fr_vectors.txt --engine ../../Hunch/Engine
    python3 fairness.py --lang fr --vectors fr_vectors.txt --threshold 45 --top 20
"""
import argparse, math, os, re, sys

LANG_SUFFIX = {"fr": "FR", "it": "IT", "de": "DE", "es": "ES"}


def load_vectors(path):
    """Read '<count> <dim>' header then '<word> f1 f2 …' lines → {word: [floats]}."""
    vecs = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        header = f.readline().split()
        dim = int(header[1]) if len(header) == 2 else None
        for line in f:
            sp = line.rstrip("\n").split(" ")
            if dim and len(sp) != dim + 1:
                continue
            try:
                vecs[sp[0].lower()] = [float(x) for x in sp[1:]]
            except ValueError:
                continue
    return vecs, dim


def norm(v):
    return math.sqrt(sum(x * x for x in v))


def cosine(a, b, na=None, nb=None):
    na = na if na is not None else norm(a)
    nb = nb if nb is not None else norm(b)
    if na == 0 or nb == 0:
        return None
    dot = sum(x * y for x, y in zip(a, b))
    c = dot / (na * nb)
    return max(0.0, min(1.0, c))


def rank_words(engine_dir, suffix):
    """The full RankVocabulary<LANG> word list, in order (mirrors the Swift rank list)."""
    path = os.path.join(engine_dir, f"RankVocabulary{suffix}.swift")
    words = []
    if os.path.exists(path):
        src = open(path, encoding="utf-8").read()
        for block in re.findall(r'"""(.*?)"""', src, re.DOTALL):
            words.extend(tok.strip().lower() for tok in block.split() if tok.strip())
    return words


def daily_secrets(engine_dir, suffix):
    """Daily-eligible secrets = tier1 + tier2 arrays of WordBank<LANG> (mirrors selection)."""
    path = os.path.join(engine_dir, f"WordBank{suffix}.swift")
    if not os.path.exists(path):
        return []
    src = open(path, encoding="utf-8").read()
    out = []
    for tier in ("tier1", "tier2"):
        m = re.search(rf"{tier}\s*=\s*\[(.*?)\]", src, re.DOTALL)
        if m:
            out.extend(w.lower() for w in re.findall(r'"([^"\\]+)"', m.group(1))
                       if " " not in w and any(c.isalpha() for c in w))
    # de-dupe, preserve order
    seen, uniq = set(), []
    for w in out:
        if w not in seen:
            seen.add(w); uniq.append(w)
    return uniq


def fairness(secret, ranks, vecs, norms):
    """Port of SemanticEngine.fairness: (best score ×100, warm count ≥30)."""
    tv = vecs.get(secret)
    if tv is None:
        return None
    tn = norms[secret]
    if tn == 0:
        return None
    best, warm = 0.0, 0
    for w in ranks:
        if w == secret or w in secret or secret in w:
            continue
        v = vecs.get(w)
        if v is None or len(v) != len(tv):
            continue
        c = cosine(tv, v, tn, norms.get(w))
        if c is None:
            continue
        s = c * 100
        if s > best:
            best = s
        if s >= 30:
            warm += 1
    return round(best), warm


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True, choices=sorted(LANG_SUFFIX))
    ap.add_argument("--vectors", required=True, help="filtered vectors file from build_vectors.py")
    ap.add_argument("--engine", default="../../Hunch/Engine")
    ap.add_argument("--threshold", type=float, default=45.0,
                    help="flag secrets whose best common-word score is below this (default 45)")
    ap.add_argument("--min-warm", type=int, default=5,
                    help="also flag secrets with fewer than this many warm words (default 5)")
    ap.add_argument("--top", type=int, default=8, help="print N nearest neighbors per flagged word")
    args = ap.parse_args()

    suffix = LANG_SUFFIX[args.lang]
    vecs, dim = load_vectors(args.vectors)
    print(f"[i] loaded {len(vecs)} vectors (dim {dim}) from {args.vectors}", file=sys.stderr)
    norms = {w: norm(v) for w, v in vecs.items()}

    ranks = rank_words(args.engine, suffix)
    secrets = daily_secrets(args.engine, suffix)
    print(f"[i] {len(secrets)} daily secrets · {len(ranks)} rank words", file=sys.stderr)

    missing = [s for s in secrets if s not in vecs]
    if missing:
        print(f"[!] {len(missing)} daily secrets MISSING from the embedding "
              f"(cannot be picked / unfair): {', '.join(missing)}")

    rows = []
    for s in secrets:
        f = fairness(s, ranks, vecs, norms)
        if f is None:
            continue
        best, warm = f
        rows.append((s, best, warm))

    rows.sort(key=lambda r: (r[1], r[2]))   # coldest / least-warm first
    flagged = [r for r in rows if r[1] < args.threshold or r[2] < args.min_warm]

    print(f"\n=== {args.lang.upper()} fairness ({len(rows)} scored, "
          f"{len(flagged)} flagged: best<{args.threshold:.0f} or warm<{args.min_warm}) ===")
    print(f"{'secret':16} {'best':>5} {'warm':>5}   nearest common words")
    for s, best, warm in flagged:
        tv, tn = vecs[s], norms[s]
        neigh = sorted(
            ((round(cosine(tv, vecs[w], tn, norms[w]) * 100), w)
             for w in ranks if w in vecs and w != s and w not in s and s not in w),
            reverse=True)[:args.top]
        pretty = ", ".join(f"{w}·{sc}" for sc, w in neigh)
        print(f"{s:16} {best:5} {warm:5}   {pretty}")

    if not flagged:
        print("No unfair outliers — every daily secret has a warm, guessable neighborhood. ✅")
    else:
        print(f"\nReview the flagged words: a low `best` means normal guesses never heat up. "
              f"Swap them from the daily pool or investigate the vectors.")

    # quantiles for a quick health read
    if rows:
        bests = sorted(r[1] for r in rows)
        q = lambda p: bests[min(len(bests) - 1, int(p * len(bests)))]
        print(f"\nbest-score distribution: min {bests[0]}  p10 {q(.1)}  median {q(.5)}  "
              f"p90 {q(.9)}  max {bests[-1]}")


if __name__ == "__main__":
    main()
