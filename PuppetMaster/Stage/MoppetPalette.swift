import UIKit

/// Moppet's colours, in one place so the whole character can be re-tinted at once.
///
/// Placeholder art: the rig below is the real thing — a cut-out hierarchy with proper
/// pivots — but the shapes are drawn in code rather than commissioned. Swapping in a
/// real illustrator's atlas means replacing the shape nodes with sprites and leaving
/// every pivot, channel binding and action track exactly as it is.
enum MoppetPalette {
    static let fur        = UIColor(red: 0.13, green: 0.52, blue: 0.53, alpha: 1)
    static let furShade   = UIColor(red: 0.09, green: 0.40, blue: 0.43, alpha: 1)
    static let belly      = UIColor(red: 0.55, green: 0.85, blue: 0.80, alpha: 1)
    static let hair       = UIColor(red: 0.98, green: 0.54, blue: 0.24, alpha: 1)
    static let eyeWhite   = UIColor(red: 1.00, green: 0.97, blue: 0.91, alpha: 1)
    static let pupil      = UIColor(red: 0.16, green: 0.13, blue: 0.11, alpha: 1)
    static let mouth      = UIColor(red: 0.42, green: 0.15, blue: 0.21, alpha: 1)
    static let tongue     = UIColor(red: 0.91, green: 0.45, blue: 0.50, alpha: 1)
    static let brow       = UIColor(red: 0.06, green: 0.30, blue: 0.33, alpha: 1)
    static let shadow     = UIColor(white: 0, alpha: 0.16)

    static let stageTop    = UIColor(red: 0.99, green: 0.87, blue: 0.70, alpha: 1)
    static let stageBottom = UIColor(red: 0.96, green: 0.68, blue: 0.53, alpha: 1)
    static let floor       = UIColor(red: 0.89, green: 0.56, blue: 0.44, alpha: 1)
}
