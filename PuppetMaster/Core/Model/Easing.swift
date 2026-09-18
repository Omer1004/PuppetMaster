import Foundation

/// Interpolation curves for keyframed motion.
///
/// `backOut` and `elasticOut` are the ones that matter for a puppet: overshoot is
/// what separates "a thing that moved" from "a thing that is alive".
public enum Easing: String, Sendable, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case backOut
    case elasticOut
    case bounceOut

    public func apply(_ t: Double) -> Double {
        let t = t.clamped(to: 0...1)
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case .backOut:
            let c1 = 1.70158, c3 = c1 + 1
            return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
        case .elasticOut:
            guard t > 0, t < 1 else { return t }
            let c4 = (2 * Double.pi) / 3
            return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
        case .bounceOut:
            let n1 = 7.5625, d1 = 2.75
            var t = t
            if t < 1 / d1 { return n1 * t * t }
            if t < 2 / d1 { t -= 1.5 / d1; return n1 * t * t + 0.75 }
            if t < 2.5 / d1 { t -= 2.25 / d1; return n1 * t * t + 0.9375 }
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }
}

/// A critically-damped-ish smoothing filter, frame-rate independent.
///
/// Used anywhere a raw signal would otherwise look mechanical — most importantly the
/// microphone amplitude feeding the jaw.
public struct Smoother: Sendable {
    public var value: Double
    public var attack: Double   // seconds to rise
    public var release: Double  // seconds to fall

    public init(value: Double = 0, attack: Double = 0.02, release: Double = 0.08) {
        self.value = value
        self.attack = attack
        self.release = release
    }

    public mutating func update(target: Double, delta: Double) {
        let tau = target > value ? attack : release
        guard tau > 0 else { value = target; return }
        let alpha = 1 - exp(-delta / tau)
        value += (target - value) * alpha
    }
}
