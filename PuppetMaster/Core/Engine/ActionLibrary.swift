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
        case .dance:   dance
        case .cheer:   cheer
        case .sneeze:  sneeze
        case .peek:    peek
        case .stretch: stretch
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

    // MARK: Dance — weight shifting side to side with the arms trading places.
    // The body leans *against* the direction it slides, which is what stops it looking
    // like a sprite being translated.

    static let dance = ActionTrack(
        id: .dance,
        duration: 3.0,
        cues: [EffectCue(0.10, .musicNotes)],
        channels: [
            .bodyOffsetX: [
                Keyframe(0.00, 0, .easeInOut), Keyframe(0.40, -26), Keyframe(1.00, 26),
                Keyframe(1.60, -26), Keyframe(2.20, 26), Keyframe(2.70, -12),
                Keyframe(3.00, 0),
            ],
            .bodyLean: [
                Keyframe(0.00, 0, .easeInOut), Keyframe(0.40, 0.17), Keyframe(1.00, -0.17),
                Keyframe(1.60, 0.17), Keyframe(2.20, -0.17), Keyframe(2.70, 0.08),
                Keyframe(3.00, 0),
            ],
            .armLeft: [
                Keyframe(0.00, 0.0, .backOut), Keyframe(0.40, -2.3), Keyframe(1.00, -0.5),
                Keyframe(1.60, -2.3), Keyframe(2.20, -0.5), Keyframe(2.70, -1.8),
                Keyframe(3.00, 0.0, .easeInOut),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .backOut), Keyframe(0.40, 0.5), Keyframe(1.00, 2.3),
                Keyframe(1.60, 0.5), Keyframe(2.20, 2.3), Keyframe(2.70, 0.6),
                Keyframe(3.00, 0.0, .easeInOut),
            ],
            .headTilt: [
                Keyframe(0.00, 0, .easeInOut), Keyframe(0.40, -0.22), Keyframe(1.00, 0.22),
                Keyframe(1.60, -0.22), Keyframe(2.20, 0.22), Keyframe(3.00, 0),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0), Keyframe(0.20, 10), Keyframe(0.40, 0), Keyframe(0.60, 10),
                Keyframe(0.80, 0), Keyframe(1.00, 10), Keyframe(1.20, 0), Keyframe(1.40, 10),
                Keyframe(1.60, 0), Keyframe(1.80, 10), Keyframe(2.00, 0), Keyframe(2.20, 10),
                Keyframe(2.40, 0), Keyframe(3.00, 0),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.25, 0.9),
                Keyframe(2.60, 0.9), Keyframe(3.00, 0.0),
            ],
        ]
    )

    // MARK: Cheer — arms up, two bounces, confetti. The second bounce is smaller,
    // because a celebration that repeats at full size reads as a loop.

    static let cheer = ActionTrack(
        id: .cheer,
        duration: 2.1,
        additive: [.jawOpen],
        cues: [EffectCue(0.16, .confetti), EffectCue(0.20, .sparkle)],
        channels: [
            .armLeft: [
                Keyframe(0.00, 0.0, .backOut), Keyframe(0.18, -2.5),
                Keyframe(1.60, -2.3), Keyframe(2.10, 0.0, .easeInOut),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .backOut), Keyframe(0.18, 2.5),
                Keyframe(1.60, 2.3), Keyframe(2.10, 0.0, .easeInOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeIn), Keyframe(0.10, -8, .easeOut),
                Keyframe(0.42, 78, .easeOut), Keyframe(0.72, 0, .easeIn),
                Keyframe(0.86, -6), Keyframe(1.14, 46, .easeOut),
                Keyframe(1.40, 0, .easeIn), Keyframe(2.10, 0),
            ],
            .squash: [
                Keyframe(0.00, 1.00), Keyframe(0.10, 0.82, .easeOut),
                Keyframe(0.30, 1.16, .backOut), Keyframe(0.72, 0.88, .easeIn),
                Keyframe(0.95, 1.08), Keyframe(1.40, 0.92), Keyframe(2.10, 1.00),
            ],
            .shadowScale: [
                Keyframe(0.00, 1.00), Keyframe(0.42, 0.50, .easeOut),
                Keyframe(0.72, 1.00, .easeIn), Keyframe(1.14, 0.68),
                Keyframe(1.40, 1.00), Keyframe(2.10, 1.00),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.15, 1.0),
                Keyframe(1.70, 1.0), Keyframe(2.10, 0.0),
            ],
            .browLift: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.15, 1.0),
                Keyframe(1.70, 0.7), Keyframe(2.10, 0.0),
            ],
            .jawOpen: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.16, 0.55),
                Keyframe(1.50, 0.35), Keyframe(2.10, 0.0),
            ],
        ]
    )

    // MARK: Sneeze — a long wind-up and a very short snap. All the comedy is in the
    // ratio between the two; stretching the recovery would kill it.

    static let sneeze = ActionTrack(
        id: .sneeze,
        duration: 1.7,
        additive: [.jawOpen],
        cues: [EffectCue(0.62, .dustPuff)],
        channels: [
            .headNod: [
                Keyframe(0.00, 0.0, .easeInOut), Keyframe(0.52, 0.95, .easeInOut),
                Keyframe(0.62, -1.00, .easeIn), Keyframe(0.90, 0.10, .backOut),
                Keyframe(1.70, 0.0, .easeInOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeInOut), Keyframe(0.52, 10),
                Keyframe(0.62, -14, .easeIn), Keyframe(0.95, 2), Keyframe(1.70, 0),
            ],
            .squash: [
                Keyframe(0.00, 1.00), Keyframe(0.52, 1.12, .easeInOut),
                Keyframe(0.62, 0.84, .easeIn), Keyframe(0.86, 1.05, .backOut),
                Keyframe(1.70, 1.00),
            ],
            .browLift: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.48, 1.0),
                Keyframe(0.62, -0.6), Keyframe(1.10, 0.1), Keyframe(1.70, 0.0),
            ],
            .blink: [
                Keyframe(0.00, 0.0), Keyframe(0.46, 0.85, .easeOut),
                Keyframe(0.62, 1.00), Keyframe(0.88, 0.0, .easeOut),
            ],
            .jawOpen: [
                Keyframe(0.00, 0.00, .easeInOut), Keyframe(0.50, 0.25),
                Keyframe(0.60, 0.95, .easeOut), Keyframe(0.80, 0.10),
                Keyframe(1.70, 0.00),
            ],
            .armLeft: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.55, -1.5),
                Keyframe(0.70, -0.4), Keyframe(1.70, 0.0),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.55, 1.5),
                Keyframe(0.70, 0.4), Keyframe(1.70, 0.0),
            ],
        ]
    )

    // MARK: Peek — hides behind its arms, waits a beat too long, then pops out.
    // The pause is the whole joke, so it is generous.

    static let peek = ActionTrack(
        id: .peek,
        duration: 2.6,
        additive: [.jawOpen],
        channels: [
            .armLeft: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.30, -2.75),
                Keyframe(1.55, -2.75), Keyframe(1.80, -0.5, .easeOut),
                Keyframe(2.60, 0.0, .easeInOut),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .easeOut), Keyframe(0.30, 2.75),
                Keyframe(1.55, 2.75), Keyframe(1.80, 0.5, .easeOut),
                Keyframe(2.60, 0.0, .easeInOut),
            ],
            .squash: [
                Keyframe(0.00, 1.00, .easeIn), Keyframe(0.34, 0.68, .easeOut),
                Keyframe(1.55, 0.70), Keyframe(1.80, 1.14, .backOut),
                Keyframe(2.10, 1.00, .easeInOut), Keyframe(2.60, 1.00),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeIn), Keyframe(0.34, -26, .easeOut),
                Keyframe(1.55, -26), Keyframe(1.80, 12, .backOut), Keyframe(2.60, 0),
            ],
            .blink: [
                Keyframe(0.00, 0.0), Keyframe(0.34, 0.75, .easeOut),
                Keyframe(1.50, 0.75), Keyframe(1.76, 0.0, .easeOut),
            ],
            .browLift: [
                Keyframe(0.00, 0.0), Keyframe(1.76, 0.0), Keyframe(1.90, 1.0, .backOut),
                Keyframe(2.35, 0.4), Keyframe(2.60, 0.0),
            ],
            .mouthSmile: [
                Keyframe(0.00, 0.0), Keyframe(1.76, 0.0), Keyframe(1.92, 1.0, .easeOut),
                Keyframe(2.35, 0.8), Keyframe(2.60, 0.0),
            ],
            .jawOpen: [
                Keyframe(0.00, 0.0), Keyframe(1.78, 0.0), Keyframe(1.92, 0.45, .easeOut),
                Keyframe(2.25, 0.0),
            ],
        ]
    )

    // MARK: Yawn — slow open, slow close, then a small shiver. Contagious if the
    // timing is right, which is the point.

    static let stretch = ActionTrack(
        id: .stretch,
        duration: 3.0,
        additive: [.jawOpen],
        channels: [
            .jawOpen: [
                Keyframe(0.00, 0.00, .easeInOut), Keyframe(0.35, 0.20),
                Keyframe(0.95, 0.92, .easeInOut), Keyframe(1.55, 0.88),
                Keyframe(2.10, 0.06, .easeInOut), Keyframe(3.00, 0.00),
            ],
            .armLeft: [
                Keyframe(0.00, 0.0, .easeInOut), Keyframe(0.90, -2.5),
                Keyframe(1.60, -2.4), Keyframe(2.20, 0.2, .easeInOut),
                Keyframe(3.00, 0.0),
            ],
            .armRight: [
                Keyframe(0.00, 0.0, .easeInOut), Keyframe(0.90, 2.5),
                Keyframe(1.60, 2.4), Keyframe(2.20, -0.2, .easeInOut),
                Keyframe(3.00, 0.0),
            ],
            .squash: [
                Keyframe(0.00, 1.00, .easeInOut), Keyframe(0.95, 1.15),
                Keyframe(1.60, 1.12), Keyframe(2.20, 0.94, .easeInOut),
                Keyframe(2.45, 1.02), Keyframe(3.00, 1.00),
            ],
            .headNod: [
                Keyframe(0.00, 0.0, .easeInOut), Keyframe(0.95, 0.70),
                Keyframe(1.60, 0.62), Keyframe(2.20, -0.18), Keyframe(3.00, 0.0),
            ],
            .blink: [
                Keyframe(0.00, 0.0, .easeInOut), Keyframe(0.70, 0.95),
                Keyframe(1.85, 0.95), Keyframe(2.20, 0.0, .easeOut),
            ],
            .bodyOffsetY: [
                Keyframe(0.00, 0, .easeInOut), Keyframe(0.95, 9),
                Keyframe(1.60, 8), Keyframe(2.20, -3), Keyframe(3.00, 0),
            ],
            // The shiver at the end: small, fast, and it is what makes it a yawn rather
            // than a mouth opening.
            .headTilt: [
                Keyframe(2.20, 0.00), Keyframe(2.32, 0.14), Keyframe(2.44, -0.12),
                Keyframe(2.56, 0.07), Keyframe(2.70, 0.00),
            ],
        ]
    )
}
