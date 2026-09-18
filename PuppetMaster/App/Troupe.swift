import Foundation
import Observation

/// Who is on stage, and which of them your thumbs are driving.
///
/// One ``PuppetEngine`` per puppet. That is deliberate and not an optimisation to undo
/// later: an engine *is* one performance — its own pose, its own idle rhythm, its own
/// boredom clock — so two puppets that share an engine are one puppet drawn twice.
/// Adding the second puppet therefore added no animation code at all.
///
/// Controls talk to ``focused``. Staging goes to everyone, because two puppets sharing a
/// stage must share a sky.
@MainActor
@Observable
final class Troupe {

    /// Two is the ceiling on purpose. A third puppet on a phone is too small to read,
    /// and the controls stop being obvious within seconds — which is the whole product.
    static let maxSize = 2

    private(set) var engines: [PuppetEngine]
    private(set) var focusIndex = 0

    /// Wired by the composition root so every puppet's sounds reach the one sound bank.
    @ObservationIgnored var onSound: ((SoundID, Double) -> Void)? {
        didSet { for engine in engines { attachSound(to: engine) } }
    }

    init() {
        engines = [PuppetEngine()]
    }

    /// The engine that control surfaces post intents to.
    var focused: PuppetEngine { engines[min(focusIndex, engines.count - 1)] }

    var isDuet: Bool { engines.count > 1 }

    // MARK: Cast size

    func setDuet(_ duet: Bool) {
        let wanted = duet ? Self.maxSize : 1
        guard wanted != engines.count else { return }

        if wanted > engines.count {
            while engines.count < wanted {
                let engine = PuppetEngine()
                // Give the newcomer a different character where there is one to spare, so
                // turning on a duet shows two puppets rather than one puppet twice.
                engine.send(.setCharacter(id: Self.partnerCharacterID(for: engines)))
                engine.send(.setBackdrop(id: engines[0].backdrop.id))
                // Two puppets that start their boredom clocks together yawn in unison,
                // which reads as one mechanism rather than two characters.
                engine.offsetIdleClock(by: Double(engines.count) * 4.5)
                attachSound(to: engine)
                engines.append(engine)
            }
        } else {
            engines.removeLast(engines.count - wanted)
        }
        focusIndex = min(focusIndex, engines.count - 1)
    }

    /// Pick a cast member the existing puppets are not already using.
    private static func partnerCharacterID(for engines: [PuppetEngine]) -> String {
        let taken = Set(engines.map(\.character.id))
        return CharacterLibrary.all.first { !taken.contains($0.id) }?.id
            ?? CharacterLibrary.default.id
    }

    // MARK: Focus

    func focus(_ index: Int) {
        guard engines.indices.contains(index), index != focusIndex else { return }
        // Release anything the old puppet was holding, or it freezes mid-gesture with
        // its eyes locked wherever your thumb last was.
        engines[focusIndex].send(.releaseAim)
        engines[focusIndex].send(.setJawDrive(0))
        focusIndex = index
    }

    /// Hand control to the other puppet. The whole interaction for a duet on one phone.
    func toggleFocus() {
        guard isDuet else { return }
        focus((focusIndex + 1) % engines.count)
    }

    // MARK: Broadcast

    /// One frame, for every puppet.
    func tick(delta: Double) {
        for engine in engines { engine.tick(delta: delta) }
    }

    /// Send to the puppet being driven.
    func send(_ intent: PuppetIntent) { focused.send(intent) }

    /// Send to a specific puppet — used when a touch lands on the stage and names one.
    func send(_ intent: PuppetIntent, to index: Int) {
        guard engines.indices.contains(index) else { return }
        engines[index].send(intent)
    }

    /// Staging belongs to the stage, not to a puppet.
    func setBackdrop(_ backdrop: Backdrop) {
        for engine in engines { engine.send(.setBackdrop(id: backdrop.id)) }
    }

    func setReduceMotion(_ reduced: Bool) {
        for engine in engines { engine.setReduceMotion(reduced) }
    }

    private func attachSound(to engine: PuppetEngine) {
        engine.onSound = { [weak self] id, pitch in self?.onSound?(id, pitch) }
    }
}
