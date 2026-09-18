import Foundation

/// Anything that can draw a puppet.
///
/// Pure in its vocabulary — no UIKit, no SpriteKit, no geometry types from a
/// rendering framework. Swapping SpriteKit for pure SwiftUI later means writing one
/// new conformance; the engine, the actions, the controls and the tests are untouched.
///
/// The engine pushes to *all* registered renderers each frame, which is how one
/// performance drives several surfaces at once (phone stage + external display, or
/// the two halves of a folding device).
@MainActor
public protocol PuppetRenderer: AnyObject {
    /// Build (or rebuild) the puppet. Called when a surface attaches and whenever the
    /// cast changes — characters are data, so this is the only thing a new one needs.
    func load(character: CharacterDescriptor)
    /// Change the staging. Separate from `load(character:)` because any character can
    /// perform against any backdrop and neither knows about the other.
    func setBackdrop(_ backdrop: Backdrop)
    func apply(pose: PuppetPose)
    func fire(effect: PuppetEffect)
}

/// Transient visual flourishes that are not part of the continuous pose.
public enum PuppetEffect: String, Sendable, CaseIterable {
    case dustPuff      // landing from a jump or a sneeze — a light knock
    case impact        // a real landing: more dust, and the stage shakes
    case sparkle       // happiness
    case confetti      // celebration
    case musicNotes    // dancing
}
