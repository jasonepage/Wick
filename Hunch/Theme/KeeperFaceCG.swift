//
//  KeeperFaceCG.swift
//  Hunch
//
//  Wick drawn with CoreGraphics (3.8), for the share replay video
//  (ReplayScene), which renders frames off the main thread into a CGContext.
//  It draws exactly what KeeperView draws: the chunky icon flame, the lighter
//  inner flame, and one of the six faces from KeeperFace.swift, using the same
//  numbers, shapes and shading. The web's version is wick-web/src/game/
//  wickcanvas.ts.
//
//  Units: everything is in Wick's viewBox units (120 wide, feet at (60, 124),
//  tip near y 4), top-left origin with y growing down. The caller sets the
//  transform that maps those units onto its canvas.
//

import CoreGraphics
import SwiftUI

nonisolated enum KeeperFaceCG {

    /// The asymmetric flame, in viewBox units. The same curve as
    /// KeeperChunkyFlameShape (KeeperFace.swift); keep the two in step.
    static func flamePath(flicker: Double, tip: KeeperTip) -> CGPath {
        let lean: Double = (flicker - 0.5) * KeeperFaces.lean
        let tx: Double = 48 + lean + tip.dx
        let ty: Double = 4 + tip.dy
        let trail: Double = -lean * 0.62
        let valley: Double = -lean * 0.22
        let tipWing: Double = 6 + 6 * tip.sharp
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 60, y: 124))
        path.addCurve(to: CGPoint(x: 16, y: 68),
                      control1: CGPoint(x: 37, y: 124), control2: CGPoint(x: 16, y: 109))
        path.addCurve(to: CGPoint(x: tx, y: ty),
                      control1: CGPoint(x: 16, y: 43), control2: CGPoint(x: 31, y: 25))
        path.addCurve(to: CGPoint(x: 63 + valley, y: 24),
                      control1: CGPoint(x: tx + tipWing * 0.58, y: ty + 7), control2: CGPoint(x: 58 + valley, y: 18))
        path.addCurve(to: CGPoint(x: 82 + trail, y: 14),
                      control1: CGPoint(x: 68 + trail, y: 20), control2: CGPoint(x: 77 + trail, y: 14))
        path.addCurve(to: CGPoint(x: 104, y: 68),
                      control1: CGPoint(x: 90 + trail, y: 25), control2: CGPoint(x: 104, y: 42))
        path.addCurve(to: CGPoint(x: 60, y: 124),
                      control1: CGPoint(x: 104, y: 109), control2: CGPoint(x: 83, y: 124))
        path.closeSubpath()
        return path
    }

    /// The inner flame (lighter core), in viewBox units. Same as KeeperPlateShape.
    static func platePath(flicker: Double) -> CGPath {
        let lean = (flicker - 0.5) * KeeperFaces.lean
        let main = lean * 0.55, trail = -lean * 0.34, valley = -lean * 0.12
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 60, y: 116))
        path.addCurve(to: CGPoint(x: 36, y: 86), control1: CGPoint(x: 47, y: 116), control2: CGPoint(x: 36, y: 108))
        path.addCurve(to: CGPoint(x: 54 + main, y: 47), control1: CGPoint(x: 36, y: 72), control2: CGPoint(x: 44, y: 59))
        path.addCurve(to: CGPoint(x: 62 + valley, y: 60), control1: CGPoint(x: 58 + main, y: 52), control2: CGPoint(x: 60 + valley, y: 57))
        path.addCurve(to: CGPoint(x: 73 + trail, y: 53), control1: CGPoint(x: 66 + trail, y: 57), control2: CGPoint(x: 70 + trail, y: 54))
        path.addCurve(to: CGPoint(x: 84, y: 86), control1: CGPoint(x: 78, y: 62), control2: CGPoint(x: 84, y: 73))
        path.addCurve(to: CGPoint(x: 60, y: 116), control1: CGPoint(x: 84, y: 108), control2: CGPoint(x: 73, y: 116))
        path.closeSubpath()
        return path
    }

    static func cgColor(_ c: KeeperRGB, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(c.r / 255), green: CGFloat(c.g / 255), blue: CGFloat(c.b / 255), alpha: alpha)
    }

    static func lighten(_ c: KeeperRGB, _ f: Double) -> KeeperRGB {
        KeeperRGB(r: c.r + (255 - c.r) * f, g: c.g + (255 - c.g) * f, b: c.b + (255 - c.b) * f)
    }

    /// The whole Wick in viewBox units: glow, body, inner flame, face.
    /// `glowBlur` is in OUTPUT pixels, because CoreGraphics shadows ignore the
    /// current transform.
    static func drawWick(in ctx: CGContext, face: KeeperFace, closure: [Double], color: KeeperRGB,
                         flicker: Double, glowBlur: CGFloat, glowAlpha: CGFloat) {
        let flame: CGPath = flamePath(flicker: flicker, tip: face.tip)

        // Glow: a soft shadow of the flame in its own colour.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: glowBlur, color: cgColor(color, glowAlpha))
        ctx.addPath(flame)
        ctx.setFillColor(cgColor(color))
        ctx.fillPath()
        ctx.restoreGState()

        // Body: lighter at the tip (lighten 12% at the top, body from 55% down).
        ctx.saveGState()
        ctx.addPath(flame)
        ctx.clip()
        let top: CGColor = cgColor(lighten(color, 0.12))
        let body: CGColor = cgColor(color)
        let colors: CFArray = [top, body, body] as CFArray
        let locations: [CGFloat] = [0, 0.55, 1]
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                     colors: colors, locations: locations) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 4), end: CGPoint(x: 0, y: 124), options: [])
        }
        ctx.restoreGState()

        // The inner flame: one tone step lighter (white at 22%).
        ctx.addPath(platePath(flicker: flicker))
        ctx.setFillColor(cgColor(lighten(color, 0.22)))
        ctx.fillPath()

        // The face, in the art's own units (see KeeperFaces.k).
        ctx.saveGState()
        let k: CGFloat = CGFloat(KeeperFaces.k)
        ctx.translateBy(x: 60 - 512 * k, y: 4 - 152 * k)
        ctx.scaleBy(x: k, y: k)
        drawFace(in: ctx, face: face, closure: closure, color: color)
        ctx.restoreGState()
    }

    /// The face, back to front, in art units. Mirrors KeeperFaces.draw(in:)
    /// step for step; keep the two in step.
    static func drawFace(in ctx: CGContext, face: KeeperFace, closure: [Double], color: KeeperRGB) {
        let plate: KeeperRGB = KeeperFaces.plateRGB(color)
        var shapes: [KeeperFaces.EyeShapes] = []
        for i in face.eyes.indices {
            let c: Double = i < closure.count ? closure[i] : 0
            shapes.append(KeeperFaces.eyeShapes(face.eyes[i], c))
        }
        let plateClip: CGPath = KeeperFaces.plateArt.cgPath
        func fill(_ p: Path, _ c: CGColor) {
            ctx.addPath(p.cgPath)
            ctx.setFillColor(c)
            ctx.fillPath()
        }
        func fillInPlate(_ p: Path, _ c: CGColor) {
            ctx.saveGState()
            ctx.addPath(plateClip)
            ctx.clip()
            fill(p, c)
            ctx.restoreGState()
        }
        func stroke(_ p: Path, _ c: CGColor, _ width: CGFloat) {
            ctx.addPath(p.cgPath)
            ctx.setStrokeColor(c)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }

        let bagBody: CGColor = cgColor(KeeperFaces.shadeRGB(color, color, 1))
        let bagPlate: CGColor = cgColor(KeeperFaces.shadeRGB(plate, color, 1))
        let lidBody: CGColor = cgColor(KeeperFaces.shadeRGB(color, color, 1.3))
        let lidPlate: CGColor = cgColor(KeeperFaces.shadeRGB(plate, color, 1.3))
        for s in shapes {
            fill(s.bag, bagBody)
            fillInPlate(s.bag, bagPlate)
            fill(s.lid, lidBody)
            fillInPlate(s.lid, lidPlate)
        }
        let white: CGColor = cgColor(KeeperFaces.eyeWhite)
        let pupil: CGColor = cgColor(KeeperFaces.pupil)
        for s in shapes {
            fill(s.white, white)
            fill(s.pupil, pupil)
            if s.lashOpacity > 0.001 {
                stroke(s.lash, cgColor(KeeperFaces.eyeWhite, CGFloat(s.lashOpacity)), 16)
            }
        }
        var brows = Path()
        for b in face.brows { brows.addPath(KeeperFaces.browPath(b)) }
        stroke(brows, cgColor(KeeperFaces.browKey(color), 0.72), 9)
        fill(brows, cgColor(KeeperFaces.browFill(color)))
        let m: KeeperMouth = face.mouth
        if m.oval < 0.999 {
            stroke(KeeperFaces.mouthStroke(m), cgColor(KeeperFaces.eyeWhite, CGFloat(1 - m.oval)), CGFloat(m.w))
        }
        if m.oval > 0.01 {
            fill(KeeperFaces.mouthOval(m), cgColor(KeeperFaces.pupil, CGFloat(m.oval)))
        }
        if face.drop.on > 0.01 {
            fill(KeeperFaces.dropPath(face.drop), cgColor(KeeperFaces.eyeWhite, CGFloat(face.drop.on)))
        }
    }
}
