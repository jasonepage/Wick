# Third-party notices

Wick's own source code is under the Mozilla Public License 2.0 (see `LICENSE`).
The items below are not Wick's work and keep their own licenses.

## fastText word vectors (embedding models)

The on-demand embedding models for French, Spanish, Italian and German
(`ODRResources/FrenchEmbedding.mlmodelc`, `SpanishEmbedding.mlmodelc`,
`ItalianEmbedding.mlmodelc`, `GermanEmbedding.mlmodelc`) are built from the
fastText "Word vectors for 157 languages" common-crawl vectors published by
Facebook AI Research:

- Source: https://fasttext.cc/docs/en/crawl-vectors.html
- License: Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0)
- Citation: E. Grave, P. Bojanowski, P. Gupta, A. Joulin, T. Mikolov,
  "Learning Word Vectors for 157 Languages", LREC 2018.

Each model is a filtered subset (roughly the 50,000 most frequent words plus
the game's own word lists), converted to a Core ML word embedding by the
scripts in `debug/embeddings/`. These model files are derived works of the
fastText vectors and are shared under CC BY-SA 3.0, not under the MPL.
English uses Apple's built-in system embedding and ships nothing.

## npm packages

`wick-api` and `wick-web` depend on open-source npm packages (Hono, ws,
word-list, qrcode, Vite, TypeScript, Vitest and their dependencies). Their
licenses are recorded in each package's `node_modules/<name>/LICENSE` after
`npm install` and in the lockfiles.

## Apple frameworks

The iOS app uses Apple's Natural Language, Foundation Models, StoreKit,
GameKit and CloudKit frameworks under the Apple Developer Program terms.
