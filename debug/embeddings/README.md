# Bundled embeddings — pipeline (all languages)

Generalized from the French POC (`debug/french_embedding/`). Ship our own word
embeddings so FR/IT/DE/ES score on first launch, offline, on the Simulator — no
Apple download-on-demand, no keyboard trick. English stays on Apple's built-in OS
embedding (nothing to build or download).

Delivery in 1.9 is **On-Demand Resources** (~60 MB/language, downloaded when a
language is first selected), but the same `.mlmodel` also works **bundled in the
binary** — which is the fastest way to field-test ranking quality first (the
`SemanticEngine` loader already prefers a bundled model synchronously).

## Steps (per language)

1. **Get fastText vectors (once, on your Mac).** Download `cc.<lang>.300.vec.gz`
   from https://fasttext.cc/docs/en/crawl-vectors.html (≈1.3 GB), `gunzip` it.
   300-dim, frequency-sorted, MIT/CC-BY-SA (attribution in-app if shipped).

2. **Filter to a shippable size (Python — runs anywhere, incl. Linux).**
   ```
   python3 build_vectors.py --lang fr --vec /path/to/cc.fr.300.vec \
       --engine ../../Hunch/Engine --top-n 50000 --out fr_vectors.txt
   ```
   Keeps the top-N most-frequent words for broad guess coverage PLUS every game
   word (auto-extracted from `RankVocabularyFR` + `WordBankFR`). Prints game-word
   coverage (expect ~99%+) and the estimated model size. `--top-n 50000` ≈ 60 MB.

3. **Check fairness BEFORE building the model (Python — no Mac needed).**
   ```
   python3 fairness.py --lang fr --vectors fr_vectors.txt --engine ../../Hunch/Engine
   ```
   Ports `SemanticEngine.fairness`: for every daily secret it reports the warmest a
   normal guess can get (`best`) and how many rank words land warm (`warm`), and
   flags outliers where sensible guesses never heat up. Fix/swap flagged words
   before spending a device build. (Optionally diff against Apple's neighbors with
   `--apple`.)

4. **Build the Core ML model (Swift — macOS only, needs CreateML).**
   ```
   swift MakeEmbedding.swift fr_vectors.txt FrenchEmbedding.mlmodel
   ```
   Output name must match `SemanticEngine.bundledResourceName(for:)`:
   `FrenchEmbedding` / `ItalianEmbedding` / `GermanEmbedding` / `SpanishEmbedding`.

5. **Add to Xcode.**
   - *Quick quality test:* drag `<Name>Embedding.mlmodel` into the Hunch target
     (Copy items + target membership). Xcode compiles it to `.mlmodelc`;
     `SemanticEngine` loads it automatically. Play FR rounds on the **Simulator**
     (worst case for Apple's assets): before → "dictionary not available"; after →
     scores immediately.
   - *Shipping path:* assign the model an On-Demand Resource tag (`embedding-fr`,
     etc.), "Download on demand" — then the ODR loader + progress UI take over
     (see below). Same model file either way.

## Switching French from bundled → ODR (the shipping delivery)

The app code for ODR is already written (1.9). Once French quality is confirmed
bundled-in-binary, flip it to a download:

1. **Tag the model.** Select `FrenchEmbedding.mlmodel` in Xcode → File inspector →
   **On Demand Resource Tags** → add `embedding-fr`. Confirm it's no longer forced
   into the initial install (ODR-tagged resources download on demand automatically).
2. **That's the only Xcode change.** The runtime is already wired:
   - `EmbeddingAssetLoader` (Engine/) requests tag `embedding-<lang>`, drives the
     progress modal, retains the granted request, and falls back to Apple's vectors
     on failure/offline.
   - `SemanticEngine.bundledResourceName` already resolves `FrenchEmbedding.mlmodelc`
     from `Bundle.main` once ODR grants access; `GameViewModel`'s retry loop swaps
     the engine in when it lands.
   - The modal (`EmbeddingDownloadView` + ContentView) and the Settings "Download
     all languages" section are live.
3. **Rollout switch.** `EmbeddingAssetLoader.odrEnabled` gates which languages the
   loader manages. It's `[.french]` today. Add `.italian` / `.german` / `.spanish`
   as you tag each one — until listed, a language keeps using Apple's built-in
   vectors, so this is safe to ship incrementally.

Test on the **Simulator** (worst case): first selection of French should show the
download sheet → progress → instant scoring; kill Wi-Fi to confirm the offline
fallback; delete + reinstall to confirm re-download; and check that a pack survives
being evicted (Settings → offline dictionaries shows status).

> Known simplification (v1): the loader keeps granted packs retained for the app's
> lifetime (never calls `endAccessingResources`), so iOS won't purge a downloaded
> language while the app is running. Fine for the pilot; revisit if memory pressure
> shows up across many languages.

## Notes
- **German:** Apple keys nouns capitalized ("Haus"); fastText is lowercase. The
  engine already tries both casings (`vocabularyForm`), so a lowercase DE model is
  fine — but verify when you get to German.
- The historical French-only POC (`debug/french_embedding/`) is kept for reference;
  this folder supersedes it.
