import UIKit

/// UIKit lifecycle, on purpose.
///
/// SwiftUI's `App` lifecycle does not give us control over multiple window scenes with
/// different session roles, and multi-surface output is the entire point of this
/// product. So the app owns its scenes and hosts SwiftUI inside them — all public API,
/// no tricks. Every view in the app is still SwiftUI.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = AppEnvironment.shared
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Roles and their delegate classes are declared in Info.plist; this just picks
        // the configuration matching whichever surface the system is handing us.
        UISceneConfiguration(name: nil, sessionRole: session.role)
    }
}
