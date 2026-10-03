import AVFoundation
import Observation

/// Something that can play a prepared take back and say how far through it is.
/// `SoundBank` in the app; the seam keeps `VoiceInput` from owning the output engine.
@MainActor
protocol TakePlayer: AnyObject {
    /// Start playing. `false` if sound is off or the engine is not running.
    func playTake(_ take: PreparedTake) -> Bool
    func stopTake()
    /// Seconds into the take being played, or `nil` once it has finished or stopped.
    func takePosition() -> Double?
}

/// Coordinates where the puppet's jaw signal comes from.
///
/// Two live sources, one interface: the real microphone, and the procedural fallback
/// used when permission is denied or unavailable. The engine cannot tell them apart,
/// and neither path is treated as degraded. A third, when a voice effect is chosen: the
/// puppet repeating the take you just finished.
@MainActor
@Observable
final class VoiceInput {

    enum Source: Equatable {
        case microphone
        case silly          // permission denied, or the user chose it
    }

    enum PermissionState: Equatable {
        case notAsked
        case granted
        case denied
    }

    private(set) var source: Source = .microphone
    private(set) var permission: PermissionState = .notAsked
    private(set) var isTalking = false
    /// The puppet is saying your last take back to you.
    private(set) var isRepeating = false

    /// How the puppet sounds. Owned by `AppEnvironment`, which persists it.
    var effect: VoiceEffect = .off {
        didSet { if !effect.repeatsYou { cancelRepeat() } }
    }

    /// Where repeated takes are played. Set once by `AppEnvironment`.
    @ObservationIgnored weak var takePlayer: (any TakePlayer)?
    /// Smoothed level for the talk button's meter.
    private(set) var displayLevel: Double = 0

    /// What the user's finger is asking for, as distinct from what has actually
     /// started. `beginTalking()` suspends on the permission prompt, and a release
     /// during that suspension must not be lost — without this the puppet would carry
     /// on talking after the button came up, with no way back.
    @ObservationIgnored private var wantsToTalk = false
    @ObservationIgnored private let mic = MicAmplitudeSource()
    @ObservationIgnored private var silly = SillyVoiceDriver()
    @ObservationIgnored private var meterSmoother = Smoother(attack: 0.05, release: 0.18)
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var repeating: PreparedTake?

    /// A pause before the puppet repeats you. Long enough to read as the puppet
    /// thinking about it — and for the audio session to settle back to playback after
    /// the microphone lets go, which rebuilds the output graph.
    private static let repeatDelay: Duration = .milliseconds(350)

    init() {
        // The microphone reports hardware trouble; deciding what to do about it needs to
        // know whether a take is in progress, which only this type does.
        mic.onNeedsRestart = { [weak self] event in self?.recoverMicrophone(after: event) }
        // A call or Siri cut the take off. Half a sentence is not worth repeating.
        mic.onInterrupted = { [weak self] in self?.endTalking(repeatingTake: false) }

        switch MicAmplitudeSource.permission {
        case .granted:      permission = .granted
        case .denied:       permission = .denied; source = .silly
        case .undetermined: permission = .notAsked
        @unknown default:   permission = .notAsked
        }
    }

    // MARK: Talk

    /// Begin talking. Asks for the microphone the first time, and falls back to the
    /// silly voice rather than failing if that is refused.
    func beginTalking() async {
        guard !wantsToTalk else { return }
        wantsToTalk = true
        // Talking over the puppet stops it. It is your turn.
        cancelRepeat()

        // No usable input? Go straight to the procedural voice, and do not pester the
        // user for a microphone permission we would not be able to use.
        if source == .microphone, !MicAmplitudeSource.isInputUsable {
            source = .silly
        }

        if source == .microphone, permission == .notAsked {
            let granted = await MicAmplitudeSource.requestPermission()
            permission = granted ? .granted : .denied
            if !granted { source = .silly }
        }
        if source == .microphone, permission == .denied { source = .silly }

        if source == .microphone {
            mic.keepsTake = effect.repeatsYou
            do {
                try mic.start()
            } catch {
                // No usable input — fall back rather than show the user an error about
                // a puppet's mouth.
                source = .silly
            }
        }
        // The finger may have come up while we were waiting on the permission prompt
        // or starting the audio engine. If so, honour that and unwind.
        guard wantsToTalk else {
            mic.stop()
            _ = mic.collectTake()   // a take that was never wanted is not kept either
            return
        }

        silly.reset()
        isTalking = true
    }

    func endTalking() {
        endTalking(repeatingTake: true)
    }

    private func endTalking(repeatingTake: Bool) {
        wantsToTalk = false
        guard isTalking else {
            mic.stop()   // may have started while a begin was still in flight
            _ = mic.collectTake()
            return
        }
        isTalking = false
        mic.stop()
        // Always drained, so a take never outlives the press that made it — even when it
        // is not going to be repeated.
        let take = mic.collectTake()
        if repeatingTake, source == .microphone, effect.repeatsYou {
            scheduleRepeat(of: take.samples, sampleRate: take.sampleRate, effect: effect)
        }
    }

    // MARK: Repeating

    private func scheduleRepeat(of samples: [Float], sampleRate: Double, effect: VoiceEffect) {
        cancelRepeat()
        guard !samples.isEmpty else { return }
        repeatTask = Task { [weak self] in
            // Off the main thread: a few hundred thousand samples is a few milliseconds
            // in release and noticeably more in a debug build.
            let prepared = await Task.detached(priority: .userInitiated) {
                VoiceEffectDSP.prepare(samples, sampleRate: sampleRate, effect: effect)
            }.value
            try? await Task.sleep(for: Self.repeatDelay)
            guard !Task.isCancelled, let prepared, let self else { return }
            self.startRepeat(prepared)
        }
    }

    private func startRepeat(_ take: PreparedTake) {
        // The finger may be back on the button.
        guard !wantsToTalk, !isTalking, take.effect == effect,
              takePlayer?.playTake(take) == true else { return }
        repeating = take
        isRepeating = true
    }

    /// Stop the puppet repeating you, and forget the take. For the app going away.
    func stopRepeating() { cancelRepeat() }

    private func cancelRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
        if repeating != nil { takePlayer?.stopTake() }
        repeating = nil
        isRepeating = false
    }

    /// Let the user pick the babble deliberately, not only as a consolation prize.
    func useSillyVoice(_ silly: Bool) {
        let wasTalking = isTalking
        if wasTalking { endTalking() }
        cancelRepeat()
        source = silly ? .silly : (permission == .denied ? .silly : .microphone)
    }

    // MARK: Per-frame

    /// The silly-voice syllable that began this frame, if any — for `SoundBank` to say
    /// out loud. Read after `level(delta:)`.
    var syllableOnset: SillyVoiceDriver.Syllable? {
        isTalking && source == .silly ? silly.onset : nil
    }

    /// Current jaw drive, 0…1. Called once per frame from the clock.
    func level(delta: Double) -> Double {
        let raw: Double
        if isTalking {
            switch source {
            case .microphone: raw = mic.level
            case .silly:      raw = silly.update(delta: delta)
            }
        } else if let take = repeating {
            if let position = takePlayer?.takePosition() {
                raw = take.jaw(at: position)
            } else {
                // Finished, or the output went away. Either way the mouth closes.
                repeating = nil
                isRepeating = false
                raw = 0
            }
        } else {
            raw = 0
        }
        meterSmoother.update(target: raw, delta: delta)
        if abs(meterSmoother.value - displayLevel) > 0.02 { displayLevel = meterSmoother.value }
        return raw
    }

    /// The audio hardware was reconfigured underneath us — a headphone plugged in, a
    /// call ending, media services restarting. Rebuild, and if the microphone cannot be
    /// brought back mid-sentence, carry on in the silly voice rather than going quiet.
    /// A puppet that stops moving its mouth reads as a broken app.
    private func recoverMicrophone(after event: AudioRecovery.Event) {
        guard source == .microphone else { return }
        if !mic.restart(after: event), isTalking {
            source = .silly
            silly.reset()
            // Half a take is not worth repeating, and must not be kept.
            _ = mic.collectTake()
        }
    }

    // MARK: Presentation

    var talkButtonTitle: String {
        switch source {
        case .microphone: "Hold to Talk"
        case .silly:      "Hold for Silly Voice"
        }
    }

    var talkButtonSymbol: String {
        switch source {
        case .microphone: "mic.fill"
        case .silly:      "waveform"
        }
    }
}
