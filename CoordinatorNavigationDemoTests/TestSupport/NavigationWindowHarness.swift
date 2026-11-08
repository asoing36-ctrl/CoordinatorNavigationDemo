import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@MainActor final class NavigationWindowHarness {
    let composition: AppComposition
    private let window: UIWindow
    private let appearance = NavigationWindowAppearanceProbe()
    private weak var previousWindow: UIWindow?

    private init(backend: MockBackend, maximumPendingNavigation: Int, maximumNavigationBurst: Int,
                 repository: (any CredentialRepository)?, environment: (any MockEnvironmentManaging)?, noticeClock: (any NoticeClock)?) throws {
        let composition = AppComposition(backend: backend, maximumPendingNavigation: maximumPendingNavigation,
            maximumNavigationBurst: maximumNavigationBurst, repository: repository, environment: environment, noticeClock: noticeClock)
        self.composition = composition
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = composition.rootViewController
        // Match SceneDelegate: install content BEFORE the window begins appearing.
        composition.start()
        let root = composition.rootViewController
        root.addChild(appearance)
        root.view.addSubview(appearance.view)
        appearance.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        appearance.view.isUserInteractionEnabled = false
        appearance.didMove(toParent: root)
        window.makeKeyAndVisible()
    }
    static func make(backend: MockBackend, maximumPendingNavigation: Int, maximumNavigationBurst: Int,
                     repository: (any CredentialRepository)?, environment: (any MockEnvironmentManaging)?, noticeClock: (any NoticeClock)?,
                     beforeClose: @MainActor () async -> Void) async throws -> NavigationWindowHarness {
        let harness = try NavigationWindowHarness(backend: backend, maximumPendingNavigation: maximumPendingNavigation,
            maximumNavigationBurst: maximumNavigationBurst, repository: repository, environment: environment, noticeClock: noticeClock)
        do {
            try await waitForNavigationCondition { harness.appearance.didAppear }
            harness.composition.router.setSceneActive(true)
            harness.appearance.willMove(toParent: nil)
            harness.appearance.view.removeFromSuperview()
            harness.appearance.removeFromParent()
            return harness
        } catch {
            await harness.close(beforeClose: beforeClose)
            throw error
        }
    }
    func close(beforeClose: @MainActor () async -> Void) async {
        composition.coordinator.stop()
        // Release test gates and join work even when construction/body assertions throw.
        await beforeClose()
        // Do not destroy a window while the router still owns native alert cleanup.
        try? await waitForNavigationCondition { !self.composition.router.hasAlertPresentation &&
            self.composition.navigationController.transitionCoordinator == nil }
        if composition.navigationController.presentedViewController != nil {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                composition.navigationController.dismiss(animated: false) { continuation.resume() }
            }
        }
        previousWindow?.makeKeyAndVisible()
        // Let UIKit return from key-window/appearance callbacks before releasing the root.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        window.isHidden = true
        window.rootViewController = nil
    }
}

@MainActor private final class NavigationWindowAppearanceProbe: UIViewController {
    private(set) var didAppear = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didAppear = true
    }
}

@MainActor func withNavigationWindow(
    backend: MockBackend = MockBackend(delay: .zero),
    maximumPendingNavigation: Int = 32,
    maximumNavigationBurst: Int = 4,
    repository: (any CredentialRepository)? = nil,
    environment: (any MockEnvironmentManaging)? = nil,
    noticeClock: (any NoticeClock)? = nil,
    beforeClose: @MainActor () async -> Void = {},
    _ body: @MainActor (NavigationWindowHarness) async throws -> Void
) async throws {
    // Suite-level serialization does not serialize two different suites. Share one
    // native window lease across the alert and router suites in this host process.
    await NavigationWindowAccess.acquire()
    defer { NavigationWindowAccess.release() }
    try Task.checkCancellation()
    let harness = try await NavigationWindowHarness.make(backend: backend, maximumPendingNavigation: maximumPendingNavigation,
        maximumNavigationBurst: maximumNavigationBurst, repository: repository, environment: environment, noticeClock: noticeClock, beforeClose: beforeClose)
    do {
        try await body(harness)
        await harness.close(beforeClose: beforeClose)
    } catch {
        await harness.close(beforeClose: beforeClose)
        throw error
    }
}

@MainActor private enum NavigationWindowAccess {
    private static var occupied = false
    private static var waiting: [CheckedContinuation<Void, Never>] = []
    static func acquire() async {
        if occupied {
            await withCheckedContinuation { waiting.append($0) }
        } else { occupied = true }
    }
    static func release() {
        if waiting.isEmpty { occupied = false }
        else { waiting.removeFirst().resume() }
    }
}

/// Uses its own SceneDelegate/window; never disconnects the host app's delegate.
@MainActor final class SceneDelegateWindowHarness {
    let scene: UIWindowScene
    let delegate = SceneDelegate()
    private(set) var startupTask: Task<Void, Never>?
    private var startupTasks: [Task<Void, Never>] = []
    private var window: SceneAppearanceWindow?
    private weak var previousWindow: UIWindow?

    private init(composition: AppComposition?, authenticated: Bool, initialURLs: [URL]) throws {
        scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = SceneAppearanceWindow(windowScene: scene)
        self.window = window
        let task = delegate.connect(window: window, initialURLs: initialURLs, authenticated: authenticated, composition: composition)
        startupTask = task
        startupTasks.append(task)
    }
    static func make(composition: AppComposition?, authenticated: Bool, initialURLs: [URL],
                     beforeClose: @MainActor () async -> Void) async throws -> SceneDelegateWindowHarness {
        let harness = try SceneDelegateWindowHarness(composition: composition, authenticated: authenticated, initialURLs: initialURLs)
        do {
            try await harness.finishAppearance()
            return harness
        } catch { await harness.close(beforeClose: beforeClose); throw error }
    }
    private func finishAppearance() async throws {
        try await waitForNavigationCondition { self.window?.appearance.didAppear == true }
        delegate.sceneDidBecomeActive(scene)
        if let appearance = window?.appearance {
            appearance.willMove(toParent: nil)
            appearance.view.removeFromSuperview()
            appearance.removeFromParent()
        }
    }
    func reconnect(composition: AppComposition, authenticated: Bool) async throws {
        delegate.sceneDidDisconnect(scene)
        await releaseWindow()
        let window = SceneAppearanceWindow(windowScene: scene)
        self.window = window
        let task = delegate.connect(window: window, initialURLs: [], authenticated: authenticated, composition: composition)
        startupTask = task
        startupTasks.append(task)
        try await finishAppearance()
    }
    func navigationController() throws -> PolicyNavigationController {
        try #require(window?.rootViewController?.children.compactMap { $0 as? PolicyNavigationController }.first)
    }
    func releaseWindow() async {
        guard let window else { return }
        let navigation = window.rootViewController?.children.compactMap { $0 as? PolicyNavigationController }.first
        try? await waitForNavigationCondition { navigation?.transitionCoordinator == nil &&
            navigation?.presentedViewController?.transitionCoordinator == nil &&
            navigation?.presentedViewController?.isBeingPresented != true &&
            navigation?.presentedViewController?.isBeingDismissed != true }
        if navigation?.presentedViewController != nil {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                navigation?.dismiss(animated: false) { continuation.resume() }
            }
        }
        previousWindow?.makeKeyAndVisible()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        window.isHidden = true
        window.rootViewController = nil
        self.window = nil
    }
    func close(beforeClose: @MainActor () async -> Void) async {
        delegate.sceneDidDisconnect(scene)
        await beforeClose()
        // Reconnect intentionally does not wait for obsolete startup. Final cleanup
        // joins every retained handle before destroying the current window/lease.
        for task in startupTasks { await task.value }
        startupTasks.removeAll(); startupTask = nil
        await releaseWindow()
    }
}

@MainActor private final class SceneAppearanceWindow: UIWindow {
    let appearance = NavigationWindowAppearanceProbe()
    override func makeKeyAndVisible() {
        if appearance.parent == nil, let root = rootViewController {
            root.addChild(appearance)
            root.view.addSubview(appearance.view)
            appearance.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            appearance.view.isUserInteractionEnabled = false
            appearance.didMove(toParent: root)
        }
        super.makeKeyAndVisible()
    }
}

@MainActor func withSceneDelegateWindow(
    composition: AppComposition? = nil,
    authenticated: Bool = false,
    initialURLs: [URL] = [],
    beforeClose: @MainActor () async -> Void = {},
    _ body: @MainActor (SceneDelegateWindowHarness) async throws -> Void
) async throws {
    await NavigationWindowAccess.acquire()
    defer { NavigationWindowAccess.release() }
    try Task.checkCancellation()
    let harness = try await SceneDelegateWindowHarness.make(composition: composition, authenticated: authenticated, initialURLs: initialURLs, beforeClose: beforeClose)
    do { try await body(harness); await harness.close(beforeClose: beforeClose) }
    catch { await harness.close(beforeClose: beforeClose); throw error }
}

@MainActor func waitForNavigationCondition(
    diagnostics: @MainActor () -> String = { "" },
    _ condition: @MainActor () -> Bool,
    fileID: String = #fileID, filePath: String = #filePath,
    line: Int = #line, column: Int = #column
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    try #require(condition(), Comment(rawValue: "The native presentation/transition must complete before continuing. \(diagnostics())"),
        sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
}
