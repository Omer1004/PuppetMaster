import UIKit
import SwiftUI

/// The phone in the performer's hand.
///
/// Hosts whichever layout the router has selected. It does not decide anything about
/// surfaces itself — that is the router's single responsibility.
final class MainSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    /// The iOS 27 registration that lets Big Screen happen at all — a
    /// `UISceneAccessoryRegistration`. Typed as `AnyObject` because a stored property
    /// cannot be marked available from a newer OS than the deployment target. Held
    /// strongly: the registration is what keeps the accessory offered.
    private var stageAccessory: AnyObject?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: RootView())
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window

        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            registerStageAccessory(on: host)
        }
        #endif
    }

    /// **Beginning in iOS 27, an app only receives an external-display scene after it
    /// registers a scene accessory.** Before that, declaring the role in `Info.plist`
    /// was enough, and that is all this app did — so on iOS 27 Big Screen would quietly
    /// never appear. (Apple, "Presenting content on a connected display".)
    ///
    /// Registered on the root controller, which is presented for the app's whole life,
    /// so the behaviour matches iOS 26: whenever a display is available, the stage goes
    /// to it. The configuration names both the delegate class and the `Info.plist`
    /// entry, so either lookup finds `ExternalDisplaySceneDelegate`. The `Info.plist`
    /// entry stays for iOS 26.
    ///
    /// Written against Apple's documentation for the iOS 27.0 SDK; not yet run against a
    /// real display, like the rest of Big Screen.
    ///
    /// **Compiled only by an Xcode with the iOS 27 SDK.** `#available` is a runtime
    /// check; the symbols still have to exist at compile time, and CI's Xcode 26.6
    /// (iOS 26.5 SDK) does not have them. `compiler(>=6.4)` is the SDK switch: Xcode 27
    /// ships Swift 6.4, Xcode 26.6 ships 6.3. A build from Xcode 26 therefore has no
    /// Big Screen on iOS 27 devices — ship from Xcode 27.
    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private func registerStageAccessory(on controller: UIViewController) {
        let configuration = UISceneConfiguration(name: "Stage",
                                                 sessionRole: .windowExternalDisplayNonInteractive)
        configuration.delegateClass = ExternalDisplaySceneDelegate.self
        stageAccessory = controller.registerSceneAccessory(
            .externalNonInteractive(sceneConfiguration: configuration))
    }
    #endif

    func sceneDidBecomeActive(_ scene: UIScene) {
        MainActor.assumeIsolated { AppEnvironment.shared.startClock() }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        MainActor.assumeIsolated {
            // Stop performing when we go away: a puppet animating in the background is
            // pure battery drain, and a live microphone there would be indefensible.
            AppEnvironment.shared.voice.endTalking()
            // A repeat in progress or still pending is dropped, not saved for later.
            AppEnvironment.shared.voice.stopRepeating()
            AppEnvironment.shared.stopClock()
        }
    }
}
