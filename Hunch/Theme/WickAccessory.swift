//
//  WickAccessory.swift
//  Hunch
//
//  Cosmetic props Wick can wear. Everything is drawn in SwiftUI shapes (no image
//  assets, same approach as the flame body in `KeeperView`), so items scale with
//  `size` and stay crisp. Purely cosmetic — no gameplay effect.
//
//  A player owns a set of accessory ids and equips at most one per slot. Catalog
//  data lives here; ownership/equip state lives in `WardrobeStore`; rendering is
//  driven from `KeeperView`.
//

import SwiftUI

// MARK: - Slot

/// One accessory may be equipped per slot, so hat + face + neck can combine.
enum AccessorySlot: String, CaseIterable, Codable, Equatable {
    case hat, eyes, face, mouth, neck
}

// MARK: - Catalog entry

struct WickAccessory: Identifiable, Equatable {
    let id: String          // stable, persisted (e.g. "hat.tophat")
    let slot: AccessorySlot
    let price: Int          // coins
    let nameKey: String     // Loc key → localized display name

    static func by(id: String) -> WickAccessory? { catalog.first { $0.id == id } }
    static func items(in slot: AccessorySlot) -> [WickAccessory] { catalog.filter { $0.slot == slot } }

    /// v1 set. Prices tiered by "fanciness": 150 / 300 / 600.
    static let catalog: [WickAccessory] = [
        // Hats
        WickAccessory(id: "hat.tophat",  slot: .hat,  price: 150, nameKey: "acc_tophat"),
        WickAccessory(id: "hat.party",   slot: .hat,  price: 150, nameKey: "acc_party"),
        WickAccessory(id: "hat.wizard",  slot: .hat,  price: 300, nameKey: "acc_wizard"),
        WickAccessory(id: "hat.crown",   slot: .hat,  price: 600, nameKey: "acc_crown"),
        // Eyes (replace Wick's eyeballs while he still emotes by color/mouth)
        WickAccessory(id: "eyes.googly", slot: .eyes, price: 150, nameKey: "acc_googly"),
        WickAccessory(id: "eyes.hearts", slot: .eyes, price: 300, nameKey: "acc_hearts"),
        WickAccessory(id: "eyes.star",   slot: .eyes, price: 300, nameKey: "acc_stars"),
        // Face
        WickAccessory(id: "face.glasses",slot: .face,  price: 300, nameKey: "acc_glasses"),
        WickAccessory(id: "face.monocle",slot: .face,  price: 300, nameKey: "acc_monocle"),
        // Mouth
        WickAccessory(id: "mouth.tongue",slot: .mouth, price: 150, nameKey: "acc_tongue"),
        // Neck
        WickAccessory(id: "neck.bowtie", slot: .neck,  price: 150, nameKey: "acc_bowtie"),
        WickAccessory(id: "neck.tie",    slot: .neck,  price: 150, nameKey: "acc_tie"),
    ]
}

// MARK: - Rendering

/// Draws a single accessory. Positioned by the caller (`KeeperView`) so it tracks
/// the flame; this view only knows how to draw the prop centered in its own space.
struct WickAccessoryView: View {
    let id: String
    let size: CGFloat

    private var felt: Color   { Color(red: 0.16, green: 0.16, blue: 0.19) }
    private var gold: Color   { HunchTheme.Palette.coin }

    var body: some View {
        switch id {
        case "hat.tophat":  topHat
        case "hat.party":   partyHat
        case "hat.wizard":  wizardHat
        case "hat.crown":   crown
        case "hat.santa":   santaHat
        case "eyes.googly", "eyes.hearts", "eyes.star": eyePair
        case "face.glasses":glasses
        case "face.monocle":monocle
        case "mouth.tongue":tongue
        case "neck.bowtie": bowtie
        case "neck.tie":    necktie
        default:            EmptyView()
        }
    }

    // MARK: Hats

    private var topHat: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(felt)
                .frame(width: size * 0.28, height: size * 0.24)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(gold).frame(width: size * 0.28, height: size * 0.045)
                }
            Ellipse().fill(felt)
                .frame(width: size * 0.44, height: size * 0.08)
                .offset(y: -size * 0.025)
        }
        .shadow(color: .black.opacity(0.22), radius: size * 0.03, y: size * 0.015)
    }

    private var partyHat: some View {
        ZStack(alignment: .top) {
            Triangle()
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.55),
                                              Color(red: 0.86, green: 0.30, blue: 0.42)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.30, height: size * 0.34)
            Circle().fill(gold)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(y: -size * 0.045)
        }
        .shadow(color: .black.opacity(0.18), radius: size * 0.025, y: size * 0.01)
    }

    private var wizardHat: some View {
        ZStack(alignment: .bottom) {
            Triangle()
                .fill(Color(red: 0.30, green: 0.25, blue: 0.62))
                .frame(width: size * 0.34, height: size * 0.40)
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: size * 0.07))
                        .foregroundStyle(gold)
                        .offset(y: size * 0.02)
                )
            Ellipse().fill(Color(red: 0.24, green: 0.20, blue: 0.52))
                .frame(width: size * 0.46, height: size * 0.08)
                .offset(y: size * 0.02)
        }
        .shadow(color: .black.opacity(0.2), radius: size * 0.03, y: size * 0.015)
    }

    private var crown: some View {
        CrownShape()
            .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.35), gold],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.42, height: size * 0.22)
            .overlay(
                HStack(spacing: size * 0.06) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(Color(red: 0.85, green: 0.25, blue: 0.35))
                            .frame(width: size * 0.05, height: size * 0.05)
                    }
                }
                .offset(y: size * 0.03)
            )
            .shadow(color: .black.opacity(0.22), radius: size * 0.03, y: size * 0.015)
    }

    /// Auto-worn seasonal hat ("Holiday Wick") — a red cone with a white fur brim
    /// and a pom-pom. Not sold in the wardrobe; equipped automatically by date.
    private var santaHat: some View {
        ZStack(alignment: .top) {
            Triangle()
                .fill(LinearGradient(colors: [Color(red: 0.86, green: 0.22, blue: 0.26),
                                              Color(red: 0.68, green: 0.13, blue: 0.17)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.32, height: size * 0.34)
            Circle().fill(.white)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(y: -size * 0.05)
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(.white)
                .frame(width: size * 0.36, height: size * 0.10)
                .offset(y: size * 0.035)
        }
        .shadow(color: .black.opacity(0.18), radius: size * 0.025, y: size * 0.01)
    }

    // MARK: Eyes

    /// The wardrobe tile shows the eyes as a pair; on Wick himself each eye is
    /// drawn by `KeeperView` via the shared `WickEye`.
    private var eyePair: some View {
        HStack(spacing: size * 0.16) {
            WickEye(id: id, size: size)
            WickEye(id: id, size: size)
        }
    }

    // MARK: Face

    /// Round spectacles with clear lenses (the eyes show through) — reads as
    /// glasses, not the opaque sunglasses we cut.
    private var glasses: some View {
        let lens = size * 0.21
        let frame = Color(red: 0.20, green: 0.20, blue: 0.24)
        return HStack(spacing: size * 0.06) {
            Circle().strokeBorder(frame, lineWidth: size * 0.022)
                .background(Circle().fill(.white.opacity(0.10)))
                .frame(width: lens, height: lens)
            Circle().strokeBorder(frame, lineWidth: size * 0.022)
                .background(Circle().fill(.white.opacity(0.10)))
                .frame(width: lens, height: lens)
        }
        .overlay(
            Rectangle().fill(frame).frame(width: size * 0.06, height: size * 0.02)
        )
    }

    private var monocle: some View {
        HStack(spacing: 0) {
            Circle()
                .stroke(gold, lineWidth: size * 0.02)
                .background(Circle().fill(.white.opacity(0.12)))
                .frame(width: size * 0.16, height: size * 0.16)
            Spacer().frame(width: size * 0.17)
        }
        .overlay(alignment: .bottomLeading) {
            Capsule().fill(gold)
                .frame(width: size * 0.015, height: size * 0.10)
                .offset(x: size * 0.06, y: size * 0.09)
        }
        // Nudge the whole monocle slightly left and down to sit over Wick's eye.
        .offset(x: -size * 0.07, y: size * 0.05)
    }

    // MARK: Mouth

    /// A cheeky tongue lolling out — sits just under Wick's mouth. Top edge is
    /// squared so it reads as coming from inside the mouth; bottom is rounded.
    private var tongue: some View {
        ZStack {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: size * 0.015, bottomLeading: size * 0.06,
                                   bottomTrailing: size * 0.06, topTrailing: size * 0.015)
            )
            .fill(Color(red: 0.95, green: 0.46, blue: 0.55))
            .frame(width: size * 0.11, height: size * 0.15)
            // center crease
            Capsule()
                .fill(Color(red: 0.80, green: 0.30, blue: 0.42))
                .frame(width: size * 0.012, height: size * 0.07)
                .offset(y: size * 0.01)
        }
        .shadow(color: .black.opacity(0.12), radius: size * 0.015, y: size * 0.006)
    }

    // MARK: Neck

    private var bowtie: some View {
        HStack(spacing: -size * 0.01) {
            Triangle().rotation(.degrees(-90))
                .fill(Color(red: 0.80, green: 0.20, blue: 0.28))
                .frame(width: size * 0.14, height: size * 0.16)
            Circle().fill(Color(red: 0.62, green: 0.14, blue: 0.20))
                .frame(width: size * 0.05, height: size * 0.05)
            Triangle().rotation(.degrees(90))
                .fill(Color(red: 0.80, green: 0.20, blue: 0.28))
                .frame(width: size * 0.14, height: size * 0.16)
        }
        .shadow(color: .black.opacity(0.15), radius: size * 0.02, y: size * 0.008)
    }

    /// A classic necktie: a small knot with a blade hanging down.
    private var necktie: some View {
        let c = Color(red: 0.78, green: 0.24, blue: 0.28)   // crimson
        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: size * 0.012)
                .fill(c)
                .frame(width: size * 0.06, height: size * 0.045)
            Triangle().rotation(.degrees(180))
                .fill(c)
                .frame(width: size * 0.10, height: size * 0.20)
        }
        // Hang it down from the neckline so the knot sits at the neck slot.
        .offset(y: size * 0.10)
        .shadow(color: .black.opacity(0.15), radius: size * 0.02, y: size * 0.008)
    }
}

// MARK: - Eye cosmetic (shared by the wardrobe tile and KeeperView)

/// One cosmetic eye, sized relative to the keeper `size` (its base eye width is
/// `size * 0.115`, matching KeeperView). Drawn identically in the wardrobe
/// preview and on Wick himself so what you buy is what you wear.
struct WickEye: View {
    let id: String
    let size: CGFloat

    var body: some View {
        let w = size * 0.13
        switch id {
        case "eyes.hearts":
            Image(systemName: "heart.fill")
                .font(.system(size: w * 1.25))
                .foregroundStyle(Color(red: 0.90, green: 0.24, blue: 0.36))
        case "eyes.star":
            Image(systemName: "star.fill")
                .font(.system(size: w * 1.3))
                .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.28))
        case "eyes.googly":
            ZStack {
                Circle().fill(.white)
                Circle().stroke(.black.opacity(0.35), lineWidth: max(1, w * 0.08))
                Circle().fill(.black)
                    .frame(width: w * 0.55, height: w * 0.55)
                    .offset(x: w * 0.12, y: w * 0.16)
            }
            .frame(width: w * 1.3, height: w * 1.3)
        default:
            EmptyView()
        }
    }
}

// MARK: - Small shapes

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct CrownShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.7))
        p.addLine(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.7))
        p.addLine(to: CGPoint(x: w, y: h * 0.35))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}
