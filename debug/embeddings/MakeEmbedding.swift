// Step 2 of the bundled-embedding pipeline. macOS ONLY (needs CreateML).
//
// Language-agnostic generalization of debug/french_embedding/MakeFrenchEmbedding.swift.
// Reads <lang>_vectors.txt (from build_vectors.py) and writes <Name>Embedding.mlmodel,
// a Core ML word embedding that NLEmbedding(contentsOf:) can load at runtime.
//
// Run on your Mac (no Xcode project needed):
//     swift MakeEmbedding.swift fr_vectors.txt FrenchEmbedding.mlmodel
//     swift MakeEmbedding.swift it_vectors.txt ItalianEmbedding.mlmodel
//     swift MakeEmbedding.swift de_vectors.txt GermanEmbedding.mlmodel
//     swift MakeEmbedding.swift es_vectors.txt SpanishEmbedding.mlmodel
//
// The output name must match SemanticEngine.bundledResourceName(for:) for that
// language (FrenchEmbedding / ItalianEmbedding / GermanEmbedding / SpanishEmbedding).
//
// Then either:
//   • drag <Name>Embedding.mlmodel into the Hunch Xcode target (Copy items + target
//     membership) for a quick BUNDLED-IN-BINARY test — SemanticEngine loads it
//     synchronously today; or
//   • assign it an On-Demand Resource tag (embedding-<lang>) for the shipping ODR path.
//
// Note (German): Apple keys nouns capitalized ("Haus"); fastText is lowercase. The
// engine already tries both casings (vocabularyForm), so a lowercase DE model is fine.

import Foundation
import CreateML       // macOS-only; that's why this step runs on your Mac, not in CI/Linux
import CoreML

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: swift MakeEmbedding.swift <vectors.txt> <Name>Embedding.mlmodel\n".utf8))
    exit(2)
}
let inPath = args[1], outPath = args[2]

guard let data = FileManager.default.contents(atPath: inPath),
      let text = String(data: data, encoding: .utf8) else {
    FileHandle.standardError.write(Data("cannot read \(inPath)\n".utf8)); exit(1)
}

var lines = text.split(separator: "\n", omittingEmptySubsequences: true).makeIterator()
guard let header = lines.next() else { exit(1) }
let hp = header.split(separator: " ")
let expectedDim = Int(hp.count == 2 ? hp[1] : "0") ?? 0
print("header: \(header)  (expecting dim \(expectedDim))")

var dictionary = [String: [Double]]()
dictionary.reserveCapacity(120_000)
var n = 0
for line in lines {
    let parts = line.split(separator: " ")
    guard parts.count == expectedDim + 1 else { continue }
    let word = String(parts[0])
    var vec = [Double](); vec.reserveCapacity(expectedDim)
    for i in 1..<parts.count { vec.append(Double(parts[i]) ?? 0) }
    dictionary[word] = vec
    n += 1
    if n % 20_000 == 0 { print("  parsed \(n) words…") }
}
print("parsed \(dictionary.count) words, dim \(expectedDim)")

do {
    let embedding = try MLWordEmbedding(dictionary: dictionary)
    let url = URL(fileURLWithPath: outPath)
    try embedding.write(to: url)
    let mb = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int)?
        .map { Double($0) / 1e6 } ?? 0
    print("✓ wrote \(outPath)  (\(String(format: "%.0f", mb)) MB)")
    print("Next: add it to the Hunch target; it compiles to \(url.deletingPathExtension().lastPathComponent).mlmodelc")
} catch {
    FileHandle.standardError.write(Data("MLWordEmbedding failed: \(error)\n".utf8)); exit(1)
}
