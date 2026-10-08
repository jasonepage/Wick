#!/bin/bash
#
# Phase 2 — build the IT/DE/ES embeddings as compiled ODR resources.
# macOS only (needs `swift` + `xcrun coremlcompiler`). Run from debug/embeddings/:
#
#     cd <repo>/debug/embeddings
#     bash make_odr_models.sh
#
# For each language it: downloads fastText vectors (if missing) → filters to 50k +
# game words → prints the fairness check → builds the model → compiles it to
# <Lang>Embedding.mlmodelc under ODRResources/ (the exact path the .xcodeproj now
# references). French is already done, so this only does it/de/es.
#
# ~1.3 GB download + ~4.5 GB uncompressed per language. Re-runnable: it skips a
# download you already have and overwrites old outputs.

set -e
cd "$(dirname "$0")"                 # debug/embeddings
REPO="$(cd ../.. && pwd)"            # repo root
ENGINE="$REPO/Hunch/Engine"
ODR="$REPO/ODRResources"
mkdir -p "$ODR"

langs=(it de es)

model_name () {
  case "$1" in
    it) echo "ItalianEmbedding" ;;
    de) echo "GermanEmbedding" ;;
    es) echo "SpanishEmbedding" ;;
  esac
}

for lang in "${langs[@]}"; do
  MODEL="$(model_name "$lang")"
  VEC="$HOME/Downloads/cc.$lang.300.vec"
  echo ""
  echo "=================== $lang → $MODEL ==================="

  if [ ! -f "$VEC" ]; then
    echo "[1/5] downloading cc.$lang.300.vec.gz (~1.3 GB)…"
    curl -L -C - -o "$VEC.gz" \
      "https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/cc.$lang.300.vec.gz"
    echo "[1/5] unzipping…"
    gunzip "$VEC.gz"
  else
    echo "[1/5] cc.$lang.300.vec already present — skipping download."
  fi

  echo "[2/5] filtering to 50k + game words…"
  python3 build_vectors.py --lang "$lang" --vec "$VEC" --engine "$ENGINE" --out "${lang}_vectors.txt"

  echo "[3/5] FAIRNESS CHECK ($lang) — review this:"
  python3 fairness.py --lang "$lang" --vectors "${lang}_vectors.txt" --engine "$ENGINE"

  echo "[4/5] building Core ML model…"
  swift MakeEmbedding.swift "${lang}_vectors.txt" "$MODEL.mlmodel"

  echo "[5/5] compiling to $MODEL.mlmodelc under ODRResources/…"
  rm -rf "$ODR/$MODEL.mlmodelc"
  xcrun coremlcompiler compile "$MODEL.mlmodel" "$ODR/"
  echo "✓ $lang done → ODRResources/$MODEL.mlmodelc"
done

echo ""
echo "======================================================"
echo "ALL THREE DONE. ODRResources/ now has:"
ls -1 "$ODR"
echo ""
echo "Scroll up and check each language's FAIRNESS CHECK — look for '0 flagged'"
echo "and a healthy best-score distribution (like French: median ~62)."
echo "Then in Xcode: Clean Build Folder (⇧⌘K) → run → switch languages."
echo ""
echo "Tip: the big cc.*.300.vec files (~4.5 GB each) are in ~/Downloads —"
echo "delete them when you're done to reclaim disk."
