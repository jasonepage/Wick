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

## Open Multilingual Wordnet and OdeNet (Spanish, French, Italian, German meanings)

`wick-web/public/gloss/es.json`, `fr.json` and `it.json` hold the short meaning
the web game shows next to each guess in those languages. They are built by
`wick-web/scripts/build-gloss-wordnet.py` from Open Multilingual Wordnet 1.4
(https://github.com/omwn/omw-data), which links each language to English
WordNet by sense:

- Spanish: Multilingual Central Repository 3.0, Creative Commons Attribution
  3.0 (CC BY 3.0)
- Italian: MultiWordNet 1.5, Creative Commons Attribution 3.0 (CC BY 3.0)
- French: WOLF (WordNet Libre du Francais), CeCILL-C license
  (http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.html)
- English WordNet 3.0 (Princeton WordNet license), used only to link senses

The derived files keep their source licenses and are not under the MPL.

The German file (`wick-web/public/gloss/de.json`) is built by the same script
from the Ding / FreeDict English-German dictionary 1.9 by Frank Richter and
Einhard Leichtfuss (https://freedict.org/, GNU General Public License v3),
with OdeNet 1.4 by Melanie Siegel and Francis Bond
(https://github.com/hdaSprachtechnologie/odenet, Creative Commons
Attribution-ShareAlike 4.0) used to confirm candidates. `de.json` is a derived
work of Ding and is shared under the GPL v3, separately from Wick's own code.

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
