//
//  GameViewModel+Replay.swift
//  Hunch
//
//  Solve Replay (3.4): the bridge from a finished round to a ReplayRequest.
//
//  Reads the round exactly as it is stored (`guesses`, `questions`); no data
//  model changes. Each guess travels with its word; the spoiler rule is
//  decided once here from the game mode (`ReplayWordPolicy`) and the
//  timeline masks what must stay secret.
//

import SwiftUI
import UIKit

extension GameViewModel {

    /// Whether the finished round has anything to replay: any solve, or a
    /// reveal with at least one scored guess.
    var canShareReplay: Bool {
        solved || (revealed && guesses.contains(where: \.known))
    }

    /// Everything the replay renderer needs, or nil before the round ends.
    func replayRequest() -> ReplayRequest? {
        guard solved || revealed else { return nil }
        let events = ReplayEvents.from(guesses: guesses, questions: questions,
                                       rank: { rank(forScore: $0) },
                                       verdictLabel: { displayVerdict($0) })
        // Spoiler rule, decided once: only a practice round is a random word
        // nobody else is playing, so only it may show the answer and the
        // closest guesses. Daily, archive and duel rounds keep the answer
        // secret and mask the top 10.
        let words: ReplayWordPolicy
        if case .practice = mode {
            words = ReplayWordPolicy(showAnswer: true, answer: target)
        } else {
            words = .hideAnswer
        }
        guard let timeline = ReplayTimeline.build(events: events,
                                                  outcome: solved ? .solved : .revealed,
                                                  words: words)
        else { return nil }

        let loc = self.loc
        var bandNames: [ReplayBand: String] = [:]
        for band in ReplayBand.allCases { bandNames[band] = loc.heat(band.token) }
        let stats = solved
            ? shareStats
            : loc.replayRevealedAfter(guesses.filter(\.known).count)

        // 3.5: dare the viewer, but only when they can play the same puzzle.
        // A practice word is random, so there is nothing to beat.
        var sharedPuzzle = mode == .daily
        if case .archive = mode { sharedPuzzle = true }
        let challenge: String? = solved && sharedPuzzle
            ? String(format: loc.replayChallengeFormat, guessCount)
            : nil

        var copy = ReplayCopy(title: shareTitle,
                              tagline: loc.replayTagline,
                              stats: stats,
                              best: loc.replayBest,
                              guessOfFormat: loc.replayGuessOfFormat,
                              fastForwardFormat: loc.replayFastForwardFormat,
                              revealed: loc.replayRevealed,
                              playFree: loc.replayPlayFree,
                              bandNames: bandNames,
                              answerWasFormat: loc.replayAnswerWasFormat)
        copy.challenge = challenge
        let fileName = mode == .daily ? "Wick-Replay-\(puzzleNumber)" : "Wick-Replay"
        return ReplayRequest(timeline: timeline, copy: copy, style: .current(),
                             maxRank: maxRank, fileName: fileName)
    }
}

/// Turns stored guesses and questions into the ordered events the timeline
/// builds from. Each guess carries its word; the timeline decides what shows.
enum ReplayEvents {
    static func from(guesses: [Guess], questions: [AskedQuestion],
                     rank: (Double) -> Int,
                     verdictLabel: (String) -> String) -> [ReplayEvent] {
        var keyed: [(key: Int, tie: Int, event: ReplayEvent)] = []
        for g in guesses where g.known {
            // `seq` orders guesses and questions together. Boards saved before
            // it existed fall back to the guess number.
            keyed.append((g.seq ?? (g.order - 1), g.order,
                          ReplayEvent.guess(rank: rank(g.score), label: g.word)))
        }
        for q in questions where !q.verdict.isEmpty {
            guard let seq = q.seq else { continue }
            let verdict = ReplayVerdict(tone: ReplayVerdictTone(token: q.verdict),
                                        label: verdictLabel(q.verdict),
                                        question: q.question)
            keyed.append((seq, -1, ReplayEvent.question(verdict)))
        }
        keyed.sort { ($0.key, $0.tie) < ($1.key, $1.tie) }
        return keyed.map(\.event)
    }
}

extension ReplayStyle {
    /// HunchTheme's colors as plain sRGB values the render thread can use.
    @MainActor
    static func current() -> ReplayStyle {
        func rgba(_ color: Color) -> ReplayRGBA {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return ReplayRGBA(r: r, g: g, b: b, a: a)
        }
        let palette = HunchTheme.Palette.self
        return ReplayStyle(
            // Same inks as RevealShareCard, so the two shares look like a set.
            ink: ReplayRGBA(r: 0.06, g: 0.07, b: 0.10),
            inkLift: ReplayRGBA(r: 0.11, g: 0.10, b: 0.15),
            onInk: ReplayRGBA(r: 0.95, g: 0.95, b: 0.98),
            onInkDim: ReplayRGBA(r: 0.62, g: 0.62, b: 0.70),
            violet: rgba(palette.keeper),
            gold: rgba(palette.coin),
            neutral: rgba(palette.neutral),
            solvedGreen: rgba(palette.solved),
            // Sample ranks inside each band, so the colors always match the
            // in-game rank colors.
            cold: rgba(HunchTheme.rankColor(5000)),
            cool: rgba(HunchTheme.rankColor(800)),
            warm: rgba(HunchTheme.rankColor(200)),
            hot: rgba(HunchTheme.rankColor(50)),
            boiling: rgba(HunchTheme.rankColor(10)))
    }
}
