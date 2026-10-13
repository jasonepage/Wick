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

## ECDICT (English to Chinese dictionary)

`wick-web/public/gloss/zh.json` is the short Chinese meaning the web game shows
next to each guess and the answer when the menus are in Chinese. It is built by
`wick-web/scripts/build-gloss-zh.mjs` from ECDICT by Linwei (skywind3000):

- Source: https://github.com/skywind3000/ECDICT
- License: MIT License, Copyright (c) 2025 Linwei

The file keeps only the game's scoring vocabulary (about 10,000 words) with one
short sense each. It is a derived work of ECDICT and keeps the MIT license; the
MIT notice is reproduced here:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions: The above copyright
> notice and this permission notice shall be included in all copies or
> substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS",
> WITHOUT WARRANTY OF ANY KIND.

## npm packages

`wick-api` and `wick-web` depend on open-source npm packages (Hono, ws,
word-list, qrcode, Vite, TypeScript, Vitest and their dependencies). Their
licenses are recorded in each package's `node_modules/<name>/LICENSE` after
`npm install` and in the lockfiles.

`wick-web` also uses Mediabunny (https://mediabunny.dev, Mozilla Public
License 2.0, the same license as Wick) to package Solve Replay videos as MP4.

## Apple frameworks

The iOS app uses Apple's Natural Language, Foundation Models, StoreKit,
GameKit and CloudKit frameworks under the Apple Developer Program terms.
