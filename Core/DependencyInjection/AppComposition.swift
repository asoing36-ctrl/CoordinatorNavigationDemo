import UIKit
import SwiftUI

/// Composition root exclusively owns the one navigation controller and concrete services.
@MainActor final class AppComposition {
    let navigationController: PolicyNavigationController
    let router: NavigationRouter
    let coordinator: AppCoordinator
    let rootViewController: UIViewController
    private var started = false

    init(backend: MockBackend = MockBackend(), maximumPendingNavigation: Int = 32,
         maximumPendingAlerts: Int = 9, maximumNavigationBurst: Int = 4) {
        let navigation = PolicyNavigationController()
        navigation.navigationBar.prefersLargeTitles = false
        navigationController = navigation
        let router = NavigationRouter(navigationController: navigation, maximumPendingNavigation: maximumPendingNavigation,
            maximumPendingAlerts: maximumPendingAlerts, maximumNavigationBurst: maximumNavigationBurst)
        self.router = router
        let coordinator = AppCoordinator(router: router, backend: backend)
        self.coordinator = coordinator
        router.onRejectedNavigation = { [weak coordinator] reason in
            if reason == .queueFull { coordinator?.reportCapacityExceeded() }
        }
        rootViewController = DemoRootViewController(navigationController: navigation, demo: coordinator.demo)
    }

    func start() {
        guard !started else { return }
        started = true
        rootViewController.loadViewIfNeeded()
        coordinator.start()
    }

    /// Initial OS URLs must run after optional demo session setup, which clears old flows.
    func start(initialURLs: [URL], authenticated: Bool) async {
        guard !Task.isCancelled else { return }
        start()
        if authenticated { await coordinator.reset(authenticated: true) }
        guard !Task.isCancelled else { return }
        for url in initialURLs { coordinator.receive(url) }
    }
}

/// Owns presentation chrome without modifying UINavigationController's managed children.
/// The navigation controller and diagnostics are siblings; only the router changes its stack.
@MainActor private final class DemoRootViewController: UIViewController {
    private let navigation: UINavigationController
    private let demo: DemoModel

    init(navigationController: UINavigationController, demo: DemoModel) {
        navigation = navigationController
        self.demo = demo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use dependency-injected initializer") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "applicationRoot"
        addChild(navigation)
        view.addSubview(navigation.view)
        navigation.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navigation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigation.view.topAnchor.constraint(equalTo: view.topAnchor),
            navigation.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigation.didMove(toParent: self)

        #if DEBUG
        let diagnostics = UIHostingController(rootView: DiagnosticsView(model: demo))
        diagnostics.sizingOptions = .intrinsicContentSize
        diagnostics.view.backgroundColor = .clear
        addChild(diagnostics)
        view.addSubview(diagnostics.view)
        diagnostics.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            diagnostics.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            diagnostics.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            diagnostics.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            diagnostics.view.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])
        diagnostics.didMove(toParent: self)
        #endif
    }

    override var childForStatusBarStyle: UIViewController? { navigation }
    override var childForStatusBarHidden: UIViewController? { navigation }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { navigation.supportedInterfaceOrientations }
}
