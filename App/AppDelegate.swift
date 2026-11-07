import UIKit

@main @MainActor final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
@MainActor final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var composition: AppComposition?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let composition = AppComposition()
        self.composition = composition
        let window = UIWindow(windowScene: scene)
        window.rootViewController = composition.rootViewController
        self.window = window
        composition.start()
        window.makeKeyAndVisible()
        let urls = connectionOptions.urlContexts.map(\.url) + connectionOptions.userActivities.compactMap(\.webpageURL)
        // OS entry points all converge on AppCoordinator.receive -> parser -> processor.
        for url in urls { composition.coordinator.receive(url) }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--authenticated") {
            Task { @MainActor [weak composition] in
                guard let composition else { return }
                await composition.coordinator.reset(authenticated: true)
                self.deliverLaunchLink(arguments, coordinator: composition.coordinator)
            }
        } else { deliverLaunchLink(arguments, coordinator: composition.coordinator) }
        #endif
    }
    #if DEBUG
    private func deliverLaunchLink(_ arguments: [String], coordinator: AppCoordinator) {
        if let index = arguments.firstIndex(of: "--link"), arguments.indices.contains(index + 1) {
            coordinator.submit(code: arguments[index + 1])
        }
    }
    #endif
    func sceneDidBecomeActive(_ scene: UIScene) { composition?.router.setSceneActive(true) }
    func sceneWillResignActive(_ scene: UIScene) { composition?.router.setSceneActive(false) }
    func sceneDidDisconnect(_ scene: UIScene) {
        composition?.coordinator.stop()
        composition = nil; window = nil
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { composition?.coordinator.receive(context.url) }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            composition?.coordinator.receive(url)
        }
    }
}
