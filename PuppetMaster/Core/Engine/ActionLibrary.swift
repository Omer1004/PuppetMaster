import Foundation

/// The built-in performance repertoire.
///
/// These are hand-tuned curves, not procedural motion — timing is the whole craft of
/// making a puppet funny, and it does not come out of a formula. They live in code
/// for the prototype and are shaped so they can be lifted into per-character JSON
/// without changing the runtime (see ARCHITECTURE §3.4).
public enum ActionLibrary {

    public static func track(for action: PuppetAction) -> ActionTrack {
        switch action {
        case .wave:   wave
        case .laugh:  laugh
        case .jump:   jump
        case .spin:   spin
        case .nod:    nod
        case .shake:  shake
        case .topple: topple
        }
    }

    // MARK: Wave — the universal hello. Body counter-leans so it reads as one motion.

    static let wave = ActionTrack(
        id: .wave,
        duration: 1.35,
        channels: [
            .armRight: [
                Keyframe(0.00, 0.00, .easeIn),
                Keyframe(0.20, 2.05, .backOut),
                Keyframe(0.42, 2.45, .easeInOut),
                Keyframe(0.62, 1.95, .easeInOut),
                Keyframe(0.82, 2.45, .easeInOut),
                Keyframe(1.02, 2.00, .easeInOut),
                Keyframe(1.35, 0.00, .easeInOut),
            ],
            .bodyLean: [
                Keyframe(0.00, 0.00), Keyframe(0.22, -0.07),
                Keyframe(1.05, -0.07), Keyframe(1.35, 0.00),
            ],
            .headTilt: [
                Keyframe(0.00, 0.00), Keyframe(0.22, 0.11),
                Keyframe(1.05, 0.11), Keyframe(1.35, 0.00),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.00, .easeOut), Keyframe(0.25, 0.55),
                Keyframe(1.05, 0.55), Keyframe(1.35, 0.00),
            ],
        ]
    )

    // MARK: Laugh — jaw is ADDITIVE so it stacks on top of live speech instead of
    // fighting the microphone for control of the mouth.

    static let laugh = ActionTrack(
        id: .laugh,
        duration: 1.6,
        additive: [.jawOpen],
        cues: [EffectCue(0.15, .sparkle)],
        channels: [
            .jawOpen: [
                Keyframe(0.00, 0.00, .easeOut), Keyframe(0.12, 0.42, .easeOut),
                Keyframe(0.26, 0.08), Keyframe(0.40, 0.44), Keyframe(0.54, 0.08),
                Keyframe(0.68, 0.40), Keyframe(0.82, 0.08), Keyframe(0.96, 0.34),
                Keyframe(1.12, 0.06), Keyframe(1.60, 0.00, .easeInOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0), Keyframe(0.12, 12, .easeOut), Keyframe(0.26, 0, .easeIn),
                Keyframe(0.40, 11), Keyframe(0.54, 0), Keyframe(0.68, 9),
                Keyframe(0.82, 0), Keyframe(0.96, 6), Keyframe(1.12, 0),
                Keyframe(1.60, 0),
            ],
            .headNod: [
                Keyframe(0.00, 0.00, .easeOut), Keyframe(0.20, 0.62),
                Keyframe(1.15, 0.55), Keyframe(1.60, 0.00, .easeInOut),
            ],
            .squash: [
                Keyframe(0.00, 1.00), Keyframe(0.12, 1.07), Keyframe(0.26, 0.96),
                Keyframe(0.40, 1.06), Keyframe(0.54, 0.97), Keyframe(1.60, 1.00),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.00, .easeOut), Keyframe(0.15, 1.00),
                Keyframe(1.20, 0.90), Keyframe(1.60, 0.00, .easeInOut),
            ],
            .blink: [
                Keyframe(0.00, 0.00), Keyframe(0.18, 0.75), Keyframe(1.15, 0.65),
                Keyframe(1.45, 0.00),
            ],
        ]
    )

    // MARK: Jump — anticipation, flight, landing. The shadow shrinking is what sells
    // the height; without it the puppet just slides up the screen.

    static let jump = ActionTrack(
        id: .jump,
        duration: 0.95,
        cues: [EffectCue(0.62, .dustPuff)],
        channels: [
            .squash: [
                Keyframe(0.00, 1.00, .easeIn), Keyframe(0.13, 0.76, .easeOut),
                Keyframe(0.24, 1.20, .backOut), Keyframe(0.50, 1.02),
                Keyframe(0.62, 0.80, .easeIn), Keyframe(0.76, 1.08, .backOut),
                Keyframe(0.95, 1.00, .easeInOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeIn), Keyframe(0.13, -10, .easeOut),
                Keyframe(0.38, 96, .easeOut), Keyframe(0.62, 0, .easeIn),
                Keyframe(0.74, -6), Keyframe(0.95, 0, .easeOut),
            ],
            .shadowScale: [
                Keyframe(0.00, 1.00), Keyframe(0.38, 0.45, .easeOut),
                Keyframe(0.62, 1.00, .easeIn), Keyframe(0.95, 1.00),
            ],
            .armLeft: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.30, -1.5),
                Keyframe(0.62, 0.3), Keyframe(0.95, 0.0),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.30, 1.5),
                Keyframe(0.62, -0.3), Keyframe(0.95, 0.0),
            ],
            .browLift: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.30, 0.9),
                Keyframe(0.70, 0.2), Keyframe(0.95, 0.0),
            ],
        ]
    )

    // MARK: Spin — two full turns, then a dizzy wobble that decays.

    static let spin = ActionTrack(
        id: .spin,
        duration: 1.9,
        channels: [
            .bodyRotation: [
                Keyframe(0.00, 0.0, .easeIn),
                Keyframe(0.14, 0.38, .easeOut),                 // wind up the other way
                Keyframe(0.95, -4 * .pi, .easeOut),             // two clean turns
                Keyframe(1.90, -4 * .pi),
            ],
            .headTilt: [
                Keyframe(0.95, 0.00), Keyframe(1.15, 0.30, .easeInOut),
                Keyframe(1.38, -0.26), Keyframe(1.58, 0.16),
                Keyframe(1.90, 0.00, .easeInOut),
            ],
            .gazeX: [
                Keyframe(0.95, 0.0), Keyframe(1.15, 0.8), Keyframe(1.38, -0.7),
                Keyframe(1.58, 0.4), Keyframe(1.90, 0.0),
            ],
            .squash: [
                Keyframe(0.00, 1.00), Keyframe(0.20, 1.10), Keyframe(0.95, 1.00),
                Keyframe(1.15, 0.95), Keyframe(1.90, 1.00),
            ],
        ]
    )

    // MARK: Nod / Shake — small, but they are what let the puppet hold a conversation.

    static let nod = ActionTrack(
        id: .nod,
        duration: 0.85,
        channels: [
            .headNod: [
                Keyframe(0.00, 0.0, .easeIn), Keyframe(0.16, -0.85, .easeOut),
                Keyframe(0.32, 0.30), Keyframe(0.48, -0.72), Keyframe(0.64, 0.22),
                Keyframe(0.85, 0.0, .easeInOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0), Keyframe(0.16, -6), Keyframe(0.32, 2),
                Keyframe(0.48, -5), Keyframe(0.85, 0),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.20, 0.5),
                Keyframe(0.62, 0.5), Keyframe(0.85, 0.0),
            ],
        ]
    )

    static let shake = ActionTrack(
        id: .shake,
        duration: 0.85,
        channels: [
            .headTurn: [
                Keyframe(0.00, 0.0, .easeIn), Keyframe(0.14, -0.85, .easeOut),
                Keyframe(0.30, 0.82), Keyframe(0.46, -0.70), Keyframe(0.62, 0.55),
                Keyframe(0.85, 0.0, .easeInOut),
            ],
            .headTilt: [
                Keyframe(0.00, 0.0), Keyframe(0.14, 0.10), Keyframe(0.30, -0.10),
                Keyframe(0.46, 0.08), Keyframe(0.85, 0.0),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.18, -0.35),
                Keyframe(0.62, -0.30), Keyframe(0.85, 0.0),
            ],
        ]
    )

    // MARK: Topple — falls over, lies there a beat, springs back. The pause is the joke.

    static let topple = ActionTrack(
        id: .topple,
        duration: 2.4,
        interruptible: false,
        cues: [EffectCue(0.60, .dustPuff)],
        channels: [
            .bodyRotation: [
                Keyframe(0.00, 0.00, .easeOut), Keyframe(0.18, -0.14, .easeIn),
                Keyframe(0.60, 1.48, .bounceOut), Keyframe(1.55, 1.44),
                Keyframe(2.10, 0.00, .elasticOut), Keyframe(2.40, 0.00),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeIn), Keyframe(0.18, 6),
                Keyframe(0.60, -34, .bounceOut), Keyframe(1.55, -34),
                Keyframe(2.10, 0, .easeOut), Keyframe(2.40, 0),
            ],
            .bodyOffsetX: [
                Keyframe(0.00, 0), Keyframe(0.60, 30, .easeOut),
                Keyframe(1.55, 30), Keyframe(2.10, 0, .easeInOut),
            ],
            .blink: [
                Keyframe(0.00, 0.0), Keyframe(0.55, 0.95, .easeOut),
                Keyframe(1.45, 0.95), Keyframe(1.70, 0.0, .easeOut),
            ],
            .browLift: [
                Keyframe(0.00, 0.0), Keyframe(0.20, 1.0, .easeOut),
                Keyframe(1.50, 0.3), Keyframe(2.40, 0.0),
            ],
            .armLeft: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.35, -1.9),
                Keyframe(1.55, -1.2), Keyframe(2.10, 0.0),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.35, 1.9),
                Keyframe(1.55, 1.2), Keyframe(2.10, 0.0),
            ],
            .squash: [
                Keyframe(0.00, 1.00), Keyframe(0.60, 1.08, .bounceOut),
                Keyframe(1.55, 1.04), Keyframe(2.10, 1.00),
            ],
        ]
    )
}
