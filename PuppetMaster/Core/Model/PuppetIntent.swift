import Foundation

/// Everything a control surface can ask the puppet to do.
///
/// Controls never touch the engine's state directly — they post intents. That single
/// indirection is what lets a control surface live on a *different screen, or a
/// different device*, from the stage: the engine cannot tell a local tap from a
/// remote one, so a second surface needs no new engine code at all.
public enum PuppetIntent: Sendable, Equatable {
    case setExpression(Expression)
    case perform(PuppetAction)
    case aim(x: Double, y: Double)   // normalised stage coordinates, -1…1
    case releaseAim
    case setMicEnabled(Bool)
    case setJawDrive(Double)         // 0…1, from the microphone or the fallback driver
}

/// Anything that accepts intents. Implemented by the engine locally, and — when a
/// second device is driving the stage — by a transport that forwards them over the
/// wire. The control views are written against this and nothing else.
@MainActor
public protocol IntentSink: AnyObject {
    func send(_ intent: PuppetIntent)
}
