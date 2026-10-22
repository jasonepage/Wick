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

    /// The chunky flame, in viewBox units. The same curve as
    /// KeeperChunkyFlameShape (KeeperFace.swift); keep the two in step.
    static func flamePath(flicker: Double, tip: KeeperTip) -> CGPath {
        let lean: Double = (flicker - 0.5) * KeeperFaces.lean
        let tx: Double = 60 + lean + tip.dx
        let ty: Double = 4 + tip.dy
        let sh: Double = 43.986 * tip.sharp
        let sy: Double = 20.605 + tip.dy * 0.5
        let sl: Double = lean * 0.6
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 60, y: 124))
        path.addCurve(to: CGPoint(x: 16, y: 67.2),
                      control1: CGPoint(x: 37.084, y: 124), control2: CGPoint(x: 16, y: 109.2))
        path.addCurve(to: CGPoint(x: tx, y: ty),
                      control1: CGPoint(x: 60 - sh + sl, y: sy), control2: CGPoint(x: tx, y: ty))
        path.addCurve(to: CGPoint(x: 104, y: 67.2),
                      control1: CGPoint(x: tx, y: ty), control2: CGPoint(x: 60 + sh + sl, y: sy))
        path.addCurve(to: CGPoint(x: 60, y: 124),
                      control1: CGPoint(x: 104, y: 109.2), control2: CGPoint(x: 82.916, y: 124))
        path.closeSubpath()
        return path
    }

    /// The inner flame (lighter core), in viewBox units. Same as KeeperPlateShape.
    static let platePath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 60, y: 53.5))
        path.addCurve(to: CGPoint(x: 84, y: 88.5),
                      control1: CGPoint(x: 72.2, y: 60.6), control2: CGPoint(x: 84, y: 68.8))
        path.addCurve(to: CGPoint(x: 60, y: 119.2),
                      control1: CGPoint(x: 84, y: 108.4), control2: CGPoint(x: 74.5, y: 119.2))
        path.addCurve(to: CGPoint(x: 36, y: 88.5),
                      control1: CGPoint(x: 45.5, y: 119.2), control2: CGPoint(x: 36, y: 108.4))
        path.addCurve(to: CGPoint(x: 60, y: 53.5),
                      control1: CGPoint(x: 36, y: 68.8), control2: CGPoint(x: 47.8, y: 60.6))
        path.closeSubpath()
        return path
    }()

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
        ctx.addPath(platePath)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22))
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
        fill(brows, cgColor(KeeperFaces.browGrey))
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
