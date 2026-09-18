import AVFoundation
import OSLog

/// Turns microphone loudness into a 0…1 signal for the puppet's jaw.
///
/// Deliberately **not** speech recognition. Loudness is enough to sell talking, works
/// in every language, needs no model and no network, and keeps the privacy story
/// something you can say in one sentence: we measure how loud it is, we do not listen
/// to what you say. Nothing is written to disk and nothing leaves the device.
@MainActor
final class MicAmplitudeSource {

    private let engine = AVAudioEngine()
    private let box = AmplitudeBox()
    private var isTapped = false
    private let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "mic")

    /// Quietest level treated as silence. Below this the mouth stays shut, so room
    /// noise does not leave the puppet permanently mumbling.
    private let floorDB: Double = -52
    private let ceilingDB: Double = -12

    private(set) var isRunning = false

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
    /// than trusted to report itself unavailable. The real microphone path has to be
    /// exercised on device.
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

        try AudioSession.activateForRecording()

        // Checked again here, not just at the call site: `inputNode` below is the line
        // that can abort the process if there is nothing behind it.
        guard Self.isInputUsable else { throw MicError.noInputAvailable }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw MicError.noInputAvailable
        }

        if !isTapped {
            let box = self.box
            let floorDB = self.floorDB
            let ceilingDB = self.ceilingDB

            // --- audio thread below this line: no allocation, no locks, no await ---
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
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
        }

        engine.prepare()
        try engine.start()
        isRunning = true
        log.info("Microphone amplitude source started")
    }

    func stop() {
        guard isRunning else { return }
        engine.pause()
        box.store(0)
        isRunning = false
        // Return to playback rather than deactivating: deactivating here used to cut off
        // any sound effect still ringing when the Talk button came up.
        AudioSession.activateForPlayback()
        log.info("Microphone amplitude source stopped")
    }

    /// Tear the tap down completely. Only on teardown — restarting is cheaper than
    /// reinstalling a tap.
    func teardown() {
        stop()
        if isTapped {
            engine.inputNode.removeTap(onBus: 0)
            isTapped = false
        }
        engine.stop()
    }

    /// Most recent loudness, 0…1. Read once per frame from the main thread.
    var level: Double { isRunning ? box.load() : 0 }

    enum MicError: Error { case noInputAvailable }
}
