import UIKit
import SwiftUI

/// An audience-facing surface on a connected display.
///
/// This is the real, shipping-today version of the idea Duo will eventually make
/// literal: the performer holds the controls, and the audience sees only the puppet.
/// It attaches through the standard external-display scene role — no private API, no
/// mirroring hacks — and it proves the stage/controls split on hardware that exists.
///
/// The system creates this scene by itself when a display is connected, because
/// `Info.plist` declares the `externalDisplayNonInteractive` role.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        MainActor.assumeIsolated {
            let environment = AppEnvironment.shared
            let window = UIWindow(windowScene: windowScene)
            // Stage only, and explicitly not interactive: nothing on the audience's
            // screen is a control.
            window.rootViewController = UIHostingController(rootView: AudienceStageView())
            window.isHidden = false
            self.window = window

            environment.router.externalSurfaceConnected()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        MainActor.assumeIsolated {
            AppEnvironment.shared.router.externalSurfaceDisconnected()
        }
        window = nil
    }
}
