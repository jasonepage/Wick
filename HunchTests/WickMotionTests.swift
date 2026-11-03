// SPDX-License-Identifier: MPL-2.0
//
//  WickMotionTests.swift
//  HunchTests
//
//  The 3.8 motion director (WickMotion.swift). The golden numbers below are
//  printed by `node wick-web/tests/wickmotion.golden.ts`: if WickMotion.swift
//  and wickmotion.ts ever drift apart, `goldenNumbersMatchTheWeb` fails.
//  The behaviour checks mirror wick-web/tests/wickmotion.test.ts.
//

import Foundation
import Testing
@testable import Hunch

@MainActor
struct WickMotionTests {
    private func pulse(_ t: Double, riserAt: Double? = nil, kiaiAt: Double? = nil) -> WickMotion.Pulse {
        let p = RaceMusic.pulse(at: t, riserAt: riserAt, kiaiAt: kiaiAt)
        return WickMotion.Pulse(beat: p.beat, down: p.down, energy: p.energy, flash: p.flash, time: p.time)
    }

    private func check(_ m: WickMotion.Motion, _ want: [Double], _ label: String) {
        let got: [Double] = WickMotion.Channel.allCases.map { m[$0] }
        for i in 0..<want.count {
            #expect(abs(got[i] - want[i]) < 1e-9, "\(label) channel \(WickMotion.Channel.allCases[i]): \(got[i]) vs web \(want[i])")
        }
    }

    @Test func goldenNumbersMatchTheWeb() {
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "deflate")!, 0.2, 1, &m)
            check(m, [0.0, 0.0, 0.0, 0.0023703703703703708, -0.0047407407407407415, 0.058094475263999995, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 0.0], "clip:deflate@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "cold-shoulder")!, 0.2, 1, &m)
            check(m, [-0.011254629629629628, 0.0, -0.5627314814814813, -0.026033125031753288, -0.01682650002540263, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.09296308008482544, 0.09296308008482544], "clip:cold-shoulder@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "inspect")!, 0.2, 1, &m)
            check(m, [0.017977252466381006, 0.0, 2.4218722141273887, 0.022555846730210383, 0.012892971319146884, -0.1269399989838948, 0.0, 8.0, 10.0, 10.0, -5.0, 0.0, 0.0], "clip:inspect@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "interest")!, 0.2, 1, &m)
            check(m, [0.0, -0.022555846730210383, 0.0, -0.017640127877444508, 0.01730300328850801, 0.0, -2.6035156249999996, -9.0, 0.0, -5.632117570060094, -5.632117570060094, 0.0, 0.0], "clip:interest@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "caught")!, 0.2, 1, &m)
            check(m, [-0.026899691358024686, 0.0, -2.01304012345679, 0.009538580246913578, -0.01714814814814814, 0.09632263183593753, 0.0, 0.0, 0.0, -6.023065589595083, -6.023065589595083, -0.35, -0.35], "clip:caught@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "hide-panic")!, 0.2, 1, &m)
            check(m, [0.0, 0.0, 0.0, 0.008263580650919259, -0.012250669363955493, -0.5513471999999999, -1.9638481044282445, 0.8281250000000004, 0.0, -3.0704648096192964, -4.33808101202412, 0.0, 0.0], "clip:hide-panic@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "judge")!, 0.2, 1, &m)
            check(m, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.016052246093749223, 0.49999999999999956], "clip:judge@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "perk")!, 0.2, 1, &m)
            check(m, [0.0, 0.0, 0.0, 0.0219155534387664, 0.0179155534387664, 0.01618559999999994, -3.5316233317003887, 0.0, -3.0, -5.699277417183738, -5.699277417183738, 0.0, 0.0], "clip:perk@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "turn-away")!, 0.2, 1, &m)
            check(m, [-0.004127589135802468, 0.0, -0.9692863209876541, 0.0, 0.0, 0.002998526647360675, 0.0, -12.0, 0.0, 3.0, 0.0, 0.0, 0.0], "clip:turn-away@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.clipInto(WickMotion.Clip(rawValue: "face-lead")!, 0.2, 1, &m)
            check(m, [0.0, 0.0, 0.0, 0.0, 0.01, 0.0, 0.0, 0.0, -4.0, -7.693238811728395, -5.346619405864198, 0.0, 0.0], "clip:face-lead@0.2")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.phraseInto(.groove, 5.3, &m, 1)
            check(m, [0.0024365820677780294, 0.0, 0.2397888858590095, 0.017951857777777802, -0.029919762962963, -0.02856629978663312, 0.0, -0.026745679012345407, 0.0, 0.0, 0.0, 0.0, 0.0], "phrase:groove@5.3")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.phraseInto(.swagger, 5.3, &m, 1)
            check(m, [0.024527496943743746, 0.0, 3.5649079148094636, -0.021646850585937502, 0.03935791015625, -0.6173091592068759, 0.0, 0.06420898437499967, 0.0, 0.0, -0.25683593749999867, 0.0, 0.0], "phrase:swagger@5.3")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.phraseInto(.hype, 5.3, &m, 1)
            check(m, [0.03645438146082321, -0.21353501350959853, 3.8821041947764288, -0.041846000000000015, 0.06695360000000002, -0.7472912521678708, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "phrase:hype@5.3")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.danceInto(pulse(240.3, riserAt: 236, kiaiAt: 240), &m, style: .swagger)
            check(m, [0.0, -0.22, 0.0, -0.03245723404387145, 0.05076205673978574, -0.2801759999999333, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "drop@240.3")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.danceInto(WickMotion.Pulse(beat: 0.4, down: 0, energy: 0.6, flash: 0, time: 13.37), &m)
            check(m, [0.032131759870550655, 0.0, 3.6352030619866134, 0.0, 0.0, -0.3826611732901736, 0.0, -2.5321624495892907, 0.0, 0.0, -2.5321624495892907, 0.0, 0.0], "auto@13.37")
        }
        do {
            var m = WickMotion.Motion()
            WickMotion.idleBody(7.7, 1234, .warm, &m)
            check(m, [0.0, -0.007444516953738451, 0.0, -0.008188968649112296, 0.014889033907476902, 0.3948267095498655, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "idle:warm@7.7")
        }
        #expect(abs(WickMotion.hash01(1234, 5) - 0.5979941140394658) < 1e-12)
        do {
            let d = WickMotion.Director(seed: 77)
            _ = d.sample(0, WickMotion.Input(mood: .warm, rm: false))
            d.cue(1, kind: nil)
            _ = d.sample(1, WickMotion.Input(mood: .hot, rm: false, transitionE: 0))
            let a = d.sample(1.3, WickMotion.Input(mood: .hot, rm: false, transitionE: 0.3))
            check(a, [-0.026413250012701315, 0.0, -1.9809937509525986, 0.005206625006350657, -0.00561987501905197, 0.35, -1.0, 0.0, 0.0, -7.145570551476201, -7.145570551476201, -0.23889599999999991, -0.23889599999999991], "director:caught@1.3")
            d.cue(1.35, kind: "near")
            let b = d.sample(1.4, WickMotion.Input(mood: .boiling, rm: false, transitionE: 0.05))
            check(b, [-0.019619656170433583, -0.0016954123518179347, -1.502176728621757, -0.0007667658233678442, 0.005962179273243698, 0.3876278964604679, -1.0, 0.0, 0.0, -8.00586883215054, -9.40333049247073, -0.08778587654320992, -0.08778587654320992], "director:near@1.4")
        }
    }

    @Test func everyTemperatureHasItsOwnEntrance() {
        let want: [WickMotion.Mood: WickMotion.Clip] = [
            .grey: .deflate, .freezing: .coldShoulder, .cold: .inspect,
            .warm: .interest, .hot: .caught, .boiling: .hidePanic,
        ]
        for (mood, clip) in want { #expect(WickMotion.clipForCue(mood, nil)?.clip == clip) }
        #expect(WickMotion.clipForCue(.celebrating, nil) == nil)
        #expect(WickMotion.clipDur(.deflate) == 0.62)
        #expect(WickMotion.clipDur(.coldShoulder) == 0.52)
        #expect(WickMotion.clipDur(.inspect) == 0.68)
        #expect(WickMotion.clipDur(.interest) == 0.56)
        #expect(WickMotion.clipDur(.caught) == 0.65)
        #expect(WickMotion.clipDur(.hidePanic) == 0.76)
    }

    @Test func personalityBeatsPickTheirClips() {
        #expect(WickMotion.clipForCue(.cold, "repeat")?.clip == .judge)
        #expect(WickMotion.clipForCue(.warm, "leap")?.clip == .perk)
        #expect(WickMotion.clipForCue(.boiling, "near")?.clip == .hidePanic)
        #expect(WickMotion.clipForCue(.boiling, "near")?.amp == 0.7)
        #expect(WickMotion.clipForCue(.hot, "regress")?.clip == .turnAway)
        #expect(WickMotion.clipForCue(.grey, "stall")?.clip == .deflate)
        #expect(WickMotion.clipForCue(.idle, "question")?.clip == .faceLead)
        #expect(WickMotion.clipForCue(.cold, "topic")?.clip == .inspect)
    }

    @Test func everyClipEndsAtTheBasePose() {
        for clip in WickMotion.Clip.allCases {
            let def = WickMotion.clips[clip]!
            for (_, keys) in def.tracks {
                #expect(keys.last == 0)
                #expect(keys[keys.count - 2] <= def.dur + 1e-9)
            }
        }
    }

    @Test func rapidSecondGuessStartsFromThePoseOnScreen() {
        let d = WickMotion.Director(seed: 5)
        _ = d.sample(0, WickMotion.Input(mood: .warm, rm: false))
        d.cue(1, kind: nil)
        var prev = d.sample(1, WickMotion.Input(mood: .hot, rm: false))
        var t = 1 + 1.0 / 60
        while t < 1.25 { prev = d.sample(t, WickMotion.Input(mood: .hot, rm: false)); t += 1.0 / 60 }
        d.cue(1.25, kind: nil)
        let after = d.sample(1.25 + 1.0 / 60, WickMotion.Input(mood: .boiling, rm: false))
        #expect(abs(after.x - prev.x) < 0.012)
        #expect(abs(after.rot - prev.rot) < 0.6)
        #expect(abs(after.sx - prev.sx) < 0.012)
        #expect(abs(after.sy - prev.sy) < 0.012)
        #expect(d.activeClip(1.3) == .hidePanic)
    }

    @Test func solveOutranksEverything() {
        let d = WickMotion.Director(seed: 3)
        _ = d.sample(0, WickMotion.Input(mood: .warm, rm: false))
        let m = d.sample(1, WickMotion.Input(mood: .celebrating, rm: false, solveE: 0.5, pulse: pulse(1)))
        for c in WickMotion.Channel.allCases { #expect(abs(m[c]) < 1e-12) }
    }

    @Test func reducedMotionHasNoTranslationRotationOrBigScale() {
        for clip in WickMotion.Clip.allCases {
            let d = WickMotion.Director(seed: 7)
            _ = d.sample(0, WickMotion.Input(mood: .idle, rm: true))
            d.cue(1, kind: nil)
            let mood: WickMotion.Mood = WickMotion.moodClip.first(where: { $0.value == clip })?.key ?? .idle
            var t = 1.0
            while t < 2 {
                let m = d.sample(t, WickMotion.Input(mood: mood, rm: true, transitionE: t - 1, pulse: pulse(t, riserAt: 0, kiaiAt: 0.5)))
                #expect(m.x == 0 && m.y == 0 && m.rot == 0)
                #expect(abs(m.sx) <= 0.02 && abs(m.sy) <= 0.02)
                t += 0.01
            }
        }
    }

    @Test func colourTravelsUpTheFlame() {
        let w = WickMotion.colorWipe(0.12, rm: false)
        #expect(w.bottom > w.mid && w.mid > w.top)
        let done = WickMotion.colorWipe(0.24, rm: false)
        #expect(done.top > 0.999 && done.mid > 0.999 && done.bottom > 0.999)
        let rm = WickMotion.colorWipe(0.15, rm: true)
        #expect(rm.top == rm.mid && rm.mid == rm.bottom)
    }

    @Test func transitionBlinkTiming() {
        #expect(KeeperFaces.swapBlink(0.07) == 1)
        #expect(KeeperFaces.swapBlink(0.239) == 1)
        #expect(KeeperFaces.swapBlink(0.36) == 0)
        #expect(KeeperFaces.swapMorph(0.07) == 0)
        #expect(KeeperFaces.swapMorph(0.24) == 1)
    }

    @Test func idleStaysQuiet() {
        for mood in WickMotion.Mood.allCases {
            var maxY = 0.0, maxSy = 0.0
            var t = 0.0
            while t < 12 {
                var m = WickMotion.Motion()
                WickMotion.idleBody(t, 1234, mood, &m)
                maxY = max(maxY, abs(m.y)); maxSy = max(maxSy, abs(m.sy))
                t += 0.01
            }
            #expect(maxY <= 0.012)
            #expect(maxSy >= 0.0099 && maxSy <= 0.018 + 1e-9)
        }
    }

    @Test func accentsMoveTheFaceNotTheData() {
        var a = WickMotion.Motion()
        a.gx = 5; a.bl = -8; a.ll = -0.5; a.tu = -2
        let f = KeeperFaces.accent(KeeperFaces.sly, a)
        #expect(f.eyes[0].pdx == KeeperFaces.sly.eyes[0].pdx + 5)
        #expect(f.brows[0].c[1] == KeeperFaces.sly.brows[0].c[1] - 8)
        #expect(f.brows[1].c[1] == KeeperFaces.sly.brows[1].c[1])
        #expect(f.eyes[0].lidL == KeeperFaces.sly.eyes[0].lidL - 12)
        #expect(f.tip.dy == KeeperFaces.sly.tip.dy - 2)
    }
}
