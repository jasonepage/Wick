#!/usr/bin/env python3
"""
Step 1 of the bundled-embedding pipeline — language-agnostic (runs anywhere, incl. Linux).

Generalized from debug/french_embedding/build_vectors.py (the French POC). Reads a
fastText `.vec` file, keeps the most frequent `--top-n` words (fastText's .vec is
frequency-sorted) PLUS every word the game actually uses for that language (extracted
from RankVocabulary<LANG>.swift + WordBank<LANG>.swift so nothing guessable or
selectable is ever missing), and writes a compact vectors file for the Swift Core ML
builder (MakeEmbedding.swift, step 2).

Why top-N *and* the game words: Apple's non-English embeddings know ~200k+ words, so a
player can type almost any word and get scored. If we bundled only the ~10k rank list,
typing any other real word would read as "unknown" — a coverage regression. Keeping the
top ~50k frequent words preserves broad coverage; force-including the game words
guarantees secrets/rank/common are always present.

Default top-n is 50000 per the 1.9 plan decision (≈60 MB float32 model per language —
half the size of 100k, and top-50k covers essentially every reasonable guess).

Usage:
    # Download once from https://fasttext.cc/docs/en/crawl-vectors.html
    #   cc.<lang>.300.vec.gz  ->  gunzip  ->  cc.<lang>.300.vec
    python3 build_vectors.py \
        --lang fr \
        --vec /path/to/cc.fr.300.vec \
        --engine ../../Hunch/Engine \
        --top-n 50000 \
        --out fr_vectors.txt

Output format (read by MakeEmbedding.swift):
    line 1:  "<count> <dim>"
    then:    "<word> <f1> <f2> ... <fdim>"   (space-separated)
"""
import argparse, re, sys, os

# Supported non-English languages → (Engine file suffix, model name expected by
# SemanticEngine.bundledResourceName). English is intentionally absent: it stays
# on Apple's built-in OS embedding.
LANG_SUFFIX = {"fr": "FR", "it": "IT", "de": "DE", "es": "ES"}
MODEL_NAME = {"fr": "FrenchEmbedding", "it": "ItalianEmbedding",
              "de": "GermanEmbedding", "es": "SpanishEmbedding"}


def extract_game_words(engine_dir: str, suffix: str) -> set[str]:
    """Pull every word this language references, so it's always in-vocab.

    Stays strictly single-language: DailyWords/StarterQuestions mix all five
    languages, so pulling from them would force-include other languages' words
    and raise false "missing" alarms. This language's secrets live in
    WordBank<LANG>; rank/common words live in RankVocabulary<LANG>.
    """
    words: set[str] = set()

    # RankVocabulary<LANG>.swift — the big space-separated raw"""...""" block(s).
    rank_path = os.path.join(engine_dir, f"RankVocabulary{suffix}.swift")
    if os.path.exists(rank_path):
        src = open(rank_path, encoding="utf-8").read()
        for block in re.findall(r'"""(.*?)"""', src, re.DOTALL):
            for tok in block.split():
                words.add(tok.strip().lower())

    # WordBank<LANG>.swift — the secret words (quoted string literals).
    bank_path = os.path.join(engine_dir, f"WordBank{suffix}.swift")
    if os.path.exists(bank_path):
        src = open(bank_path, encoding="utf-8").read()
        for lit in re.findall(r'"([^"\\]{1,40})"', src):
            w = lit.strip().lower()
            if w and " " not in w and any(c.isalpha() for c in w):
                words.add(w)

    # Drop obvious non-word junk (keys, empties). Keep hyphen/apostrophe forms.
    return {w for w in words if w and not w.isdigit()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True, choices=sorted(LANG_SUFFIX),
                    help="language code: fr, it, de, or es")
    ap.add_argument("--vec", required=True, help="fastText cc.<lang>.300.vec (uncompressed)")
    ap.add_argument("--engine", default="../../Hunch/Engine",
                    help="path to Hunch/Engine for game-word extraction")
    ap.add_argument("--top-n", type=int, default=50_000,
                    help="most-frequent words to keep for guess coverage (default 50000)")
    ap.add_argument("--out", default=None, help="output path (default <lang>_vectors.txt)")
    args = ap.parse_args()

    suffix = LANG_SUFFIX[args.lang]
    out_path = args.out or f"{args.lang}_vectors.txt"

    must = extract_game_words(args.engine, suffix)
    print(f"[i] {args.lang}: game words to force-include: {len(must)}", file=sys.stderr)
    if not must:
        print(f"[!] no game words found — check --engine path and that "
              f"RankVocabulary{suffix}.swift / WordBank{suffix}.swift exist", file=sys.stderr)

    kept: dict[str, str] = {}   # word -> raw "f1 f2 ..." string
    dim = None
    with open(args.vec, encoding="utf-8", errors="replace") as f:
        header = f.readline().split()
        total, dim = int(header[0]), int(header[1])
        for idx, line in enumerate(f):
            sp = line.rstrip("\n").split(" ")
            if len(sp) != dim + 1:
                continue
            word = sp[0].lower()
            in_topn = idx < args.top_n
            if in_topn or word in must:
                if word not in kept:                 # keep highest-frequency occurrence
                    kept[word] = " ".join(sp[1:])

    hits = sum(1 for w in must if w in kept)
    print(f"[i] dim={dim}  kept={len(kept)}  game-word coverage: {hits}/{len(must)} "
          f"({100*hits/max(1,len(must)):.1f}%)", file=sys.stderr)
    missing = sorted(w for w in must if w not in kept)
    if missing:
        print(f"[!] {len(missing)} game words NOT in fastText (will be unguessable): "
              f"{', '.join(missing[:40])}{' …' if len(missing) > 40 else ''}", file=sys.stderr)

    with open(out_path, "w", encoding="utf-8") as out:
        out.write(f"{len(kept)} {dim}\n")
        for w, vec in kept.items():
            out.write(f"{w} {vec}\n")
    mb = os.path.getsize(out_path) / 1e6
    print(f"[✓] wrote {out_path}  ({len(kept)} words, {mb:.0f} MB text). "
          f"Est. .mlmodel ≈ {len(kept)*dim*4/1e6:.0f} MB (float32).", file=sys.stderr)
    print(f"    next (on your Mac): swift MakeEmbedding.swift {out_path} "
          f"{MODEL_NAME[args.lang]}.mlmodel", file=sys.stderr)


if __name__ == "__main__":
    main()
