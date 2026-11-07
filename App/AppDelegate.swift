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
    private var startupTask: Task<Void, Never>?
    private var starting = false
    private var startupURLs: [URL] = []
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let urls = connectionOptions.urlContexts.map(\.url) + connectionOptions.userActivities.compactMap(\.webpageURL)
        #if DEBUG
        let authenticated = ProcessInfo.processInfo.arguments.contains("--authenticated")
        #else
        let authenticated = false
        #endif
        connect(window: UIWindow(windowScene: scene), initialURLs: urls, authenticated: authenticated)
    }
    /// Explicit window ownership; the OS entry point above decodes connection options.
    func connect(window: UIWindow, initialURLs: [URL], authenticated: Bool) {
        startupTask?.cancel()
        self.composition?.coordinator.stop()
        starting = true
        startupURLs.removeAll()
        let composition = AppComposition()
        self.composition = composition
        window.rootViewController = composition.rootViewController
        self.window = window
        composition.start()
        window.makeKeyAndVisible()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        #endif
        startupTask = Task { @MainActor [weak self, weak composition] in
            guard let composition else { return }
            await composition.start(initialURLs: initialURLs, authenticated: authenticated)
            guard !Task.isCancelled, let self, self.composition === composition else { return }
            self.starting = false
            self.startupTask = nil
            let waiting = self.startupURLs
            self.startupURLs.removeAll()
            for url in waiting { composition.coordinator.receive(url) }
            #if DEBUG
            self.deliverLaunchLink(arguments, coordinator: composition.coordinator)
            #endif
        }
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
        startupTask?.cancel(); startupTask = nil
        starting = false; startupURLs.removeAll()
        composition?.coordinator.stop()
        composition = nil; window = nil
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { receive(context.url) }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            receive(url)
        }
    }
    private func receive(_ url: URL) {
        // Covers URL/Universal Link callbacks that arrive while cold session setup awaits.
        if starting { startupURLs.append(url) }
        else { composition?.coordinator.receive(url) }
    }
}
