import UIKit
import SpriteKit

/// Tiny generated textures for particle effects.
///
/// Generated rather than bundled so the prototype has no binary art dependency at all.
/// Real art replaces these without touching the emitters.
@MainActor
enum ParticleTextures {

    private static var cache: [String: SKTexture] = [:]

    /// A soft round blob that fades out at the edge.
    static func soft(radius: CGFloat, color: UIColor) -> SKTexture {
        let key = "soft-\(radius)-\(color.hashValue)"
        if let cached = cache[key] { return cached }

        let size = CGSize(width: radius * 2, height: radius * 2)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [color.withAlphaComponent(0.95).cgColor,
                          color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0, 1]) else { return }
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: radius, y: radius), startRadius: 0,
                endCenter: CGPoint(x: radius, y: radius), endRadius: radius,
                options: [])
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    /// A small solid square, for confetti.
    static func chip(size: CGFloat, color: UIColor) -> SKTexture {
        let key = "chip-\(size)-\(color.hashValue)"
        if let cached = cache[key] { return cached }

        let dimension = CGSize(width: size, height: size * 1.6)
        let image = UIGraphicsImageRenderer(size: dimension).image { context in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: dimension),
                         cornerRadius: size * 0.2).fill()
            _ = context
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    /// Vertical gradient used for the stage backdrop.
    static func gradient(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: [])
        }
        return SKTexture(image: image)
    }
}
