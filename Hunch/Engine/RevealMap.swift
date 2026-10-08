//
//  RevealMap.swift
//  Hunch
//
//  Pure, framework-free engine for "The Reveal" (3.2). Turns a finished round's
//  guesses into a semantic-map layout:
//    • distance from center = the guess's warmth — HONEST to the 0...100 score the
//      player already saw (rings line up with the HunchTheme heat bands), and
//    • angle = a 2D projection of the guesses' pairwise semantic similarity, so
//      guesses that are close to each other in meaning cluster together.
//
//  Deterministic: the same round always draws the same map (fixed rotation + mirror).
//  No SwiftUI, no Apple frameworks, no network — safe to unit-test and reuse. The View
//  layer supplies each guess's on-device embedding vector (from SemanticEngine) and its
//  score; everything here is plain arithmetic.
//
//  Keep the radius breakpoints in lockstep with HunchTheme's band thresholds.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// One plotted guess on the reveal map. `x`/`y` are on the unit disc (−1...1); the
/// View scales them to its canvas and places the word at the center (0,0).
struct RevealPoint: Equatable {
    let index: Int      // guess order (0-based)
    let word: String
    let score: Double   // 0...100, the warmth the player saw
    let radius: Double  // 0 (center / hot) ... 1 (rim / cold) — a function of score only
    let angle: Double   // radians — from the 2D projection
    let x: Double        // radius * cos(angle)
    let y: Double        // radius * sin(angle)
}

enum RevealMap {

    /// A guess to plot: its word, the warmth score it earned (0...100), and its
    /// embedding vector (any dimension, equal across guesses).
    struct Guess {
        let word: String
        let score: Double
        let vector: [Double]
        init(word: String, score: Double, vector: [Double]) {
            self.word = word; self.score = score; self.vector = vector
        }
    }

    /// Compute the layout. Radius is a pure function of score (rings match the heat
    /// bands the player saw); angle comes from a deterministic 2D projection of the
    /// guesses' pairwise semantic similarity.
    static func layout(_ guesses: [Guess]) -> [RevealPoint] {
        core(words: guesses.map { $0.word },
             scores: guesses.map { $0.score },
             dist: distanceMatrix(guesses.map { $0.vector }))
    }

    /// Convenience for the iOS View layer: build the layout from words + scores and a
    /// pairwise similarity function (0...1), e.g. `SemanticEngine.similarity`. Avoids
    /// exposing raw vectors — the distance between two guesses is `1 - similarity`
    /// (unknown pairs default to maximally far).
    static func layout(words: [String], scores: [Double],
                       similarity: (String, String) -> Double?) -> [RevealPoint] {
        let n = words.count
        var d = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let dist = max(0.0, 1.0 - (similarity(words[i], words[j]) ?? 0))
                d[i][j] = dist; d[j][i] = dist
            }
        }
        return core(words: words, scores: scores, dist: d)
    }

    /// Shared core: radius from score, angle from the 2D projection of `dist`.
    private static func core(words: [String], scores: [Double], dist: [[Double]]) -> [RevealPoint] {
        let n = words.count
        if n == 0 { return [] }

        let angles: [Double]
        if n == 1 {
            angles = [-.pi / 2]                       // a lone guess sits at the top
        } else {
            angles = canonicalAngles(mds2D(dist), scores: scores)
        }

        var out: [RevealPoint] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let r = radius(forScore: scores[i])
            let a = angles[i]
            out.append(RevealPoint(index: i, word: words[i], score: scores[i],
                                   radius: r, angle: a, x: r * cos(a), y: r * sin(a)))
        }
        return out
    }

    // MARK: - Radius from score (rings == HunchTheme heat bands)

    /// Map a 0...100 warmth score to a 0...1 radius (higher score → nearer the center).
    /// Breakpoints sit on the HunchTheme band thresholds so the concentric rings ARE the
    /// heat bands: boiling(60+), hot(45), warm(30), cool(18), cold(8), freezing(<8).
    static func radius(forScore score: Double) -> Double {
        let s = max(0, min(100, score))
        let pts: [(s: Double, r: Double)] = [(100, 0.0), (60, 0.30), (45, 0.48),
                                             (30, 0.64), (18, 0.78), (8, 0.90), (0, 1.0)]
        for k in 0..<(pts.count - 1) {
            let hi = pts[k], lo = pts[k + 1]
            if s <= hi.s && s >= lo.s {
                let t = hi.s == lo.s ? 0 : (hi.s - s) / (hi.s - lo.s)
                return hi.r + t * (lo.r - hi.r)
            }
        }
        return 1.0
    }

    // MARK: - Geometry

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        if n == 0 { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<n { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        if na == 0 || nb == 0 { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    private static func distanceMatrix(_ vecs: [[Double]]) -> [[Double]] {
        let n = vecs.count
        var d = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let dist = max(0.0, 1.0 - cosine(vecs[i], vecs[j]))
                d[i][j] = dist; d[j][i] = dist
            }
        }
        return d
    }

    /// Classical MDS to 2D via double-centering + a Jacobi eigen-decomposition.
    private static func mds2D(_ dist: [[Double]]) -> [[Double]] {
        let n = dist.count
        var d2 = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { for j in 0..<n { d2[i][j] = dist[i][j] * dist[i][j] } }
        var rowMean = Array(repeating: 0.0, count: n)
        var grand = 0.0
        for i in 0..<n {
            for j in 0..<n { rowMean[i] += d2[i][j] }
            rowMean[i] /= Double(n); grand += rowMean[i]
        }
        grand /= Double(n)
        var b = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n { b[i][j] = -0.5 * (d2[i][j] - rowMean[i] - rowMean[j] + grand) }
        }

        let (vals, vecs) = jacobiEigen(b)
        let order = (0..<n).sorted { vals[$0] > vals[$1] }
        let k0 = order[0]
        let k1 = n > 1 ? order[1] : order[0]
        let scale0 = max(0, vals[k0]).squareRoot()
        let scale1 = max(0, vals[k1]).squareRoot()
        var coords = Array(repeating: [0.0, 0.0], count: n)
        for i in 0..<n {
            coords[i][0] = vecs[i][k0] * scale0
            coords[i][1] = vecs[i][k1] * scale1
        }
        return coords
    }

    /// Jacobi eigenvalue algorithm for a symmetric matrix. Returns eigenvalues and
    /// eigenvectors as columns (vecs[i][k] = component i of eigenvector k).
    private static func jacobiEigen(_ input: [[Double]]) -> (values: [Double], vectors: [[Double]]) {
        let n = input.count
        var a = input
        var v = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { v[i][i] = 1.0 }
        if n == 1 { return ([a[0][0]], v) }

        for _ in 0..<100 {
            var p = 0, q = 1, maxOff = 0.0
            for i in 0..<n {
                for j in (i + 1)..<n where a[i][j].magnitude > maxOff {
                    maxOff = a[i][j].magnitude; p = i; q = j
                }
            }
            if maxOff < 1e-12 { break }

            let app = a[p][p], aqq = a[q][q], apq = a[p][q]
            let phi = 0.5 * atan2(2 * apq, aqq - app)
            let c = cos(phi), s = sin(phi)

            for i in 0..<n {                // A = Rᵀ A R (columns then rows)
                let aip = a[i][p], aiq = a[i][q]
                a[i][p] = c * aip - s * aiq
                a[i][q] = s * aip + c * aiq
            }
            for i in 0..<n {
                let api = a[p][i], aqi = a[q][i]
                a[p][i] = c * api - s * aqi
                a[q][i] = s * api + c * aqi
            }
            for i in 0..<n {                // accumulate rotations into V
                let vip = v[i][p], viq = v[i][q]
                v[i][p] = c * vip - s * viq
                v[i][q] = s * vip + c * viq
            }
        }
        var vals = Array(repeating: 0.0, count: n)
        for i in 0..<n { vals[i] = a[i][i] }
        return (vals, v)
    }

    // MARK: - Deterministic orientation

    /// Turn 2D coords into angles, then fix rotation + mirror so the same round always
    /// draws the same way: the hottest guess is rotated to the top, and the mirror is
    /// chosen so the second-hottest sits on the right half. A collapsed projection
    /// (all points coincident) falls back to even spacing by guess order.
    private static func canonicalAngles(_ coords: [[Double]], scores: [Double]) -> [Double] {
        let n = coords.count
        var ang = coords.map { atan2($0[1], $0[0]) }

        let spread = coords.map { ($0[0] * $0[0] + $0[1] * $0[1]).squareRoot() }.max() ?? 0
        if spread < 1e-9 {
            for i in 0..<n { ang[i] = -.pi / 2 + 2 * Double.pi * Double(i) / Double(n) }
            return ang
        }

        var hot = 0
        for i in 1..<n where scores[i] > scores[hot] { hot = i }

        var second = -1
        for i in 0..<n where i != hot {
            if second < 0 || scores[i] > scores[second] { second = i }
        }
        if second >= 0 {
            var rel = ang[second] - ang[hot]
            while rel <= -Double.pi { rel += 2 * Double.pi }
            while rel > Double.pi { rel -= 2 * Double.pi }
            if rel < 0 {                    // reflect across the hottest's axis
                for i in 0..<n { ang[i] = 2 * ang[hot] - ang[i] }
            }
        }

        let rot = -Double.pi / 2 - ang[hot]  // rotate hottest to the top
        for i in 0..<n {
            var a = ang[i] + rot
            while a <= -Double.pi { a += 2 * Double.pi }
            while a > Double.pi { a -= 2 * Double.pi }
            ang[i] = a
        }
        return ang
    }
}
