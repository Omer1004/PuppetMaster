import Foundation

/// A held facial/postural state. Exactly one is active at a time, and it never
/// prevents an action or live speech from also affecting the pose.
public enum Expression: String, CaseIterable, Identifiable, Sendable, Codable {
    case neutral, happy, surprised, silly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .neutral:   "Neutral"
        case .happy:     "Happy"
        case .surprised: "Whoa"
        case .silly:     "Silly"
        }
    }

    /// Glyph used on the control pad. SF Symbols, so it scales and is VoiceOver-legible.
    public var symbol: String {
        switch self {
        case .neutral:   "face.dashed"
        case .happy:     "face.smiling"
        case .surprised: "exclamationmark.bubble"
        case .silly:     "hand.raised.fingers.spread"
        }
    }

    /// Channel targets this expression pulls toward. Absent channels are left alone,
    /// so an expression never stomps on breathing, talking, or an in-flight action.
    public var targets: [PoseChannel: Double] {
        switch self {
        case .neutral:
            return [.mouthSmile: 0.1, .browLift: 0, .browAngle: 0, .tongueOut: 0]
        case .happy:
            return [.mouthSmile: 1.0, .browLift: 0.45, .browAngle: -0.2,
                    .tongueOut: 0, .headTilt: 0.06]
        case .surprised:
            return [.mouthSmile: -0.15, .browLift: 1.0, .browAngle: 0,
                    .jawOpen: 0.45, .tongueOut: 0, .bodyOffsetY: 6, .squash: 1.08]
        case .silly:
            return [.mouthSmile: 0.7, .browLift: 0.2, .browAngle: 0.35,
                    .tongueOut: 1.0, .headTilt: -0.18, .gazeX: 0.3,
                    .jawOpen: 0.20]
        }
    }
}
