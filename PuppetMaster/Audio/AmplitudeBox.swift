import Synchronization

/// Lock-free hand-off of one `Double` from the audio thread to the main thread.
///
/// The realtime audio callback must not allocate, take a lock, or touch Swift
/// concurrency — doing any of those risks a glitch in the audio graph, which is
/// audible. A single relaxed atomic is all this needs: the reader only ever wants the
/// most recent value, and a missed update is invisible at 60 frames per second.
final class AmplitudeBox: Sendable {

    private let bits = Atomic<UInt64>(0)

    /// Called from the audio thread. Allocation-free and non-blocking.
    func store(_ value: Double) {
        bits.store(value.bitPattern, ordering: .relaxed)
    }

    /// Called from the main thread, once per frame.
    func load() -> Double {
        Double(bitPattern: bits.load(ordering: .relaxed))
    }
}
