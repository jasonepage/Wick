//
//  SemanticEngine.swift
//  Hunch
//
//  On-device semantic closeness using Apple's Natural Language word embeddings.
//  Nothing leaves the device; works fully offline. Language-parameterized:
//  English by default, or any language Apple ships a word embedding for
//  (Spanish, French, Italian, German, Portuguese, Simplified Chinese).
//

import Foundation
import NaturalLanguage
import UIKit

struct SemanticEngine {
    let language: GameLanguage
    private let embedding: NLEmbedding?
    private let rankWords: [String]
    private let commonWords: Set<String>

    // Cache the (sometimes flaky) system embeddings so we don't re-fetch — and
    // risk a degraded/empty load — on every language switch. Apple's non-English
    // word vectors are download-on-demand and can come back empty; we retry to
    // get a good load (one that knows a common probe word) and cache only that.
    private static var cache: [String: NLEmbedding] = [:]

    /// A custom word embedding we ship for a language — as a bundled-in-binary
    /// model (the pilot's quality test) or, in 1.9, as an On-Demand Resource that
    /// `EmbeddingAssetLoader` downloads and grants. Either way the compiled model
    /// resolves from `Bundle.main` once present, which is what `bundledEmbedding`
    /// loads. Unlike Apple's `wordEmbedding(for:)` — whose non-English vectors are
    /// downloaded on demand into a shared OS asset catalog (absent on fresh devices
    /// and the Simulator) — our model is present offline once downloaded.
    ///
    /// English never needs a model (its OS assets ship with the system). The four
    /// non-English names are the outputs of `debug/embeddings/MakeEmbedding.swift`;
    /// a name returning non-nil with no matching file simply falls back to Apple's
    /// vectors, so this is safe to define before every model is built/tagged.
    static func bundledResourceName(for language: GameLanguage) -> String? {
        switch language {
        case .english: return nil
        case .french:  return "FrenchEmbedding"
        case .italian: return "ItalianEmbedding"
        case .german:  return "GermanEmbedding"
        case .spanish: return "SpanishEmbedding"
        }
    }

    /// Load our bundled embedding for this language, if one is shipped and present.
    /// Xcode compiles a bundled `.mlmodel` to `.mlmodelc`; load the compiled model.
    private static func bundledEmbedding(for language: GameLanguage) -> NLEmbedding? {
        guard let name = bundledResourceName(for: language) else { return nil }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: name, withExtension: "mlmodel") else { return nil }
        return try? NLEmbedding(contentsOf: url)
    }

    private static func loadEmbedding(for language: GameLanguage) -> NLEmbedding? {
        if let hit = cache[language.rawValue] { return hit }

        // Prefer our bundled embedding when one exists for this language. Falls
        // through to Apple's on-demand vectors when the model isn't in the bundle
        // yet, so this is safe to ship before FrenchEmbedding.mlmodel is added.
        if let bundled = bundledEmbedding(for: language) {
            cache[language.rawValue] = bundled
            return bundled
        }

        let probe = language.probeWord
        // German keys its nouns capitalized ("Haus"), so a good load must be
        // recognized in either casing — otherwise a healthy German embedding
        // reads as degraded and the language never unblocks.
        let probeCapped = probe.prefix(1).uppercased() + probe.dropFirst()
        for _ in 0..<3 {
            guard let emb = NLEmbedding.wordEmbedding(for: language.nl) else { continue }
            if emb.vector(for: probe) != nil || emb.vector(for: probeCapped) != nil {
                cache[language.rawValue] = emb          // good load — cache and use it
                return emb
            }
        }
        return NLEmbedding.wordEmbedding(for: language.nl)  // best effort if all degraded
    }

    init(language: GameLanguage = .english) {
        self.language = language
        self.embedding = SemanticEngine.loadEmbedding(for: language)
        switch language {
        case .english:
            self.rankWords = RankVocabulary.words
            self.commonWords = RankVocabulary.commonSet
        case .spanish:
            self.rankWords = RankVocabularyES.words
            self.commonWords = RankVocabularyES.commonSet
        case .french:
            self.rankWords = RankVocabularyFR.words
            self.commonWords = RankVocabularyFR.commonSet
        case .italian:
            self.rankWords = RankVocabularyIT.words
            self.commonWords = RankVocabularyIT.commonSet
        case .german:
            self.rankWords = RankVocabularyDE.words
            self.commonWords = RankVocabularyDE.commonSet
        }
    }

    /// The common-word set hints are drawn from, in the engine's language.
    var hintCommonSet: Set<String> { commonWords }

    /// Whether this language's word embedding actually loaded AND works on this
    /// device — verified against the language's probe word, because Apple's
    /// download-on-demand vectors can hand back a non-nil but EMPTY embedding
    /// (e.g. first launch offline, or on the Simulator). A degraded load must
    /// read as unavailable so the auto-retry keeps trying, instead of silently
    /// rejecting every guess as "unknown."
    var hasVocabulary: Bool { isKnown(language.probeWord) }

    /// The form of `word` that's actually in the embedding vocabulary, or nil.
    /// The app normalizes everything lowercase, but Apple's GERMAN vectors key
    /// nouns capitalized ("Haus", "Stiefel") — so try lowercase first, then
    /// first-letter-capitalized. Case-flexibility costs nothing for languages
    /// whose vocabularies are all-lowercase.
    private func vocabularyForm(_ word: String) -> String? {
        guard let embedding else { return nil }
        let lower = word.lowercased()
        if embedding.vector(for: lower) != nil { return lower }
        let capped = lower.prefix(1).uppercased() + lower.dropFirst()
        if capped != lower, embedding.vector(for: capped) != nil { return capped }
        return nil
    }

    /// The word's vector under whichever casing the vocabulary knows, or nil.
    private func vector(for word: String) -> [Double]? {
        guard let embedding, let form = vocabularyForm(word) else { return nil }
        return embedding.vector(for: form)
    }

    /// Whether the word exists in the embedding vocabulary (single words only).
    func isKnown(_ word: String) -> Bool {
        vocabularyForm(word) != nil
    }

    // MARK: - Forgiving guesses

    /// Resolve a typed guess to the word we'll actually score. Inflections are
    /// folded to their dictionary base so "running", "ran", and "run" all land
    /// in the same place (and "windmills" solves "windmill"). Returns the
    /// canonical word plus whether it's in the embedding vocabulary at all.
    func resolveGuess(_ raw: String) -> (word: String, known: Bool) {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return (lower, false) }
        if let canonical = canonicalForm(lower) { return (canonical, true) }
        return (lower, false)
    }

    /// The first in-vocabulary form among: the word ITSELF, its lemma, then
    /// simple de-inflected variants. The word itself wins when it's a real
    /// vocabulary word — taggers misread isolated words (German "haus" →
    /// verb lemma "hau"), and a word the dictionary knows must never be
    /// rewritten. True inflections ("windmills") still fold via the lemma,
    /// and solving with an inflection is guaranteed by `matchesTarget`.
    /// nil if nothing is known.
    func canonicalForm(_ word: String) -> String? {
        let lower = word.lowercased()
        var candidates: [String] = [lower]
        let lemmaInput = vocabularyForm(lower) ?? lower
        if let lemma = lemma(of: lemmaInput) { candidates.append(lemma) }
        candidates.append(contentsOf: morphologicalVariants(lower))

        var seen = Set<String>()
        for c in candidates where seen.insert(c).inserted {
            if isKnown(c) { return c }
        }
        return nil
    }

    /// Whether any reasonable reading of `typed` — itself, its lemma, or a
    /// simple de-inflection — is exactly `target`. This is the solve check:
    /// "windmills" must solve "windmill" (and "häuser" solve "haus") even
    /// though the word-first canonical form keeps the typed word for scoring.
    func matchesTarget(_ typed: String, target: String) -> Bool {
        let t = target.lowercased()
        let lower = typed.lowercased()
        if lower == t { return true }
        if let l = lemma(of: vocabularyForm(lower) ?? lower), l == t { return true }
        return morphologicalVariants(lower).contains(t)
    }

    /// Dictionary base form via Apple's on-device linguistic tagger.
    private func lemma(of word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        tagger.setLanguage(language.nl, range: word.startIndex..<word.endIndex)
        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma)
        guard let lemma = tag?.rawValue.lowercased(), !lemma.isEmpty, lemma != word else { return nil }
        return lemma
    }

    /// Cheap fallback de-inflections for when the lemma tagger comes up empty
    /// (e.g. an out-of-dictionary plural). Order doesn't matter — the caller
    /// takes the first that's in vocabulary. Handles English and the overlapping
    /// Spanish plural forms (-s / -es); deeper Spanish morphology is left to the
    /// lemma tagger above.
    private func morphologicalVariants(_ w: String) -> [String] {
        var out: [String] = []
        func add(_ s: String) { if s.count >= 2 { out.append(s) } }
        if w.hasSuffix("ies") { add(String(w.dropLast(3)) + "y") }
        if w.hasSuffix("es") { add(String(w.dropLast(2))) }
        if w.hasSuffix("s") && !w.hasSuffix("ss") { add(String(w.dropLast())) }
        if w.hasSuffix("ing") { add(String(w.dropLast(3))); add(String(w.dropLast(3)) + "e") }
        if w.hasSuffix("ed") { add(String(w.dropLast(2))); add(String(w.dropLast(1))) }
        return out
    }

    /// A spell-check style suggestion for an unknown guess, returning the first
    /// correction that's actually in the embedding vocabulary, else nil. Used
    /// for "did you mean …?" Fully on-device (UITextChecker).
    func spellingSuggestion(for word: String) -> String? {
        let lower = word.lowercased()
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let guesses = checker.guesses(forWordRange: range, in: lower, language: language.rawValue) ?? []
        for guess in guesses {
            let g = guess.lowercased()
            if g != lower, !g.contains(" "), isKnown(g) { return g }
        }
        return nil
    }

    /// Cosine similarity in 0...1 (higher = closer), or nil if either word is unknown.
    /// Computed directly from the raw word vectors to avoid any ambiguity in
    /// Apple's `distance(between:)` range.
    func similarity(_ a: String, _ b: String) -> Double? {
        guard let va = vector(for: a),
              let vb = vector(for: b),
              va.count == vb.count, !va.isEmpty else { return nil }

        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<va.count {
            dot += va[i] * vb[i]
            normA += va[i] * va[i]
            normB += vb[i] * vb[i]
        }
        guard normA > 0, normB > 0 else { return nil }

        let cosine = dot / (normA.squareRoot() * normB.squareRoot()) // -1...1
        return max(0.0, min(1.0, cosine))
    }

    /// Display closeness score 0...100, or nil if the guess isn't a known word.
    func score(_ guess: String, target: String) -> Double? {
        guard let sim = similarity(guess, target) else { return nil }
        return (sim * 100).rounded()
    }

    /// Similarities of the rank vocabulary to `target`, sorted high→low,
    /// excluding the target and its morphological variants. Used for the
    /// Contexto-style rank. Computed once per round.
    func rankingSimilarities(for target: String) -> [Double] {
        let t = target.lowercased()
        guard let tv = vector(for: t) else { return [] }
        let tNorm = tv.reduce(0.0) { $0 + $1 * $1 }.squareRoot()
        guard tNorm > 0 else { return [] }

        var sims: [Double] = []
        sims.reserveCapacity(rankWords.count)
        for w in rankWords {
            if w == t || w.contains(t) || t.contains(w) { continue }
            guard let v = vector(for: w), v.count == tv.count else { continue }
            var dot = 0.0, n = 0.0
            for i in 0..<v.count { dot += v[i] * tv[i]; n += v[i] * v[i] }
            if n > 0 {
                let cos = dot / (tNorm * n.squareRoot())
                sims.append(max(0.0, min(1.0, cos)))
            }
        }
        return sims.sorted(by: >)
    }

#if DEBUG
    /// How "fair" a secret word plays: the closeness of the single closest
    /// common word (the warmest a normal guess can realistically get) and how
    /// many common words land in warm-or-better territory (score ≥ 30). A word
    /// with a cold `best` is an embedding outlier — sensible guesses never heat
    /// up — and plays unfairly.
    func fairness(for word: String) -> (best: Double, warmCount: Int) {
        let sims = rankingSimilarities(for: word)
        let best = (sims.first ?? 0) * 100
        let warm = sims.reduce(into: 0) { if $1 * 100 >= 30 { $0 += 1 } }
        return (best.rounded(), warm)
    }
#endif

    /// Words related to `word`, nearest-first, excluding the word itself and
    /// obvious morphological variants (ocean/oceans). Used for hints.
    func relatedWords(to word: String, max: Int = 40) -> [String] {
        guard let embedding, let form = vocabularyForm(word) else { return [] }
        let w = word.lowercased()
        var out: [String] = []
        for (candidate, _) in embedding.neighbors(for: form, maximumCount: max) {
            let c = candidate.lowercased()
            if c == w { continue }
            if c.contains(w) || w.contains(c) { continue }
            if !out.contains(c) { out.append(c) }
        }
        return out
    }
}
