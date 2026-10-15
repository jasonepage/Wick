// SPDX-License-Identifier: MPL-2.0
//
//  RaceMusic.swift
//  Hunch
//
//  Race music for live races (3.5). Made in GarageBand, all 120 BPM:
//
//    race_chill  a 16 bar (32 s) loop that plays from the start of a race.
//    race_riser  a 2 bar (4 s) build that plays into the switch.
//    race_kiai   a 16 bar loop that takes over when the race heats up: either
//                player reaches Hot, or a minute is left on the clock. It never
//                switches back.
//
//  The switch: the riser starts on the next bar line while chill ducks under
//  it, and kiai comes in from its own bar 1 as the riser ends. The riser and
//  kiai starts are scheduled on the audio clock, so they land on the beat.
//
//  Gapless looping. AAC adds a little silence at the start of a file, which
//  would click at every loop. So each file holds one extra second on both sides
//  (the loop's last second, the 32 s loop, its first second). We cut the 32 s
//  window starting at 1 s into a buffer and loop that buffer. Any 32 s window of
//  the file is a perfect loop, so a decoder's offset can't break it. The files
//  are built by debug/music/make_race_loops.py; the web plays the same files.
//
//  Plays only when both the Sound switch and its own Race music switch are on
//  (both default on). The session is `.ambient`, like `Sound`, so the silent
//  switch mutes it and the player's own music keeps playing underneath.
//

import AVFoundation

@MainActor
final class RaceMusic {
    static let shared = RaceMusic()

    /// Same cutoff as the Hot band (score 45 and up).
    nonisolated static let kiaiWarmth = 0.45
    nonisolated static let kiaiRemainingMs = 60_000

    /// Should the race be on the kiai track? Pure, so it can be tested.
    nonisolated static func wantsKiai(youBest: Double, oppBest: Double, remainingMs: Int) -> Bool {
        max(youBest, oppBest) >= kiaiWarmth || remainingMs <= kiaiRemainingMs
    }

    private static let loopSeconds: Double = 32
    private static let paddingSeconds: Double = 1
    private static let barSeconds: Double = 2      // one bar at 120 BPM
    private static let volume: Float = 0.6         // under the guess tones
    private static let fadeIn: Double = 1.5
    private static let fadeOut: Double = 1.2
    private static let riserSeconds: Double = 4    // 2 bars
    private static let duck: Float = 0.35          // chill level by the riser's end

    private let engine = AVAudioEngine()
    private let chill = AVAudioPlayerNode()
    private let kiai = AVAudioPlayerNode()
    private let riser = AVAudioPlayerNode()
    private var buffers: (chill: AVAudioPCMBuffer, kiai: AVAudioPCMBuffer?, riser: AVAudioPCMBuffer?)?
    private var wired = false
    private(set) var isPlaying = false
    private var kiaiOn = false
    private var fades: [Task<Void, Never>] = []

    private init() {}

    /// The Race music switch in Settings. Default on.
    static var enabled: Bool {
        Sound.enabled && (UserDefaults.standard.object(forKey: "hunch.music") as? Bool ?? true)
    }

    // MARK: - Intents

    /// Start the race music. Does nothing if it is already playing or the
    /// Sound switch is off.
    func start() {
        guard !isPlaying, Self.enabled, let buffers = loadBuffers() else { return }
        cancelFades()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])

        if !wired {
            engine.attach(chill)
            engine.attach(kiai)
            engine.attach(riser)
            engine.connect(chill, to: engine.mainMixerNode, format: buffers.chill.format)
            engine.connect(kiai, to: engine.mainMixerNode, format: (buffers.kiai ?? buffers.chill).format)
            engine.connect(riser, to: engine.mainMixerNode, format: (buffers.riser ?? buffers.chill).format)
            wired = true
        }
        engine.mainMixerNode.outputVolume = 0
        do { try engine.start() } catch { return }
        // A stop that is still fading out may have left the nodes running;
        // stopping clears their schedules so both restart together.
        chill.stop()
        kiai.stop()
        riser.stop()

        chill.volume = 1
        kiai.volume = 1
        riser.volume = 1
        chill.scheduleBuffer(buffers.chill, at: nil, options: .loops)
        chill.play()

        isPlaying = true
        kiaiOn = false
        fade(from: 0, to: Self.volume, over: Self.fadeIn) { [engine] v in engine.mainMixerNode.outputVolume = v }
    }

    /// Feed every race state in. Switches to kiai once: the riser starts on the
    /// next bar line and kiai lands on the downbeat after it.
    func update(youBest: Double, oppBest: Double, remainingMs: Int) {
        guard isPlaying, !kiaiOn, let kiaiBuffer = buffers?.kiai,
              Self.wantsKiai(youBest: youBest, oppBest: oppBest, remainingMs: remainingMs),
              let nodeTime = chill.lastRenderTime, nodeTime.isSampleTimeValid,
              let t = chill.playerTime(forNodeTime: nodeTime), t.sampleRate > 0 else { return }
        kiaiOn = true

        // Where chill is in its bar grid, and the next bar line at least 0.1 s out.
        let played = Double(t.sampleTime) / t.sampleRate
        let nextBar = ((played + 0.1) / Self.barSeconds).rounded(.up) * Self.barSeconds
        let wait = nextBar - played
        let riserBuffer = buffers?.riser
        let toKiai = wait + (riserBuffer == nil ? 0 : Self.riserSeconds)
        let rate = nodeTime.sampleRate
        func at(_ seconds: Double) -> AVAudioTime {
            AVAudioTime(sampleTime: nodeTime.sampleTime + AVAudioFramePosition(seconds * rate), atRate: rate)
        }

        if let riserBuffer {
            riser.scheduleBuffer(riserBuffer, at: nil)
            riser.play(at: at(wait))
            fade(from: 1, to: Self.duck, over: Self.riserSeconds, after: wait) { [chill] v in chill.volume = v }
        }
        kiai.scheduleBuffer(kiaiBuffer, at: nil, options: .loops)
        kiai.play(at: at(toKiai))
        fade(from: riserBuffer == nil ? 1 : Self.duck, to: 0, over: 0.06, after: toKiai) { [chill] v in chill.volume = v }
    }

    /// Fade the music out and stop it. Safe to call when nothing is playing.
    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        cancelFades()
        let from = engine.mainMixerNode.outputVolume
        let job = fade(from: from, to: 0, over: Self.fadeOut) { [engine] v in engine.mainMixerNode.outputVolume = v }
        fades.append(Task { [weak self] in
            await job.value
            guard let self, !self.isPlaying else { return }
            self.chill.stop()
            self.kiai.stop()
            self.riser.stop()
            self.engine.stop()
        })
    }

    // MARK: - Loading

    private func loadBuffers() -> (chill: AVAudioPCMBuffer, kiai: AVAudioPCMBuffer?, riser: AVAudioPCMBuffer?)? {
        if let buffers { return buffers }
        guard let c = loopBuffer(named: "race_chill") else { return nil }
        let loaded = (chill: c, kiai: loopBuffer(named: "race_kiai"), riser: wholeBuffer(named: "race_riser"))
        buffers = loaded
        return loaded
    }

    /// Reads a one-shot file (the riser) whole.
    private func wholeBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return buffer
    }

    /// Reads a padded file and returns just the 32 s loop window, starting 1 s in.
    private func loopBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        guard let whole = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: whole)) != nil else { return nil }
        let start = Int(Self.paddingSeconds * format.sampleRate)
        let count = Int(Self.loopSeconds * format.sampleRate)
        guard Int(whole.frameLength) >= start + count,
              let loop = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let src = whole.floatChannelData, let dst = loop.floatChannelData else { return nil }
        for ch in 0..<Int(format.channelCount) {
            dst[ch].update(from: src[ch].advanced(by: start), count: count)
        }
        loop.frameLength = AVAudioFrameCount(count)
        return loop
    }

    // MARK: - Fades

    /// Ramps a volume from `from` to `to` in steps of about 1/30 s, after an
    /// optional wait. Cancelled by `cancelFades`.
    @discardableResult
    private func fade(from: Float, to: Float, over: Double, after: Double = 0,
                      _ set: @escaping @MainActor (Float) -> Void) -> Task<Void, Never> {
        let task = Task { @MainActor in
            if after > 0 { try? await Task.sleep(for: .seconds(after)) }
            let steps = max(1, Int(over * 30))
            for i in 1...steps {
                if Task.isCancelled { return }
                set(from + (to - from) * Float(i) / Float(steps))
                try? await Task.sleep(for: .seconds(over / Double(steps)))
            }
        }
        fades.append(task)
        return task
    }

    private func cancelFades() {
        fades.forEach { $0.cancel() }
        fades.removeAll()
    }
}
