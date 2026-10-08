//
//  SeededRandom.swift
//  Hunch
//
//  A tiny, deterministic, cross-platform PRNG. Seeding it with the same value
//  produces the same stream on every device — which is what lets the daily word
//  order and the daily starter questions be identical for all players without a
//  server.
//

import Foundation

/// SplitMix64 — small, fast, well-distributed. Deterministic for a given seed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
