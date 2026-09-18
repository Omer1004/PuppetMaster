import UIKit
import SpriteKit

/// Tiny generated textures for particle effects.
///
/// Generated rather than bundled so the prototype carries no binary art dependency at
/// all. Real art replaces these without touching the emitters.
@MainActor
enum ParticleTextures {

    private static var cache: [String: SKTexture] = [:]

    /// A soft round blob that fades out at the edge.
    static func soft(radius: CGFloat, color: UIColor) -> SKTexture {
        cached("soft-\(radius)-\(color.hashValue)") {
            let size = CGSize(width: radius * 2, height: radius * 2)
            return UIGraphicsImageRenderer(size: size).image { context in
                let colors = [color.withAlphaComponent(0.95).cgColor,
                              color.withAlphaComponent(0).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                colors: colors, locations: [0, 1]) else { return }
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: radius, y: radius), startRadius: 0,
                    endCenter: CGPoint(x: radius, y: radius), endRadius: radius,
                    options: [])
            }
        }
    }

    /// A small rounded rectangle, for confetti.
    static func chip(size: CGFloat, color: UIColor) -> SKTexture {
        cached("chip-\(size)-\(color.hashValue)") {
            let dimension = CGSize(width: size, height: size * 1.6)
            return UIGraphicsImageRenderer(size: dimension).image { _ in
                color.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: dimension),
                             cornerRadius: size * 0.2).fill()
            }
        }
    }

    /// An SF Symbol rendered into a particle texture — music notes, stars, hearts.
    /// Free, crisp at any size, and no asset to commission.
    static func symbol(_ name: String, size: CGFloat, color: UIColor) -> SKTexture {
        cached("symbol-\(name)-\(size)-\(color.hashValue)") {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
            guard let image = UIImage(systemName: name, withConfiguration: config)?
                .withTintColor(color, renderingMode: .alwaysOriginal) else {
                // Fall back to a plain dot rather than shipping an invisible effect.
                return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
                    color.setFill()
                    UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
                }
            }
            return UIGraphicsImageRenderer(size: image.size).image { _ in
                image.draw(at: .zero)
            }
        }
    }

    /// Vertical gradient used for the stage backdrop.
    static func gradient(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        cached("grad-\(Int(size.height))-\(top.hashValue)-\(bottom.hashValue)") {
            UIGraphicsImageRenderer(size: size).image { context in
                let colors = [top.cgColor, bottom.cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                colors: colors, locations: [0, 1]) else { return }
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: [])
            }
        }
    }

    private static func cached(_ key: String, _ make: () -> UIImage) -> SKTexture {
        if let hit = cache[key] { return hit }
        let texture = SKTexture(image: make())
        cache[key] = texture
        return texture
    }
}
