import AVFoundation
import OSLog

/// Every sound the puppet makes, synthesised on demand.
///
/// Sounds are generated *at the requested pitch* rather than pitch-shifted after the
/// fact, so a character's voice costs nothing at playback time and there is no
/// `AVAudioUnitTimePitch` in the graph. Buffers are cached per (sound, pitch bucket);
/// each one is a few thousand samples, so the first generation is well under a
/// millisecond and every later use is a lookup.
@MainActor
final class SoundBank {

    /// Replaced rather than reused after a media services reset, which invalidates
    /// every object in the old graph.
    private var engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]
    /// Whether the app *wants* sound running. Whether it actually is, is
    /// `engine.isRunning` — the system stops the engine without telling this flag, and
    /// trusting it was one of two ways the app used to abort on device.
    private var isStarted = false
    private var observers: [any NSObjectProtocol] = []
    private let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "sound")

    /// Honours the app's sound setting. Off means silent, not quieter.
    var isEnabled = true {
        didSet { if !isEnabled { stopAll() } }
    }

    /// Enough voices that a rapid sequence never cuts itself off, few enough that the
    /// graph stays cheap.
    private static let voiceCount = 8
    private static let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate,
                                              channels: 1)!

    // MARK: Lifecycle

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeSystemAudioEvents()
        // `reactivate()` rather than `activateForPlayback()` for the same reason: at
        // cold start the intent is already playback so this is identical, and if the
        // app is ever restarted while input is live it does not silently drop it.
        AudioSession.reactivate()
        buildGraph()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        tearDownGraph()
    }

    private func buildGraph() {
        for _ in 0..<Self.voiceCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: Self.format)
            players.append(player)
        }
        engine.prepare()

        do {
            try engine.start()
            for player in players { player.play() }
        } catch {
            // No sound is a smaller loss than a crash; the puppet still performs.
            log.error("Sound engine did not start: \(error.localizedDescription)")
        }
    }

    private func tearDownGraph() {
        for player in players {
            player.stop()
            engine.detach(player)
        }
        players.removeAll()
        nextPlayer = 0
        engine.stop()
    }

    /// Silence anything ringing, without touching the graph.
    ///
    /// `play()` on a node whose engine is not running raises an Objective-C exception
    /// that Swift cannot catch, so it is only ever called behind `engine.isRunning`.
    private func stopAll() {
        let running = engine.isRunning
        for player in players {
            player.stop()
            if running { player.play() }
        }
    }

    // MARK: Surviving the system

    /// The audio hardware belongs to the system, not to this app. Switching the session
    /// category for the microphone, a phone call, or a pair of headphones all
    /// reconfigure it — and a reconfiguration stops this engine and invalidates every
    /// connection made with an explicit format, which is all of them. See
    /// `docs/MIC-CRASH.md`.
    private func observeSystemAudioEvents() {
        guard observers.isEmpty else { return }
        let centre = NotificationCenter.default

        observers.append(centre.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild(freshEngine: false) }
            })

        observers.append(centre.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild(freshEngine: true) }
            })

        observers.append(centre.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw),
                      type == .ended else { return }
                MainActor.assumeIsolated { self?.rebuild(freshEngine: false) }
            })
    }

    /// Put the graph back after the system pulled it apart.
    ///
    /// A media services reset invalidates the engine object itself, so that case gets a
    /// new one — and with it new observers, because the configuration-change
    /// notification is posted by a specific engine instance.
    private func rebuild(freshEngine: Bool) {
        guard isStarted else { return }
        tearDownGraph()
        if freshEngine {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
            engine = AVAudioEngine()
            observeSystemAudioEvents()
        }
        // Re-assert, never downgrade. The notification that brings us here is most
        // often the microphone upgrading the session — so calling `activateForPlayback`
        // here pulled the category back to `.playback` while the user was still holding
        // Talk, and the microphone then upgraded again. The two engines fought each
        // other for the whole take.
        AudioSession.reactivate()
        buildGraph()
        log.info("Sound graph rebuilt after a system audio change")
    }

    // MARK: Playing

    /// `pitch` multiplies the sound's natural frequency — 1.4 for a small excitable
    /// character, 0.66 for a large slow one.
    func play(_ sound: SoundID, pitch: Double = 1, volume: Float = 1) {
        // Asked of the engine, never of a cached flag. The system stops the engine
        // during a session change, and scheduling into a stopped one is undefined.
        guard isEnabled, isStarted, engine.isRunning, !players.isEmpty else { return }
        guard let buffer = buffer(for: sound, pitch: pitch) else { return }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.volume = volume
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: Generation

    private func buffer(for sound: SoundID, pitch: Double) -> AVAudioPCMBuffer? {
        // Bucket the pitch so four characters do not become an unbounded cache.
        let bucket = (pitch.clamped(to: 0.4...2.2) * 20).rounded() / 20
        let key = "\(sound.rawValue)-\(bucket)"
        if let cached = cache[key] { return cached }

        let samples = Synth.normalised(Self.render(sound, pitch: bucket), peak: peak(for: sound))
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: Self.format,
                                            frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<samples.count { channel[i] = samples[i] }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        cache[key] = buffer
        return buffer
    }

    /// Relative loudness, so a tick does not arrive at the same level as a landing.
    private func peak(for sound: SoundID) -> Float {
        switch sound {
        case .tap:            0.18
        case .tick:           0.30
        case .whoosh, .yawn:  0.42
        case .pop, .squeak:   0.55
        case .giggle, .chime: 0.62
        case .boing:          0.70
        case .sneeze, .thud:  0.85
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func render(_ sound: SoundID, pitch p: Double) -> [Float] {
        switch sound {

        case .pop:
            // Rising blip. The upward sweep is what makes it read as "light".
            return Synth.tone(duration: 0.13,
                              frequency: { 430 * p * (1 + $0 * 5.2) },
                              amplitude: { Synth.decay($0, 0.13, power: 5) },
                              harmonic: 0.25)

        case .boing:
            // Sweep up with a wobble on top — a spring, not a slide whistle.
            return Synth.tone(duration: 0.30,
                              frequency: { 170 * p * (1 + $0 * 3.4) * (1 + 0.16 * sin(2 * .pi * 17 * $0)) },
                              amplitude: { Synth.decay($0, 0.30, power: 2.6) },
                              harmonic: 0.35)

        case .thud:
            // Body plus knock. Either alone sounds wrong: the low tone has no contact,
            // the noise has no mass.
            let body = Synth.tone(duration: 0.26,
                                  frequency: { 118 * p * pow(0.42, $0 * 6) + 38 * p },
                                  amplitude: { Synth.decay($0, 0.26, power: 3.2) },
                                  harmonic: 0.5)
            let knock = Synth.noise(duration: 0.26,
                                    colour: { 0.55 - $0 * 1.6 },
                                    amplitude: { Synth.decay($0, 0.05, attack: 0.001, power: 3) * 0.7 })
            return Synth.mix([body, knock])

        case .whoosh:
            // Moved air: bright in the middle, dark at both ends.
            return Synth.noise(duration: 0.32,
                               colour: { 0.04 + Synth.swell($0, 0.32) * 0.30 },
                               amplitude: { pow(Synth.swell($0, 0.32), 1.6) })

        case .giggle:
            // Four short rising blips, each a little higher and shorter than the last.
            let steps: [(Double, Double, Double)] = [(0.00, 1.00, 0.075), (0.10, 1.18, 0.070),
                                                     (0.19, 1.09, 0.065), (0.27, 1.32, 0.060)]
            let total = 0.40
            return Synth.mix(steps.map { offset, scale, length in
                Synth.at(offset,
                         Synth.tone(duration: length,
                                    frequency: { 520 * p * scale * (1 + $0 * 1.5) },
                                    amplitude: { Synth.decay($0, length, power: 2.2) },
                                    harmonic: 0.45),
                         duration: total)
            })

        case .chime:
            // A major third plus an octave, long decay. Unambiguously "good news".
            let voices: [(Double, Double, Double)] = [(1.0, 0.85, 0.0), (1.26, 0.55, 0.02),
                                                      (2.0, 0.40, 0.04)]
            let total = 0.85
            return Synth.mix(voices.map { ratio, level, offset in
                Synth.at(offset,
                         Synth.tone(duration: total - offset,
                                    frequency: { _ in 880 * p * ratio },
                                    amplitude: { Synth.decay($0, total - offset, power: 2.4) * level }),
                         duration: total)
            })

        case .tick:
            return Synth.tone(duration: 0.055,
                              frequency: { 1150 * p * (1 - $0 * 2) },
                              amplitude: { Synth.decay($0, 0.055, attack: 0.001, power: 6) })

        case .sneeze:
            // Quiet inhale, then the burst. The gap between them is the whole gag.
            let total = 0.44
            let inhale = Synth.at(0.0,
                Synth.noise(duration: 0.17,
                            colour: { 0.05 + $0 * 0.20 },
                            amplitude: { Synth.swell($0, 0.17) * 0.22 }),
                duration: total)
            let burst = Synth.at(0.18,
                Synth.noise(duration: 0.24,
                            colour: { 0.75 - $0 * 2.2 },
                            amplitude: { Synth.decay($0, 0.24, attack: 0.006, power: 2.4) }),
                duration: total)
            let voice = Synth.at(0.18,
                Synth.tone(duration: 0.22,
                           frequency: { 740 * p * pow(0.34, $0 * 3.4) },
                           amplitude: { Synth.decay($0, 0.22, attack: 0.006, power: 2.6) * 0.55 },
                           harmonic: 0.4),
                duration: total)
            return Synth.mix([inhale, burst, voice])

        case .yawn:
            // Slow glide down and back up, with a slight waver. Contagious if it is
            // long enough, which is why it runs almost a second.
            return Synth.tone(duration: 0.95,
                              frequency: { t in
                                  let shape = 1 - 0.42 * sin(min(t / 0.95, 1) * .pi)
                                  return 300 * p * shape * (1 + 0.03 * sin(2 * .pi * 5.5 * t))
                              },
                              amplitude: { Synth.swell($0, 0.95) * 0.9 },
                              harmonic: 0.55)

        case .squeak:
            // Up then down, fast. A rubber toy being stood on.
            return Synth.tone(duration: 0.16,
                              frequency: { 640 * p * (1 + sin(min($0 / 0.16, 1) * .pi) * 1.5) },
                              amplitude: { Synth.swell($0, 0.16) },
                              harmonic: 0.3)

        case .tap:
            return Synth.tone(duration: 0.03,
                              frequency: { 900 * p * (1 - $0 * 3) },
                              amplitude: { Synth.decay($0, 0.03, attack: 0.001, power: 5) })
        }
    }
}
