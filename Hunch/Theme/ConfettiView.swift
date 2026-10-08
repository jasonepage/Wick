//
//  ConfettiView.swift
//  Hunch
//
//  A one-shot celebratory burst drawn with Canvas — little embers and sparks
//  that fly out from the Keeper and tumble down under gravity, then fade. Used
//  when a round is solved. UI-only, self-contained.
//
//  Accessibility: under Reduce Motion we skip the flying particles and show a
//  brief, motionless twinkle of sparkles that fades in and out instead.
//

import SwiftUI

struct ConfettiView: View {
    var colors: [Color] = [
        HunchTheme.Palette.coin, HunchTheme.Palette.solved,
        HunchTheme.Palette.hot, HunchTheme.Palette.warm, HunchTheme.Palette.keeper,
    ]
    var count: Int = 30
    var duration: Double = 1.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var bits: [Bit] = []

    /// One particle's fixed launch parameters (randomized once on appear).
    private struct Bit {
        let angle: Double       // launch direction (radians)
        let speed: Double       // launch speed (fraction of view height / sec)
        let spin: Double        // rotations per second
        let size: Double        // edge length in points
        let wobble: Double      // horizontal sway frequency
        let delay: Double       // stagger
        let isCircle: Bool      // ember (circle) vs confetti (rect)
        let colorIndex: Int
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = ctx.date.timeIntervalSince(startDate)
            Canvas { canvas, size in
                if reduceMotion {
                    drawReducedMotion(in: &canvas, size: size, elapsed: elapsed)
                } else {
                    drawBurst(in: &canvas, size: size, elapsed: elapsed)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startDate = Date()
            if bits.isEmpty { bits = Self.makeBits(count: count, colors: colors.count) }
        }
    }

    // MARK: - Full motion burst

    private func drawBurst(in canvas: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
        let gravity = size.height * 0.9     // pts/sec^2 (in view units)

        for bit in bits {
            let t = elapsed - bit.delay
            guard t >= 0 else { continue }
            if t > duration { continue }

            let v0 = bit.speed * size.height
            let vx = cos(bit.angle) * v0
            let vy = sin(bit.angle) * v0
            let sway = sin(t * bit.wobble) * size.width * 0.02
            let x = origin.x + vx * t + sway
            let y = origin.y + vy * t + 0.5 * gravity * t * t

            // Fade out over the last 45% of life.
            let life = t / duration
            let opacity = life < 0.55 ? 1.0 : max(0, 1 - (life - 0.55) / 0.45)
            guard opacity > 0.01 else { continue }

            let color = colors[bit.colorIndex % colors.count].opacity(opacity)
            let angle = Angle(radians: t * bit.spin * 2 * .pi)

            canvas.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: angle)
                let s = bit.size
                if bit.isCircle {
                    layer.fill(Path(ellipseIn: CGRect(x: -s/2, y: -s/2, width: s, height: s)), with: .color(color))
                } else {
                    let rect = CGRect(x: -s/2, y: -s*0.35, width: s, height: s * 0.7)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
                }
            }
        }
    }

    // MARK: - Reduce Motion: motionless twinkle

    private func drawReducedMotion(in canvas: inout GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < duration else { return }
        let fade = sin(min(1, elapsed / duration) * .pi)   // in then out
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
        for bit in bits.prefix(10) {
            let r = size.width * 0.18 + bit.speed * size.width * 0.25
            let x = center.x + cos(bit.angle) * r
            let y = center.y + sin(bit.angle) * r * 0.7
            let color = colors[bit.colorIndex % colors.count].opacity(fade)
            let s = bit.size
            canvas.fill(
                Path(ellipseIn: CGRect(x: x - s/2, y: y - s/2, width: s, height: s)),
                with: .color(color)
            )
        }
    }

    private static func makeBits(count: Int, colors: Int) -> [Bit] {
        (0..<count).map { _ in
            Bit(
                angle: Double.random(in: (-Double.pi * 0.95)...(-Double.pi * 0.05)), // upward fan
                speed: Double.random(in: 0.45...0.95),
                spin: Double.random(in: -1.6...1.6),
                size: Double.random(in: 6...11),
                wobble: Double.random(in: 6...12),
                delay: Double.random(in: 0...0.12),
                isCircle: Bool.random(),
                colorIndex: Int.random(in: 0..<max(1, colors))
            )
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
        ConfettiView()
    }
    .ignoresSafeArea()
}
