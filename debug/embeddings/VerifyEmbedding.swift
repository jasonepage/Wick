// Sanity-check a built embedding BEFORE integrating it into Xcode. macOS only.
//
// Create ML's MLWordEmbedding compresses/quantizes the vectors, so the written
// .mlmodel is much smaller than raw float32. This confirms the compression didn't
// wreck the semantics: it loads the model the same way the app does
// (NLEmbedding(contentsOf:)) and prints neighbors + warm/cold distances for a few
// probe words. If related words are close and unrelated words far, ship it.
//
// Run on your Mac:
//     swift VerifyEmbedding.swift FrenchEmbedding.mlmodel fr
//
// Probe sets are per-language; add others as you roll out IT/DE/ES.

import Foundation
import NaturalLanguage
import CoreML

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: swift VerifyEmbedding.swift <model.mlmodel|.mlmodelc> [lang]\n".utf8))
    exit(2)
}
let modelPath = args[1]
let lang = args.count >= 3 ? args[2] : "fr"

// NLEmbedding(contentsOf:) needs a COMPILED model (.mlmodelc). Compile on the fly
// if given a raw .mlmodel (this is what Xcode does at build time).
let srcURL = URL(fileURLWithPath: modelPath)
let compiledURL: URL
if srcURL.pathExtension == "mlmodel" {
    do { compiledURL = try MLModel.compileModel(at: srcURL) }
    catch { FileHandle.standardError.write(Data("compile failed: \(error)\n".utf8)); exit(1) }
} else {
    compiledURL = srcURL
}

guard let emb = try? NLEmbedding(contentsOf: compiledURL) else {
    FileHandle.standardError.write(Data("NLEmbedding failed to load \(compiledURL.lastPathComponent)\n".utf8)); exit(1)
}
print("loaded \(compiledURL.lastPathComponent) — dimension \(emb.dimension)\n")

// Cosine from raw vectors — mirrors SemanticEngine.similarity exactly.
func cosine(_ a: String, _ b: String) -> Double? {
    guard let va = emb.vector(for: a), let vb = emb.vector(for: b),
          va.count == vb.count, !va.isEmpty else { return nil }
    var dot = 0.0, na = 0.0, nb = 0.0
    for i in 0..<va.count { dot += va[i]*vb[i]; na += va[i]*va[i]; nb += vb[i]*vb[i] }
    guard na > 0, nb > 0 else { return nil }
    return max(0, min(1, dot / (na.squareRoot() * nb.squareRoot())))
}
func score(_ a: String, _ b: String) -> String {
    cosine(a, b).map { String(format: "%3.0f", $0 * 100) } ?? " ??"
}

// (probe, expected-warm neighbors, expected-cold word) per language.
let probes: [(String, [String], String)]
switch lang {
case "fr": probes = [("chien", ["chat","animal","chiens"], "voiture"),
                     ("soleil", ["lune","ciel","étoile"], "banque"),
                     ("roi", ["reine","royaume","prince"], "fromage"),
                     ("mer", ["océan","plage","eau"], "ordinateur")]
case "it": probes = [("cane", ["gatto","animale"], "automobile")]
case "de": probes = [("hund", ["katze","tier"], "auto")]
case "es": probes = [("perro", ["gato","animal"], "coche")]
default:   probes = [("chien", ["chat"], "voiture")]
}

var allGood = true
for (w, warm, cold) in probes {
    guard emb.vector(for: w) != nil else {
        print("⚠️  probe '\(w)' NOT in vocabulary"); allGood = false; continue
    }
    let neigh = emb.neighbors(for: w, maximumCount: 8)
        .map { "\($0.0)·\(Int(( $0.1).isFinite ? ($0.1) : 0))" }  // distance (lower = closer)
    print("• \(w):")
    print("    neighbors (NLEmbedding): \(neigh.joined(separator: ", "))")
    let warmScores = warm.map { "\($0)=\(score(w, $0))" }.joined(separator: "  ")
    print("    warm  \(warmScores)")
    print("    cold  \(cold)=\(score(w, cold))")
    // Heuristic pass: at least one warm word should out-score the cold word clearly.
    let warmMax = warm.compactMap { cosine(w, $0) }.max() ?? 0
    let coldVal = cosine(w, cold) ?? 0
    if warmMax <= coldVal + 0.05 { print("    ❌ warm not clearly above cold — compression may be too lossy"); allGood = false }
    else { print("    ✅ warm > cold") }
}
print("\n\(allGood ? "PASS — semantics preserved, safe to integrate." : "CHECK — some probes look off; tell Claude the numbers.")")
