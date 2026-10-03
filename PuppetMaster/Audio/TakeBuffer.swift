import Synchronization

/// Holds one microphone take in memory, so the puppet can repeat it.
///
/// Written from the realtime audio thread, so the same rules as `AmplitudeBox`: no
/// allocation, no locks, no Swift concurrency. The storage is allocated once, up front,
/// and the audio thread only copies into it and publishes how far it got.
///
/// **Privacy.** This only fills while a voice effect that repeats you is chosen. It is
/// never written to disk and never leaves the device; `drain()` hands the samples over
/// once and zeroes the storage, so nothing outlives the take that made it.
///
/// The threading contract is simple and is the caller's to keep: `begin` and `drain`
/// run on the main thread while no tap is delivering, and `append` runs on the audio
/// thread in between.
final class TakeBuffer: @unchecked Sendable {

    let capacity: Int
    private let storage: UnsafeMutablePointer<Float>
    private let written = Atomic<Int>(0)
    private let accepting = Atomic<Bool>(false)
    /// The rate the samples were captured at. Main thread only.
    private(set) var sampleRate: Double = 0
    /// The current take was given up on. Main thread only. Stays set until the take is
    /// drained or discarded, so a later rebuild in the same press cannot quietly start
    /// a new one — which would have the puppet repeat only the tail of what was said.
    private var isAbandoned = false

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage = .allocate(capacity: self.capacity)
        storage.initialize(repeating: 0, count: self.capacity)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    /// Start, or continue, a take at `rate`. Main thread, before the tap is installed.
    ///
    /// A take that is rebuilt mid-way at a different rate — headphones with their own
    /// clock — cannot be stitched together, so it is abandoned rather than replayed at
    /// the wrong speed.
    func begin(sampleRate rate: Double, keep: Bool) {
        guard keep, !isAbandoned else {
            accepting.store(false, ordering: .relaxed)
            clear()
            return
        }
        if written.load(ordering: .acquiring) > 0, rate != sampleRate {
            accepting.store(false, ordering: .relaxed)
            clear()
            sampleRate = 0
            isAbandoned = true
            return
        }
        sampleRate = rate
        accepting.store(true, ordering: .releasing)
    }

    /// Audio thread. Copies what fits; anything past the capacity is dropped.
    func append(_ samples: UnsafePointer<Float>, count: Int) {
        guard accepting.load(ordering: .acquiring) else { return }
        let start = written.load(ordering: .relaxed)
        let n = min(count, capacity - start)
        guard n > 0 else { return }
        (storage + start).update(from: samples, count: n)
        written.store(start + n, ordering: .releasing)
    }

    /// Main thread, after the engine has stopped. Returns the take once, then forgets it.
    ///
    /// Relies on no tap callback still running after `removeTap` and `engine.stop()`.
    /// AVFoundation does not promise that in writing. A straggler is harmless to memory
    /// — `append` never writes past `capacity` — but could leave a few stale samples to
    /// be zeroed by the next `begin`/`discard`. Worth knowing; not worth a lock on the
    /// audio thread.
    func drain() -> (samples: [Float], sampleRate: Double) {
        accepting.store(false, ordering: .relaxed)
        let n = min(written.load(ordering: .acquiring), capacity)
        let samples = Array(UnsafeBufferPointer(start: storage, count: n))
        let rate = sampleRate
        clear()
        sampleRate = 0
        isAbandoned = false
        return (samples, rate)
    }

    /// Forget the take without reading it.
    func discard() {
        accepting.store(false, ordering: .relaxed)
        clear()
        sampleRate = 0
        isAbandoned = false
    }

    private func clear() {
        let n = min(written.load(ordering: .acquiring), capacity)
        if n > 0 { storage.update(repeating: 0, count: n) }
        written.store(0, ordering: .releasing)
    }
}
