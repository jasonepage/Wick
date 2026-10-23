//
//  ReplayScene.swift
//  Hunch
//
//  Solve Replay (3.4), part 3: drawing one frame.
//
//  `draw(in:at:)` paints the frame for time t into any CGContext. It asks the
//  timeline what is happening at t and draws it with Core Graphics, so the
//  same moment always produces the same picture. That is what lets the
//  renderer write frames as fast as the phone can draw them instead of
//  recording the screen in real time.
//
//  Layout is a 1080 x 1920 portrait canvas. The board sits in the middle and
//  keeps clear of the right edge and the bottom, where TikTok, Reels and
//  Shorts put their buttons and captions.
//
//  Wick is drawn by KeeperFaceCG (3.8): the same chunky flame and the same
//  six faces as KeeperView, in CoreGraphics so this offscreen render can use
//  them. Which face he wears follows the game's rules (wickFace below).
//
//  Keeper questions show their text in Wick's bubble on every round; only
//  the guessed words follow the spoiler rule.
//
//  Guessed words come from the timeline's tile labels, which are already
//  masked for a daily round (ReplayTimeline.swift, ReplaySpoiler.rankLimit).
//  The answer is drawn only when the timeline's showAnswer flag is set AND
//  the label is present, so a daily replay never contains the answer in any
//  frame.
//

import CoreGraphics
import CoreText
import Foundation
import UIKit

// MARK: - Style and copy

/// A plain sRGB color that can cross threads.
nonisolated struct ReplayRGBA: Equatable, Sendable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat = 1

    func cg(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a * alpha)
    }

    /// Mix toward another color, t = 0...1.
    func mixed(_ other: ReplayRGBA, _ t: CGFloat) -> ReplayRGBA {
        ReplayRGBA(r: r + (other.r - r) * t, g: g + (other.g - g) * t,
                   b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }

    /// Darker (k < 1) version, same alpha.
    func scaled(_ k: CGFloat) -> ReplayRGBA {
        ReplayRGBA(r: r * k, g: g * k, b: b * k, a: a)
    }

    var key: String { "\(Int(r * 255))-\(Int(g * 255))-\(Int(b * 255))" }

    static let white = ReplayRGBA(r: 1, g: 1, b: 1)
    static let black = ReplayRGBA(r: 0, g: 0, b: 0)
}

/// Colors, resolved from HunchTheme on the main actor (see
/// `ReplayStyle.current()` in GameViewModel+Replay.swift).
nonisolated struct ReplayStyle: Equatable, Sendable {
    var ink: ReplayRGBA
    var inkLift: ReplayRGBA
    var onInk: ReplayRGBA
    var onInkDim: ReplayRGBA
    var violet: ReplayRGBA
    var gold: ReplayRGBA
    var neutral: ReplayRGBA
    var solvedGreen: ReplayRGBA
    var cold: ReplayRGBA
    var cool: ReplayRGBA
    var warm: ReplayRGBA
    var hot: ReplayRGBA
    var boiling: ReplayRGBA

    func band(_ b: ReplayBand) -> ReplayRGBA {
        switch b {
        case .cold:    return cold
        case .cool:    return cool
        case .warm:    return warm
        case .hot:     return hot
        case .boiling: return boiling
        case .solved:  return gold
        }
    }

    func verdict(_ tone: ReplayVerdictTone) -> ReplayRGBA {
        switch tone {
        case .yes:    return solvedGreen
        case .no:     return boiling
        case .sortOf: return warm
        case .other:  return neutral
        }
    }
}

/// Every piece of on-video text, already localized.
nonisolated struct ReplayCopy: Equatable, Sendable {
    /// "Wick #1359", same header as the text share.
    var title: String
    /// "Ask 20 questions, race to reveal the secret word"
    var tagline: String
    /// "solved in 12 · 2 questions", same as the text share.
    var stats: String
    /// "Best"
    var best: String
    /// "Guess %d of %d"
    var guessOfFormat: String
    /// "+%d guesses"
    var fastForwardFormat: String
    /// "Revealed"
    var revealed: String
    /// "Play free at"
    var playFree: String
    /// 3.5: "Can you beat 14? Play free at". Set only on a solved daily or
    /// archive round, where a viewer can play the same puzzle; nil falls back
    /// to `playFree`.
    var challenge: String? = nil
    var domain: String = "guesswick.com"
    /// Localized heat words, keyed by band.
    var bandNames: [ReplayBand: String]
    /// "The word was %@", for the practice end card.
    var answerWasFormat: String = "The word was %@"
}

/// Everything the renderer needs, safe to hand to a background task.
nonisolated struct ReplayRequest: Identifiable, Sendable {
    let id = UUID()
    let timeline: ReplayTimeline
    let copy: ReplayCopy
    let style: ReplayStyle
    /// Size of the rank list, for the log-scale meter.
    let maxRank: Int
    /// "Wick-Replay-1359"
    let fileName: String
}

// MARK: - Scene

nonisolated final class ReplayScene {

    static let size = CGSize(width: 1080, height: 1920)
    /// Where the board may go. Clear of the title bar above, and of the app
    /// buttons (right) and caption (bottom) that short-video apps overlay.
    static let boardArea = CGRect(x: 120, y: 480, width: 840, height: 940)
    /// Guess tiles narrower than this print the rank only.
    static let minTileForWord: CGFloat = 60
    /// Narrower still, and the tile is color only.
    static let minTileForRank: CGFloat = 52
    /// Three dots stand in for a masked word.
    static let maskedWord = "\u{2022}\u{2022}\u{2022}"

    let board: ReplayBoard
    private let request: ReplayRequest
    private var timeline: ReplayTimeline { request.timeline }
    private var style: ReplayStyle { request.style }
    private var copy: ReplayCopy { request.copy }
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private let wickSize: CGFloat
    private var fonts: [FontRole: CTFont] = [:]
    private var sizedFonts: [Int: CTFont] = [:]
    private var lines: [String: CTLine] = [:]
    private var backdrop: CGImage?
    private var boardCache: (settled: Int, image: CGImage)?

    init(request: ReplayRequest) {
        let board = ReplayBoard(count: request.timeline.tiles.count, area: Self.boardArea)
        self.request = request
        self.board = board
        self.wickSize = min(160, max(84, board.cell * 0.74))
        let tileText = max(16, board.cell * 0.86 * 0.27)
        fonts = [
            .title: Self.font(60, .heavy),
            .counter: Self.font(36, .semibold),
            .label: Self.font(36, .semibold),
            .rank: Self.font(50, .heavy),
            .tagline: Self.font(38, .medium),
            .tile: Self.font(tileText, .heavy),
            .tileMark: Self.font(tileText * 1.6, .heavy),
            .tileRank: Self.font(max(13, board.cell * 0.86 * 0.19), .bold),
            .hudAnswer: Self.font(40, .heavy),
            .endAnswer: Self.font(52, .bold),
            .chip: Self.font(36, .heavy),
            .flash: Self.font(84, .heavy),
            .badge: Self.font(36, .bold),
            .watermark: Self.font(32, .semibold),
            .endSmall: Self.font(62, .semibold),
            .endBig: Self.font(108, .heavy),
            .endStats: Self.font(40, .medium),
        ]
    }

    // MARK: Frame

    /// Draws the frame for time t. The context is a plain bitmap context
    /// (origin bottom-left); everything below works in top-left coordinates.
    func draw(in ctx: CGContext, at t: Double) {
        let full = CGRect(origin: .zero, size: Self.size)
        ctx.saveGState()
        defer { ctx.restoreGState() }

        // Backdrop: drawn unflipped, it is already an upright image.
        if backdrop == nil { backdrop = makeBackdrop() }
        if let backdrop { ctx.draw(backdrop, in: full) }

        ctx.translateBy(x: 0, y: Self.size.height)
        ctx.scaleBy(x: 1, y: -1)

        let shake = shakeOffset(at: t)
        ctx.saveGState()
        ctx.translateBy(x: shake.x, y: shake.y)

        let introBoard = ReplayEase.clamp((t - 0.2) / 0.5)
        drawBoard(in: ctx, at: t, alpha: CGFloat(introBoard))
        drawRings(in: ctx, at: t)
        drawWickOnBoard(in: ctx, at: t)
        drawSparkBurst(in: ctx, at: t)
        drawKeeperBubble(in: ctx, at: t)
        ctx.restoreGState()

        drawHUD(in: ctx, at: t, alpha: CGFloat(ReplayEase.clamp(t / 0.45)))
        drawFlash(in: ctx, at: t)
        drawBurstBadge(in: ctx, at: t)
        drawEndCard(in: ctx, at: t)
    }

    // MARK: Backdrop

    private func makeBackdrop() -> CGImage? {
        guard let ctx = makeContext() else { return nil }
        ctx.translateBy(x: 0, y: Self.size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(style.ink.cg())
        ctx.fill(CGRect(origin: .zero, size: Self.size))
        // A soft violet glow from the top, the app's night-sky feel.
        let colors = [style.violet.cg(0.22), style.violet.cg(0)] as CFArray
        if let g = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 540, y: 120), startRadius: 0,
                                   endCenter: CGPoint(x: 540, y: 120), endRadius: 1100,
                                   options: [])
        }
        return ctx.makeImage()
    }

    // MARK: Board

    /// Floor, walls and every settled tile come from a cached image that is
    /// rebuilt only when another tile settles. Tiles still popping in, the
    /// glowing goal and the solve wave are drawn live on top.
    private func drawBoard(in ctx: CGContext, at t: Double, alpha: CGFloat) {
        guard alpha > 0 else { return }
        let settled = settledPrefix(at: t)
        if boardCache?.settled != settled, let image = makeBoardImage(settled: settled) {
            boardCache = (settled, image)
        }
        ctx.saveGState()
        ctx.setAlpha(alpha)
        if let image = boardCache?.image {
            // The cache is upright; undo this context's flip just for it.
            ctx.saveGState()
            ctx.translateBy(x: 0, y: Self.size.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(origin: .zero, size: Self.size))
            ctx.restoreGState()
        }

        let landed = timeline.landedCount(at: t)
        if landed > settled {
            for slot in settled..<landed {
                let tile = timeline.tiles[slot]
                let dt = t - tile.landsAt
                drawTile(tile, in: ctx, scale: popScale(dt, big: isBig(tile)),
                         glow: glowAmount(tile, dt: dt))
            }
        }
        drawBestRing(in: ctx, at: t)
        drawSolveWave(in: ctx, at: t)
        ctx.restoreGState()
    }

    /// How many leading tiles have finished animating. Never includes the
    /// last tile, which keeps glowing.
    private func settledPrefix(at t: Double) -> Int {
        var n = 0
        for tile in timeline.tiles where tile.slot < timeline.finalSlot {
            guard t >= tile.landsAt + settleTime(tile) else { break }
            n += 1
        }
        return n
    }

    private func makeBoardImage(settled: Int) -> CGImage? {
        guard let ctx = makeContext() else { return nil }
        ctx.translateBy(x: 0, y: Self.size.height)
        ctx.scaleBy(x: 1, y: -1)

        let cell = board.cell
        // Walls around the level.
        let wall = board.frame.insetBy(dx: -cell * 0.16, dy: -cell * 0.16)
        ctx.addPath(roundedPath(wall, cell * 0.3))
        ctx.setFillColor(style.inkLift.scaled(0.8).cg())
        ctx.fillPath()
        ctx.addPath(roundedPath(wall, cell * 0.3))
        ctx.setStrokeColor(style.violet.cg(0.38))
        ctx.setLineWidth(max(4, cell * 0.05))
        ctx.strokePath()

        // Floor squares with a little dot, like empty Sokoban goal spots.
        for slot in 0..<board.count {
            let r = board.rect(of: slot).insetBy(dx: cell * 0.07, dy: cell * 0.07)
            ctx.addPath(roundedPath(r, r.width * 0.2))
            ctx.setFillColor(style.inkLift.cg())
            ctx.fillPath()
            if slot == timeline.finalSlot {
                // The goal square: a gold ring waiting for the answer.
                ctx.addPath(roundedPath(r.insetBy(dx: r.width * 0.12, dy: r.width * 0.12), r.width * 0.16))
                ctx.setStrokeColor(style.gold.cg(0.45))
                ctx.setLineWidth(max(3, cell * 0.04))
                ctx.strokePath()
            } else {
                let d = max(4, cell * 0.09)
                ctx.setFillColor(style.violet.cg(0.35))
                ctx.fillEllipse(in: CGRect(x: r.midX - d / 2, y: r.midY - d / 2, width: d, height: d))
            }
        }

        for slot in 0..<settled {
            drawTile(timeline.tiles[slot], in: ctx, scale: 1, glow: 0)
        }
        return ctx.makeImage()
    }

    private func makeContext() -> CGContext? {
        CGContext(data: nil, width: Int(Self.size.width), height: Int(Self.size.height),
                  bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
    }

    // MARK: Tiles

    private func isBig(_ tile: ReplayTile) -> Bool {
        tile.kind == .answer || (tile.emphasis?.isBigJump ?? false)
    }

    private func settleTime(_ tile: ReplayTile) -> Double {
        isBig(tile) ? 1.2 : 0.32
    }

    /// Scale of a tile popping in, dt seconds after it lands.
    private func popScale(_ dt: Double, big: Bool) -> CGFloat {
        guard dt > 0 else { return 0 }
        if !big {
            let d = 0.32
            guard dt < d else { return 1 }
            return CGFloat(ReplayEase.easeOutBack(dt / d))
        }
        let d = 0.6
        guard dt < d else { return 1 }
        let x = dt / d
        if x < 0.35 { return CGFloat(1.45 * ReplayEase.easeOut(x / 0.35)) }
        return CGFloat(1 + 0.45 * (1 - ReplayEase.easeInOut((x - 0.35) / 0.65)))
    }

    private func glowAmount(_ tile: ReplayTile, dt: Double) -> CGFloat {
        guard dt > 0 else { return 0 }
        if tile.kind == .answer { return CGFloat(0.65 + 0.35 * sin(dt * 2 * .pi / 1.2)) }
        if tile.emphasis?.isBigJump == true { return CGFloat(max(0, 1 - dt / 1.2)) }
        return 0
    }

    private func drawTile(_ tile: ReplayTile, in ctx: CGContext, scale: CGFloat, glow: CGFloat) {
        guard scale > 0.01 else { return }
        let cell = board.rect(of: tile.slot)
        let base = cell.insetBy(dx: cell.width * 0.07, dy: cell.width * 0.07)
        let w = base.width * scale, h = base.height * scale
        let r = CGRect(x: base.midX - w / 2, y: base.midY - h / 2, width: w, height: h)
        let radius = r.width * 0.2

        let color: ReplayRGBA
        switch tile.kind {
        case .answer:   color = style.gold
        case .revealed: color = style.neutral
        case .guess:    color = style.band(tile.band)
        }

        // Lip: a darker edge along the bottom makes it read as a crate.
        ctx.addPath(roundedPath(r, radius))
        ctx.setFillColor(color.scaled(0.6).cg())
        ctx.fillPath()

        let face = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.9)
        ctx.saveGState()
        if glow > 0 {
            ctx.setShadow(offset: .zero, blur: board.cell * 0.55 * glow, color: color.cg(0.9))
        }
        ctx.addPath(roundedPath(face, radius))
        ctx.setFillColor(color.cg())
        ctx.fillPath()
        ctx.restoreGState()

        // Top highlight.
        let shine = CGRect(x: face.minX + face.width * 0.1, y: face.minY + face.height * 0.08,
                           width: face.width * 0.8, height: face.height * 0.16)
        ctx.addPath(roundedPath(shine, shine.height / 2))
        ctx.setFillColor(ReplayRGBA.white.cg(0.16))
        ctx.fillPath()

        let center = CGPoint(x: face.midX, y: face.midY)
        let wordRoom = base.width >= Self.minTileForWord
        // Two lines: the word (or what stands in for it) above, the rank below.
        let wordAt = CGPoint(x: center.x, y: center.y - face.height * 0.13)
        let rankAt = CGPoint(x: center.x, y: center.y + face.height * 0.17)
        let maxW = base.width * 0.86 * scale
        let wordSize = max(14, base.width * 0.21) * scale
        let minWordSize = max(11, base.width * 0.12) * scale

        switch tile.kind {
        case .answer:
            let word = timeline.showAnswer ? tile.label : nil
            ctx.setFillColor(ReplayRGBA.white.cg())
            if wordRoom, let word {
                drawFitted(word, at: wordAt, size: wordSize, minSize: minWordSize, maxWidth: maxW, in: ctx)
                ctx.addPath(starPath(center: rankAt, radius: face.width * 0.14, points: 5))
            } else if wordRoom {
                drawCheckmark(at: wordAt, size: face.width * 0.22 * scale, in: ctx)
                ctx.addPath(starPath(center: rankAt, radius: face.width * 0.14, points: 5))
            } else {
                ctx.addPath(starPath(center: center, radius: face.width * 0.26, points: 5))
            }
            ctx.setFillColor(ReplayRGBA.white.cg())
            ctx.fillPath()
        case .revealed:
            let word = timeline.showAnswer ? tile.label : nil
            if wordRoom, let word {
                drawFitted(word, at: wordAt, size: wordSize, minSize: minWordSize, maxWidth: maxW, in: ctx)
                drawText("?", .tileRank, .white, at: rankAt, align: .center, in: ctx,
                         scale: scale, alpha: 0.9)
            } else if base.width >= 40 {
                drawText("?", .tileMark, .white, at: center, align: .center, in: ctx,
                         scale: scale, alpha: 0.9)
            }
        case .guess:
            if wordRoom {
                let word = tile.masked ? Self.maskedWord : tile.label
                if let word {
                    drawFitted(word, at: wordAt, size: wordSize, minSize: minWordSize, maxWidth: maxW, in: ctx)
                    drawText(ReplayFormat.rank(tile.rank), .tileRank, .white, at: rankAt, align: .center,
                             in: ctx, scale: scale, alpha: 0.85, maxWidth: maxW)
                } else {
                    drawText(ReplayFormat.rank(tile.rank), .tile, .white, at: center, align: .center,
                             in: ctx, scale: scale, maxWidth: base.width * 0.86)
                }
            } else if base.width >= Self.minTileForRank {
                drawText(ReplayFormat.rank(tile.rank), .tile, .white, at: center, align: .center,
                         in: ctx, scale: scale, maxWidth: base.width * 0.86)
            }
        }
    }

    /// A simple check, centered on `point`, about `size` wide.
    private func drawCheckmark(at point: CGPoint, size: CGFloat, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(ReplayRGBA.white.cg())
        ctx.setLineWidth(max(3, size * 0.2))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: point.x - size * 0.5, y: point.y + size * 0.02))
        ctx.addLine(to: CGPoint(x: point.x - size * 0.15, y: point.y + size * 0.34))
        ctx.addLine(to: CGPoint(x: point.x + size * 0.5, y: point.y - size * 0.3))
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// A thin ring around the best guess so far, so viewers can follow it.
    private func drawBestRing(in ctx: CGContext, at t: Double) {
        guard let best = timeline.bestRank(at: t), best > 1,
              let slot = timeline.tiles.first(where: { $0.rank == best && $0.landsAt <= t })?.slot
        else { return }
        let r = board.rect(of: slot).insetBy(dx: board.cell * 0.03, dy: board.cell * 0.03)
        ctx.addPath(roundedPath(r, r.width * 0.24))
        ctx.setStrokeColor(ReplayRGBA.white.cg(0.6))
        ctx.setLineWidth(max(3, board.cell * 0.035))
        ctx.strokePath()
    }

    /// Solved: a wave of light runs along the path, like a finished Sokoban
    /// level lighting up.
    private func drawSolveWave(in ctx: CGContext, at t: Double) {
        guard timeline.outcome == .solved, let last = timeline.tiles.last else { return }
        let start = last.landsAt + 0.15
        guard t > start else { return }
        let n = max(1, timeline.tiles.count - 1)
        let step = min(0.05, 1.2 / Double(n))
        for tile in timeline.tiles.dropLast() {
            let x = (t - start - Double(tile.slot) * step) / 0.35
            guard x > 0, x < 1 else { continue }
            let r = board.rect(of: tile.slot).insetBy(dx: board.cell * 0.07, dy: board.cell * 0.07)
            ctx.addPath(roundedPath(r, r.width * 0.2))
            ctx.setFillColor(style.gold.mixed(.white, 0.5).cg(CGFloat(0.55 * sin(.pi * x))))
            ctx.fillPath()
        }
    }

    /// Big jumps send two rings out from the tile.
    private func drawRings(in ctx: CGContext, at t: Double) {
        for tile in timeline.tiles where isBig(tile) {
            let color = tile.kind == .answer ? style.gold : style.band(tile.band)
            for delay in [0.0, 0.18] {
                let e = (t - tile.landsAt - delay) / 0.9
                guard e > 0, e < 1 else { continue }
                let c = board.center(of: tile.slot)
                let radius = board.cell * CGFloat(0.5 + 1.9 * e)
                ctx.setStrokeColor(color.cg(CGFloat(0.85 * (1 - e))))
                ctx.setLineWidth(CGFloat(2 + 10 * (1 - e)))
                ctx.strokeEllipse(in: CGRect(x: c.x - radius, y: c.y - radius,
                                             width: radius * 2, height: radius * 2))
            }
        }
    }

    /// Gold sparks burst off the answer tile.
    private func drawSparkBurst(in ctx: CGContext, at t: Double) {
        guard timeline.outcome == .solved, let last = timeline.tiles.last else { return }
        let dt = t - last.landsAt
        guard dt > 0, dt < 1.4 else { return }
        let c = board.center(of: last.slot)
        let e = dt / 1.4
        for i in 0..<16 {
            let angle = Double(i) / 16 * 2 * .pi + 0.3
            let speed = 260 + Double((i * 37) % 5) * 40
            let dist = CGFloat(speed * ReplayEase.easeOut(e))
            let p = CGPoint(x: c.x + CGFloat(cos(angle)) * dist,
                            y: c.y + CGFloat(sin(angle)) * dist + CGFloat(120 * e * e))
            ctx.addPath(sparklePath(center: p, radius: CGFloat(22 * (1 - e) + 6)))
            ctx.setFillColor(style.gold.cg(CGFloat(1 - e)))
            ctx.fillPath()
        }
    }

    private func shakeOffset(at t: Double) -> CGPoint {
        for tile in timeline.tiles.reversed() where isBig(tile) {
            let dt = t - tile.landsAt
            guard dt >= 0 else { continue }
            guard dt < 0.45 else { break }
            let amp = 16 * (1 - dt / 0.45)
            return CGPoint(x: sin(dt * 70) * amp, y: cos(dt * 55) * amp * 0.6)
        }
        return .zero
    }

    // MARK: Wick on the board

    private func wickLook(at t: Double) -> WickLook {
        if let last = timeline.tiles.last, t >= last.landsAt {
            return timeline.outcome == .solved ? .celebrating : .defeated
        }
        if let i = timeline.beatIndex(at: t), case .keeper = timeline.beats[i].kind {
            return .thinking
        }
        // He wears the heat of the guess that just landed (the latest tile),
        // not the best so far, so he flickers cold and hot as the guesses do.
        // The HUD's "Best" still shows the best.
        var latest: ReplayTile? = nil
        for tile in timeline.tiles {
            if tile.landsAt <= t { latest = tile } else { break }
        }
        if let tile = latest { return .band(tile.band) }
        return .idle
    }

    /// Wick's feet on the board at time t, plus how high he is hopping.
    private func wickPlacement(at t: Double) -> (ground: CGPoint, lift: CGFloat, squash: CGFloat, dir: CGFloat) {
        let travel = timeline.wickTravel(at: t)
        let a = board.center(of: travel.from), b = board.center(of: travel.to)
        let p = CGFloat(ReplayEase.easeInOut(travel.progress))
        let footDrop = board.cell * 0.2
        var ground = CGPoint(x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p + footDrop)
        var lift: CGFloat = 0
        var squash: CGFloat = 1
        let dir: CGFloat = travel.from == travel.to ? 0 : (b.x > a.x ? 1 : (b.x < a.x ? -1 : 0))

        if travel.from != travel.to {
            lift = CGFloat(sin(.pi * travel.progress)) * max(26, board.cell * 0.42)
        } else {
            // Crouch just before a hop, and squash for a moment after landing.
            for tile in timeline.tiles {
                let lead = tile.landsAt - t
                if lead > 0, lead <= 0.12 { squash = 1 - 0.14 * CGFloat(1 - lead / 0.12); break }
                let after = t - (tile.landsAt + tile.hop)
                if tile.hop > 0, after >= 0, after < 0.14 { squash = 1 - 0.12 * CGFloat(1 - after / 0.14) }
            }
        }

        // Intro: drop in from above onto the first cell.
        if t < 1.2 {
            let fall = ReplayEase.clamp((t - 0.5) / 0.45)
            lift = CGFloat(1 - ReplayEase.easeIn(fall)) * 460
            if t >= 0.95 { squash = 1 - 0.18 * CGFloat(sin(.pi * ReplayEase.clamp((t - 0.95) / 0.25))) }
            ground = CGPoint(x: board.center(of: 0).x, y: board.center(of: 0).y + footDrop)
        }

        // Finale: the last tile rises under him and lifts him a little.
        if let last = timeline.tiles.last {
            let dt = t - last.landsAt
            if dt > 0 {
                lift += popScale(dt, big: isBig(last)) * board.cell * 0.08
                if timeline.outcome == .solved {
                    lift += CGFloat(max(0, sin(dt * 2 * .pi / 0.8))) * board.cell * 0.12
                }
            }
        }
        return (ground, lift, squash, dir)
    }

    private func drawWickOnBoard(in ctx: CGContext, at t: Double) {
        guard t >= 0.5 else { return }
        let place = wickPlacement(at: t)
        let s = wickSize

        // Ground shadow stays on the floor while he hops.
        let shrink = 1 - min(0.5, place.lift / 400)
        let sw = s * 0.62 * shrink, sh = s * 0.16 * shrink
        ctx.setFillColor(ReplayRGBA.black.cg(0.42))
        ctx.fillEllipse(in: CGRect(x: place.ground.x - sw / 2, y: place.ground.y - sh / 2,
                                   width: sw, height: sh))

        drawWick(in: ctx, feet: CGPoint(x: place.ground.x, y: place.ground.y - place.lift),
                 size: s, look: wickLook(at: t), t: t, squash: place.squash,
                 lookDirection: place.dir, standing: place.lift < 1)
    }

    // MARK: Wick

    nonisolated enum WickLook: Equatable {
        case idle, thinking, band(ReplayBand), celebrating, defeated
    }

    private func color(of look: WickLook) -> ReplayRGBA {
        switch look {
        case .idle, .thinking: return style.violet
        case .band(let b):     return b == .solved ? style.solvedGreen : style.band(b)
        case .celebrating:     return style.solvedGreen
        case .defeated:        return style.neutral
        }
    }

    private func bobPeriod(_ look: WickLook) -> Double {
        switch look {
        case .idle, .thinking:   return 1.8
        case .celebrating:       return 0.8
        case .defeated:          return 2.8
        case .band(let b):
            switch b {
            case .cold:    return 2.6
            case .cool:    return 2.2
            case .warm:    return 1.2
            case .hot:     return 0.8
            case .boiling: return 0.55
            case .solved:  return 0.8
            }
        }
    }

    /// Which face and colour Wick wears at each moment of the replay: the
    /// game's own rules (Sly cold, Flustered warm, Focus while answering,
    /// Shocked on the solve, Calm on a give-up), in the replay's colours.
    private func wickFace(_ look: WickLook) -> KeeperFaceName {
        switch look {
        case .idle:        return .sly
        case .thinking:    return .focus
        case .celebrating: return .shocked
        case .defeated:    return .calm
        case .band(let b):
            switch b {
            case .cold, .cool:           return .sly
            case .warm, .hot, .boiling:  return .flustered
            case .solved:                return .shocked
            }
        }
    }

    /// Draws Wick with his feet at `feet`, `size` wide, 1.18 x `size` tall,
    /// with the same flame and faces as KeeperView (3.8, KeeperFaceCG).
    private func drawWick(in ctx: CGContext, feet: CGPoint, size s: CGFloat, look: WickLook,
                          t: Double, squash: CGFloat, lookDirection: CGFloat, standing: Bool) {
        let h: CGFloat = s * 1.18
        let period: Double = bobPeriod(look)
        let bob: CGFloat = standing ? CGFloat(sin(t * 2 * .pi / period)) * s * 0.03 : 0
        let flicker: Double = 0.5 + 0.5 * sin(t * 2 * .pi / (period * 0.8))
        let body: ReplayRGBA = color(of: look)
        let rgb = KeeperRGB(r: Double(body.r) * 255, g: Double(body.g) * 255, b: Double(body.b) * 255)
        let face: KeeperFace = KeeperFaces.face(wickFace(look))
        let canBlink: Bool = look != .celebrating && look != .defeated
        let blink: Double = canBlink ? KeeperFaces.blinkAmount(fmod(t + 0.7, 3.3)) : 0
        let closure: [Double] = face.eyes.map { max($0.closed, blink) }

        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: feet.x, y: feet.y + bob)
        ctx.scaleBy(x: 1 + (1 - squash) * 0.9, y: squash)

        // Sparkles around a celebrating Wick, in pixels around his middle.
        if look == .celebrating {
            for i in 0..<5 {
                let a: Double = Double(i) / 5 * 2 * .pi
                let phase: Double = (sin(t * 2 * .pi / 0.6 - Double(i) * 0.75) + 1) / 2
                let p = CGPoint(x: CGFloat(cos(a)) * s * 0.62, y: -h / 2 + CGFloat(sin(a)) * s * 0.62)
                ctx.addPath(sparklePath(center: p, radius: s * 0.07))
                ctx.setFillColor(style.gold.cg(CGFloat(0.25 + 0.75 * phase)))
                ctx.fillPath()
            }
        }

        // Into Wick's viewBox units: 120 units tall from the tip to the feet.
        let unit: CGFloat = h / 120
        ctx.saveGState()
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: -60, y: -124)
        KeeperFaceCG.drawWick(in: ctx, face: face, closure: closure, color: rgb, flicker: flicker,
                              glowBlur: s * 0.3, glowAlpha: look == .defeated ? 0.1 : 0.6)
        ctx.restoreGState()
    }

    // MARK: Keeper bubble

    /// Questions asked in a row: Wick says just the verdicts. Never the text.
    private func drawKeeperBubble(in ctx: CGContext, at t: Double) {
        guard let i = timeline.beatIndex(at: t), case .keeper(let verdicts) = timeline.beats[i].kind
        else { return }
        let beat = timeline.beats[i]
        let local = t - beat.start
        let appear = local < 0.2 ? ReplayEase.easeOutBack(local / 0.2) : 1
        let fade = ReplayEase.clamp((beat.end - t) / 0.15)
        guard appear > 0.01, fade > 0 else { return }

        // One row per question: the text, then its verdict chip. Rounds saved
        // before question text travelled show chips only, in one row.
        let chipH: CGFloat = 64, gap: CGFloat = 14, pad: CGFloat = 20
        let textChipGap: CGFloat = 18, textMax: CGFloat = 560
        struct Row { var question: CTLine?; var textW: CGFloat; var chip: String; var color: ReplayRGBA; var chipW: CGFloat }
        let shownVerdicts = verdicts.prefix(3)
        let hasText = shownVerdicts.contains { $0.question != nil }
        var rows: [Row] = shownVerdicts.map { v in
            let chip = v.label.uppercased()
            let fitted = v.question.map { fittedLine($0, size: 34, minSize: 24, weight: .semibold, maxWidth: textMax) }
            return Row(question: fitted?.line, textW: fitted?.width ?? 0, chip: chip,
                       color: style.verdict(v.tone), chipW: textWidth(chip, .chip) + 44)
        }
        if verdicts.count > 3 {
            let extra = "+\(verdicts.count - 3)"
            rows.append(Row(question: nil, textW: 0, chip: extra, color: style.neutral,
                            chipW: textWidth(extra, .chip) + 44))
        }
        let bubbleW: CGFloat, bubbleH: CGFloat
        if hasText {
            bubbleW = (rows.map { ($0.question == nil ? 0 : $0.textW + textChipGap) + $0.chipW }.max() ?? 0) + pad * 2
            bubbleH = CGFloat(rows.count) * chipH + CGFloat(rows.count - 1) * gap + pad * 2
        } else {
            bubbleW = rows.map(\.chipW).reduce(0, +) + gap * CGFloat(max(0, rows.count - 1)) + pad * 2
            bubbleH = chipH + pad * 2
        }

        let place = wickPlacement(at: t)
        let headTop = place.ground.y - place.lift - wickSize * 1.18
        var above = true
        var bubbleY = headTop - 30 - bubbleH
        if bubbleY < Self.boardArea.minY - 40 {
            above = false
            bubbleY = place.ground.y + 34
        }
        let bubbleX = min(max(60, place.ground.x - bubbleW / 2), Self.size.width - 60 - bubbleW)
        let bubble = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)

        ctx.saveGState()
        ctx.setAlpha(CGFloat(fade))
        let anchor = CGPoint(x: place.ground.x, y: above ? bubble.maxY : bubble.minY)
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.scaleBy(x: CGFloat(appear), y: CGFloat(appear))
        ctx.translateBy(x: -anchor.x, y: -anchor.y)

        // Tail toward Wick.
        let tail = CGMutablePath()
        let tx = min(max(bubble.minX + 40, place.ground.x), bubble.maxX - 40)
        if above {
            tail.move(to: CGPoint(x: tx - 18, y: bubble.maxY - 2))
            tail.addLine(to: CGPoint(x: tx, y: bubble.maxY + 22))
            tail.addLine(to: CGPoint(x: tx + 18, y: bubble.maxY - 2))
        } else {
            tail.move(to: CGPoint(x: tx - 18, y: bubble.minY + 2))
            tail.addLine(to: CGPoint(x: tx, y: bubble.minY - 22))
            tail.addLine(to: CGPoint(x: tx + 18, y: bubble.minY + 2))
        }
        tail.closeSubpath()
        let fill = style.inkLift.mixed(style.violet, 0.12)
        ctx.addPath(tail)
        ctx.setFillColor(fill.cg())
        ctx.fillPath()
        ctx.addPath(roundedPath(bubble, 28))
        ctx.setFillColor(fill.cg())
        ctx.fillPath()
        ctx.addPath(roundedPath(bubble, 28))
        ctx.setStrokeColor(style.violet.cg(0.55))
        ctx.setLineWidth(3)
        ctx.strokePath()

        if hasText {
            for (i, row) in rows.enumerated() {
                let y = bubble.minY + pad + CGFloat(i) * (chipH + gap)
                var x = bubble.minX + pad
                if let line = row.question {
                    drawLine(line, at: CGPoint(x: x, y: y + chipH / 2), in: ctx)
                    x += row.textW + textChipGap
                }
                let r = CGRect(x: x, y: y, width: row.chipW, height: chipH)
                ctx.addPath(roundedPath(r, chipH / 2))
                ctx.setFillColor(row.color.cg())
                ctx.fillPath()
                drawText(row.chip, .chip, .white, at: CGPoint(x: r.midX, y: r.midY), align: .center, in: ctx)
            }
        } else {
            var x = bubble.minX + pad
            for row in rows {
                let r = CGRect(x: x, y: bubble.minY + pad, width: row.chipW, height: chipH)
                ctx.addPath(roundedPath(r, chipH / 2))
                ctx.setFillColor(row.color.cg())
                ctx.fillPath()
                drawText(row.chip, .chip, .white, at: CGPoint(x: r.midX, y: r.midY), align: .center, in: ctx)
                x += row.chipW + gap
            }
        }
        ctx.restoreGState()
    }

    // MARK: HUD

    private func drawHUD(in ctx: CGContext, at t: Double, alpha: CGFloat) {
        guard alpha > 0 else { return }
        ctx.saveGState()
        ctx.setAlpha(alpha)
        let left: CGFloat = 120, right: CGFloat = 960

        drawText(copy.title, .title, style.onInk, at: CGPoint(x: left, y: 268), in: ctx, maxWidth: 520)
        let shown = timeline.guessesShown(at: t)
        if shown > 0 {
            let counter = String(format: copy.guessOfFormat, shown, timeline.totalGuesses)
            drawText(counter, .counter, style.onInkDim, at: CGPoint(x: right, y: 272), align: .right,
                     in: ctx, maxWidth: 300)
        }

        let rowY: CGFloat = 352
        if let best = timeline.bestRank(at: t) {
            let band = ReplayBand(rank: best)
            let c = style.band(band)
            var x = left
            x += drawText(copy.best, .label, style.onInkDim, at: CGPoint(x: x, y: rowY), in: ctx) + 16
            x += drawText(ReplayFormat.rank(best), .rank, c, at: CGPoint(x: x, y: rowY - 2), in: ctx) + 16
            x += drawText(copy.bandNames[band] ?? band.token, .label, c, at: CGPoint(x: x, y: rowY), in: ctx)
            if timeline.outcome == .revealed, let last = timeline.tiles.last, t >= last.landsAt {
                x += drawText("·  " + copy.revealed, .label, style.onInkDim,
                              at: CGPoint(x: x + 16, y: rowY), in: ctx, maxWidth: right - x - 16) + 16
            }
            // Practice only: Wick stands on the final tile, so the answer goes
            // up here too once that tile lands. Both the flag and the word
            // must be set.
            if let last = timeline.tiles.last, t >= last.landsAt,
               timeline.showAnswer, let answer = timeline.answer {
                drawText("·  " + answer, .hudAnswer, style.gold.mixed(.white, 0.5),
                         at: CGPoint(x: x + 16, y: rowY), in: ctx, maxWidth: right - x - 16)
            }
            drawMeter(in: ctx, at: t, best: best, color: c)
        } else {
            drawText(copy.tagline, .tagline, style.onInkDim, at: CGPoint(x: left, y: rowY), in: ctx,
                     maxWidth: right - left)
        }

        drawText(copy.domain, .watermark, style.violet.mixed(.white, 0.35),
                 at: CGPoint(x: 540, y: 1488), align: .center, in: ctx, alpha: 0.75)
        ctx.restoreGState()
    }

    /// The closeness meter eases to each new best instead of snapping.
    private func drawMeter(in ctx: CGContext, at t: Double, best: Int, color: ReplayRGBA) {
        let track = CGRect(x: 120, y: 404, width: 840, height: 14)
        ctx.addPath(roundedPath(track, 7))
        ctx.setFillColor(ReplayRGBA.white.cg(0.10))
        ctx.fillPath()

        var fill = ReplayFormat.fill(rank: best, maxRank: request.maxRank)
        if let setter = timeline.tiles.first(where: { $0.rank == best && $0.landsAt <= t }) {
            let previous = timeline.bestRank(at: setter.landsAt - 0.0001)
            let from = previous.map { ReplayFormat.fill(rank: $0, maxRank: request.maxRank) } ?? 0
            fill = from + (fill - from) * ReplayEase.easeOut(ReplayEase.clamp((t - setter.landsAt) / 0.4))
        }
        let w = max(14, track.width * CGFloat(fill))
        let bar = CGRect(x: track.minX, y: track.minY, width: w, height: track.height)
        ctx.addPath(roundedPath(bar, 7))
        ctx.setFillColor(color.cg())
        ctx.fillPath()
    }

    /// "COLD → HOT" over the board when a big jump lands.
    private func drawFlash(in ctx: CGContext, at t: Double) {
        for tile in timeline.tiles {
            guard case .bigJump(let from)? = tile.emphasis else { continue }
            let dt = t - tile.landsAt
            guard dt > 0, dt < 1.5 else { continue }
            let text = "\((copy.bandNames[from] ?? from.token).uppercased())  →  \((copy.bandNames[tile.band] ?? tile.band.token).uppercased())"
            let scale = CGFloat(dt < 0.25 ? ReplayEase.easeOutBack(dt / 0.25) : 1)
            let alpha = CGFloat(ReplayEase.clamp((1.5 - dt) / 0.3))
            let center = CGPoint(x: 540, y: Self.boardArea.midY)
            let w = min(980, textWidth(text, .flash) + 80)
            ctx.saveGState()
            ctx.setAlpha(alpha)
            ctx.translateBy(x: center.x, y: center.y)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -center.x, y: -center.y)
            let pill = CGRect(x: center.x - w / 2, y: center.y - 70, width: w, height: 140)
            ctx.addPath(roundedPath(pill, 70))
            ctx.setFillColor(style.ink.cg(0.82))
            ctx.fillPath()
            ctx.addPath(roundedPath(pill, 70))
            ctx.setStrokeColor(style.band(tile.band).cg(0.9))
            ctx.setLineWidth(4)
            ctx.strokePath()
            drawText(text, .flash, style.band(tile.band), at: center, align: .center, in: ctx,
                     maxWidth: w - 60)
            ctx.restoreGState()
        }
    }

    /// "» +8 guesses" while a fast-forward burst plays.
    private func drawBurstBadge(in ctx: CGContext, at t: Double) {
        guard let i = timeline.beatIndex(at: t), case .place(let slots) = timeline.beats[i].kind,
              slots.count > 1 else { return }
        let beat = timeline.beats[i]
        let alpha = CGFloat(min(ReplayEase.clamp((t - beat.start) / 0.15), ReplayEase.clamp((beat.end - t) / 0.15)))
        let text = String(format: copy.fastForwardFormat, slots.count)
        let w = textWidth(text, .badge) + 104
        let pill = CGRect(x: 540 - w / 2, y: 432, width: w, height: 60)
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.addPath(roundedPath(pill, 30))
        ctx.setFillColor(style.violet.cg(0.9))
        ctx.fillPath()
        // Two small "fast forward" triangles.
        ctx.setFillColor(ReplayRGBA.white.cg())
        for k in 0..<2 {
            let x0 = pill.minX + 26 + CGFloat(k) * 18
            let tri = CGMutablePath()
            tri.move(to: CGPoint(x: x0, y: pill.midY - 12))
            tri.addLine(to: CGPoint(x: x0 + 18, y: pill.midY))
            tri.addLine(to: CGPoint(x: x0, y: pill.midY + 12))
            tri.closeSubpath()
            ctx.addPath(tri)
            ctx.fillPath()
        }
        drawText(text, .badge, .white, at: CGPoint(x: pill.minX + 80, y: pill.midY), in: ctx)
        ctx.restoreGState()
    }

    // MARK: End card

    private func drawEndCard(in ctx: CGContext, at t: Double) {
        guard let beat = timeline.beats.last, beat.kind == .endCard, t >= beat.start else { return }
        let local = t - beat.start
        let dim = CGFloat(ReplayEase.clamp(local / 0.45))
        ctx.setFillColor(style.ink.cg(0.95 * dim))
        ctx.fill(CGRect(origin: .zero, size: Self.size))

        let a = CGFloat(ReplayEase.clamp((local - 0.25) / 0.4))
        guard a > 0 else { return }
        ctx.saveGState()
        ctx.setAlpha(a)

        let glowColors = [style.violet.cg(0.35), style.violet.cg(0)] as CFArray
        if let g = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 540, y: 740), startRadius: 0,
                                   endCenter: CGPoint(x: 540, y: 740), endRadius: 420, options: [])
        }
        let look: WickLook = timeline.outcome == .solved ? .celebrating : .idle
        let rise = CGFloat(1 - ReplayEase.easeOut(ReplayEase.clamp((local - 0.25) / 0.5))) * 60
        drawWick(in: ctx, feet: CGPoint(x: 540, y: 880 + rise), size: 230, look: look, t: t,
                 squash: 1, lookDirection: 0, standing: true)

        drawText(copy.challenge ?? copy.playFree, .endSmall, style.onInk, at: CGPoint(x: 540, y: 1010),
                 align: .center, in: ctx, maxWidth: 900)
        drawText(copy.domain, .endBig, style.violet.mixed(.white, 0.45), at: CGPoint(x: 540, y: 1120),
                 align: .center, in: ctx, maxWidth: 940)
        drawText("\(copy.title)  ·  \(copy.stats)", .endStats, style.onInkDim,
                 at: CGPoint(x: 540, y: 1232), align: .center, in: ctx, maxWidth: 900)
        // Practice only: the answer. Both the flag and the word must be set.
        if timeline.showAnswer, let answer = timeline.answer {
            drawText(String(format: copy.answerWasFormat, answer), .endAnswer, style.gold.mixed(.white, 0.5),
                     at: CGPoint(x: 540, y: 1330), align: .center, in: ctx, maxWidth: 900)
        }
        ctx.restoreGState()
    }

    // MARK: Text

    nonisolated enum FontRole: String {
        case title, counter, label, rank, tagline, tile, tileMark, tileRank, chip, flash, badge, watermark
        case endSmall, endBig, endStats, hudAnswer, endAnswer
    }

    nonisolated enum Align { case left, center, right }

    private static func font(_ size: CGFloat, _ weight: UIFont.Weight) -> CTFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size) as CTFont
    }

    private func line(_ text: String, _ role: FontRole, _ color: ReplayRGBA) -> CTLine {
        let key = "\(role.rawValue)|\(color.key)|\(text)"
        if let cached = lines[key] { return cached }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): fonts[role] ?? Self.font(36, .regular),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cg(),
        ]
        let made = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
        lines[key] = made
        return made
    }

    private func textWidth(_ text: String, _ role: FontRole) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, role, .white), nil, nil, nil))
    }

    /// Draws one line of text vertically centered on `point.y`. Shrinks to
    /// fit `maxWidth`. Returns the drawn width.
    @discardableResult
    private func drawText(_ text: String, _ role: FontRole, _ color: ReplayRGBA, at point: CGPoint,
                          align: Align = .left, in ctx: CGContext, scale: CGFloat = 1,
                          alpha: CGFloat = 1, maxWidth: CGFloat? = nil) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let l = line(text, role, color)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(l, &ascent, &descent, &leading))
        var k = scale
        if let maxWidth, width * k > maxWidth, width > 0 { k = maxWidth / width }
        let drawn = width * k
        let x: CGFloat
        switch align {
        case .left:   x = point.x
        case .center: x = point.x - drawn / 2
        case .right:  x = point.x - drawn
        }
        let baseline = point.y + (ascent - descent) / 2 * k
        ctx.saveGState()
        if alpha < 1 { ctx.setAlpha(alpha) }
        ctx.translateBy(x: x, y: baseline)
        ctx.scaleBy(x: k, y: k)
        // This context is flipped (y grows down); flip glyphs back upright.
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(l, ctx)
        ctx.restoreGState()
        return drawn
    }

    /// A font at a pixel size and weight, cached, for text that must fit.
    private func sizedFont(_ size: CGFloat, _ weight: UIFont.Weight = .heavy) -> CTFont {
        let key = Int((size * 2).rounded()) * 10 + Int((weight.rawValue + 1) * 4)
        if let cached = sizedFonts[key] { return cached }
        let made = Self.font((size * 2).rounded() / 2, weight)
        sizedFonts[key] = made
        return made
    }

    private func sizedLine(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight = .heavy,
                           color: ReplayRGBA = .white) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): sizedFont(size, weight),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cg(),
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
    }

    /// The line that fits `maxWidth`: shrink the font from `size` down to
    /// `minSize`; if it still does not fit, cut the text and add an ellipsis.
    /// Works for wide Chinese characters the same as for long Latin words.
    private func fittedLine(_ text: String, size: CGFloat, minSize: CGFloat, weight: UIFont.Weight,
                            maxWidth: CGFloat, color: ReplayRGBA = .white) -> (line: CTLine, width: CGFloat) {
        func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }
        var px = size
        var l = sizedLine(text, px, weight, color: color)
        let step = max(1, size * 0.06)
        while px > minSize, width(l) > maxWidth {
            px = max(minSize, px - step)
            l = sizedLine(text, px, weight, color: color)
        }
        if width(l) > maxWidth {
            let chars = Array(text)
            var n = chars.count - 1
            while n > 1, width(sizedLine(String(chars[0..<n]) + "\u{2026}", px, weight, color: color)) > maxWidth { n -= 1 }
            l = sizedLine(String(chars[0..<max(1, n)]) + "\u{2026}", px, weight, color: color)
        }
        return (l, min(maxWidth, width(l)))
    }

    /// Draws a prepared line with its left edge at `point.x`, vertically
    /// centered on `point.y`.
    private func drawLine(_ l: CTLine, at point: CGPoint, in ctx: CGContext) {
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(l, &ascent, &descent, &leading)
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y + (ascent - descent) / 2)
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(l, ctx)
        ctx.restoreGState()
    }

    /// A word on a tile: fitted (see `fittedLine`), centered on `point`, white.
    private func drawFitted(_ text: String, at point: CGPoint, size: CGFloat, minSize: CGFloat,
                            maxWidth: CGFloat, in ctx: CGContext) {
        guard !text.isEmpty else { return }
        let f = fittedLine(text, size: size, minSize: minSize, weight: .heavy, maxWidth: maxWidth)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(f.line, &ascent, &descent, &leading))
        let k: CGFloat = w > maxWidth && w > 0 ? maxWidth / w : 1
        ctx.saveGState()
        ctx.translateBy(x: point.x - w * k / 2, y: point.y + (ascent - descent) / 2 * k)
        ctx.scaleBy(x: k, y: k)
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(f.line, ctx)
        ctx.restoreGState()
    }

    // MARK: Shapes and easing

    private func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let limit = max(0, min(r.width, r.height) / 2 - 0.01)
        let rad = max(0, min(radius, limit))
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    private func starPath(center c: CGPoint, radius: CGFloat, points: Int) -> CGPath {
        let path = CGMutablePath()
        let inner = radius * 0.45
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? radius : inner
            let a = -Double.pi / 2 + Double(i) * .pi / Double(points)
            let p = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// A four-point twinkle.
    private func sparklePath(center c: CGPoint, radius r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let k = r * 0.28
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        path.closeSubpath()
        return path
    }
}

// MARK: - Easing

nonisolated enum ReplayEase {
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func easeIn(_ x: Double) -> Double { x * x }
    static func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}
