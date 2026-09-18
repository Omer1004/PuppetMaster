import AVFoundation
import OSLog

/// Turns microphone loudness into a 0…1 signal for the puppet's jaw.
///
/// Deliberately **not** speech recognition. Loudness is enough to sell talking, works
/// in every language, needs no model and no network, and keeps the privacy story
/// something you can say in one sentence: we measure how loud it is, we do not listen
/// to what you say. Nothing is written to disk and nothing leaves the device.
///
/// Almost everything below the amplitude maths is about surviving a real device, where
/// the audio hardware is reconfigured out from under you by phone calls, Siri,
/// headphones and this app's own audio session changes. `docs/MIC-CRASH.md` has the
/// full account of what went wrong before it did.
@MainActor
final class MicAmplitudeSource {

    /// Replaced wholesale rather than reused after the system pulls the rug out: a
    /// media services reset invalidates every object in the old graph.
    private var engine = AVAudioEngine()
    private let box = AmplitudeBox()
    private var isTapped = false
    /// The format the live tap was installed with. Kept so a configuration change can
    /// be answered with "did the hardware actually move?" rather than always assuming
    /// the worst — see `handleConfigurationChange()`.
    private var installedTapFormat: AVAudioFormat?
    private let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "mic")
    private var observers: [any NSObjectProtocol] = []

    /// The system reconfigured the audio hardware and this engine must be rebuilt.
    /// Owned by `VoiceInput`, which is the only thing that knows whether a take is in
    /// progress and what to fall back to.
    var onNeedsRestart: (() -> Void)?

    /// A phone call, Siri or an alarm took the input away mid-performance.
    var onInterrupted: (() -> Void)?

    /// Quietest level treated as silence. Below this the mouth stays shut, so room
    /// noise does not leave the puppet permanently mumbling.
    private let floorDB: Double = -52
    private let ceilingDB: Double = -12

    private(set) var isRunning = false

    init() { observeSystemAudioEvents() }

    // MARK: Permission

    static var permission: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    /// Whether it is safe to touch the audio input at all.
    ///
    /// This guard is not defensive politeness — it prevents a hard crash. Reading
    /// `AVAudioEngine.inputNode` initialises AURemoteIO, and when there is no real
    /// input behind it that call can **abort the process** from inside AudioToolbox
    /// (SIGABRT via an RPC timeout). That is not a Swift error, so no `do`/`catch`
    /// around `start()` can contain it — the only fix is not to ask.
    ///
    /// The Simulator hits this reliably, which is why it is excluded outright rather
    /// than trusted to report itself unavailable. The cost of that exclusion is that
    /// the entire microphone path is device-only, and nothing here can be caught in the
    /// Simulator — which is exactly how the crash this file now guards against shipped.
    static var isInputUsable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVAudioSession.sharedInstance().isInputAvailable
        #endif
    }

    /// Ask for the microphone. Only ever called after the user has pressed Talk —
    /// never at launch, and never before they have seen what the app does.
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: Lifecycle

    func start() throws {
        guard !isRunning else { return }
        // Before the session is touched, not after: the old order upgraded the session
        // to `.playAndRecord` and then threw, leaving the whole app looking like a
        // recording app until it was killed.
        guard Self.isInputUsable else { throw MicError.noInputAvailable }

        do {
            try AudioSession.activateForRecording()
            try beginTap()
        } catch {
            // Any failure unwinds completely. A half-started engine on an upgraded
            // session is the state that aborts the process on the next attempt.
            unwind()
            throw error
        }
    }

    private func beginTap() throws {
        let input = engine.inputNode

        // Both formats are re-read on every start. The old code installed the tap once
        // and kept it: a route change between one Talk press and the next — headphones,
        // a call ending — moves the hardware format while the tap keeps the old one,
        // and `installTap` aborts the process on the mismatch rather than throwing.
        let tapFormat = input.outputFormat(forBus: 0)
        let hardwareFormat = input.inputFormat(forBus: 0)

        guard TapFormatCheck.isUsable(tapSampleRate: tapFormat.sampleRate,
                                      tapChannels: tapFormat.channelCount,
                                      hardwareSampleRate: hardwareFormat.sampleRate,
                                      hardwareChannels: hardwareFormat.channelCount) else {
            log.error("""
                Input format not usable: tap \(tapFormat.sampleRate, privacy: .public)Hz \
                ×\(tapFormat.channelCount, privacy: .public) vs hardware \
                \(hardwareFormat.sampleRate, privacy: .public)Hz \
                ×\(hardwareFormat.channelCount, privacy: .public)
                """)
            throw MicError.formatMismatch
        }

        removeTap()

        let box = self.box
        let floorDB = self.floorDB
        let ceilingDB = self.ceilingDB

        // --- audio thread below this line: no allocation, no locks, no await ---
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }

            var sum: Float = 0
            for i in 0..<count { sum += channel[i] * channel[i] }
            let rms = Double((sum / Float(count)).squareRoot())

            let db = rms > 0 ? 20 * log10(rms) : -160
            let normalised = ((db - floorDB) / (ceilingDB - floorDB)).clamped(to: 0...1)
            // Slight curve: quiet speech should still open the mouth a useful amount.
            box.store(pow(normalised, 0.75))
        }
        isTapped = true
        installedTapFormat = tapFormat

        engine.prepare()
        try engine.start()
        isRunning = true
        log.info("Microphone amplitude source started")
    }

    func stop() {
        unwind()
        log.info("Microphone amplitude source stopped")
    }

    /// Return to a clean, fully torn-down state and hand the session back.
    ///
    /// The engine is **stopped**, not paused. Pausing left the input unit initialised
    /// while the session dropped back to `.playback` — a category with no input at all
    /// — which is an invalid combination and the state the next Talk press started from.
    private func unwind() {
        isRunning = false
        box.store(0)
        removeTap()
        engine.stop()
        // Returning the session to playback is itself a reconfiguration, so it happens
        // last, once this engine no longer cares.
        AudioSession.returnToPlaybackIfNeeded()
    }

    private func removeTap() {
        guard isTapped else { return }
        engine.inputNode.removeTap(onBus: 0)
        isTapped = false
        installedTapFormat = nil
    }

    /// Most recent loudness, 0…1. Read once per frame from the main thread.
    var level: Double { isRunning ? box.load() : 0 }

    // MARK: Surviving the system

    /// The hardware is not ours. Phone calls, Siri, alarms, headphones being plugged in
    /// and this app's own session upgrade all reconfigure it, and an `AVAudioEngine`
    /// that is not told about it is an engine that aborts the process the next time it
    /// is used. None of this can be reproduced in the Simulator.
    private func observeSystemAudioEvents() {
        let centre = NotificationCenter.default

        observers.append(centre.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleConfigurationChange() }
            })

        observers.append(centre.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onNeedsRestart?() }
            })

        observers.append(centre.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw),
                      type == .began else { return }
                // A call or Siri takes the input away. There is no sensible way to resume
                // a held Talk button afterwards, so end the take cleanly rather than
                // leave a dead engine looking alive.
                MainActor.assumeIsolated { self?.onInterrupted?() }
            })
    }

    /// Not every configuration change deserves a rebuild.
    ///
    /// The single most common one is self-inflicted: `start()` upgrades the session to
    /// `.playAndRecord`, which reconfigures the hardware, which posts this notification
    /// on the very engine that just started. Treating that as "the world changed" tore
    /// the engine down and rebuilt it on *every* Talk press, costing a dropped syllable
    /// at the front of every take.
    ///
    /// So: ask whether the hardware format actually moved away from the one the live tap
    /// was installed with. If it did not, the graph is still valid and the engine only
    /// needs starting again — the system stops it on any configuration change regardless.
    private func handleConfigurationChange() {
        // Nothing is installed and nothing is running, so nothing can be invalid.
        guard isRunning else { return }

        guard let installed = installedTapFormat else {
            onNeedsRestart?()
            return
        }

        let hardware = engine.inputNode.inputFormat(forBus: 0)
        guard TapFormatCheck.isUsable(tapSampleRate: installed.sampleRate,
                                      tapChannels: installed.channelCount,
                                      hardwareSampleRate: hardware.sampleRate,
                                      hardwareChannels: hardware.channelCount) else {
            log.info("Hardware format moved under the tap — rebuilding")
            onNeedsRestart?()
            return
        }

        guard !engine.isRunning else { return }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            log.error("Engine would not restart in place: \(error.localizedDescription)")
            onNeedsRestart?()
        }
    }

    /// Rebuild from nothing. Everything in the old graph may be invalid.
    func restartAfterSystemChange() -> Bool {
        let wasRunning = isRunning
        removeTap()
        engine.stop()
        engine = AVAudioEngine()
        isRunning = false
        // A fresh engine needs fresh observers: the configuration-change notification is
        // posted by a specific engine object, and the old one is gone.
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        observeSystemAudioEvents()

        guard wasRunning else { return false }
        do {
            try start()
            return true
        } catch {
            log.error("Microphone did not survive a system audio change: \(error.localizedDescription)")
            return false
        }
    }

    enum MicError: Error {
        case noInputAvailable
        /// The input format disagreed with the hardware. Installing the tap anyway would
        /// have aborted the process rather than thrown.
        case formatMismatch
    }
}
