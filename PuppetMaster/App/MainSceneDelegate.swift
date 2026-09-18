import UIKit
import SwiftUI

/// The phone in the performer's hand.
///
/// Hosts whichever layout the router has selected. It does not decide anything about
/// surfaces itself — that is the router's single responsibility.
final class MainSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: RootView())
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        MainActor.assumeIsolated { AppEnvironment.shared.startClock() }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        MainActor.assumeIsolated {
            // Stop performing when we go away: a puppet animating in the background is
            // pure battery drain, and a live microphone there would be indefensible.
            AppEnvironment.shared.voice.endTalking()
            AppEnvironment.shared.stopClock()
        }
    }
}
