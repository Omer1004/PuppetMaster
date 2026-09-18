import AVFoundation
import Observation

/// Coordinates where the puppet's jaw signal comes from.
///
/// Two sources, one interface: the real microphone, and the procedural fallback used
/// when permission is denied or unavailable. The engine cannot tell them apart, and
/// neither path is treated as degraded.
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

    init() {
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
            return
        }

        silly.reset()
        isTalking = true
    }

    func endTalking() {
        wantsToTalk = false
        guard isTalking else {
            mic.stop()   // may have started while a begin was still in flight
            return
        }
        isTalking = false
        mic.stop()
    }

    /// Let the user pick the babble deliberately, not only as a consolation prize.
    func useSillyVoice(_ silly: Bool) {
        let wasTalking = isTalking
        if wasTalking { endTalking() }
        source = silly ? .silly : (permission == .denied ? .silly : .microphone)
    }

    // MARK: Per-frame

    /// Current jaw drive, 0…1. Called once per frame from the clock.
    func level(delta: Double) -> Double {
        let raw: Double
        if isTalking {
            switch source {
            case .microphone: raw = mic.level
            case .silly:      raw = silly.update(delta: delta)
            }
        } else {
            raw = 0
        }
        meterSmoother.update(target: raw, delta: delta)
        if abs(meterSmoother.value - displayLevel) > 0.02 { displayLevel = meterSmoother.value }
        return raw
    }

    func teardown() { mic.teardown() }

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
