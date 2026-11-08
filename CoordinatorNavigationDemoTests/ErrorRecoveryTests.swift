import Testing
import UIKit
@testable import CoordinatorNavigationDemo

private enum RecoveryDestination: String, CaseIterable, Sendable {
    case home, secondary, details, xib, sheet, fullScreen

    var routes: [Route] {
        switch self {
        case .secondary: return [.home, .secondary]
        case .details: return [.home, .details]
        case .xib: return [.home, .lab]
        default: return [.home]
        }
    }
    var modal: PresentationRoute? {
        switch self {
        case .sheet: return .credentialSheet
        case .fullScreen: return .uikitFullScreen
        default: return nil
        }
    }
    @MainActor func open(using home: HomeCoordinator) {
        switch self {
        case .home: break
        case .secondary: home.showSecondary()
        case .details: home.showDetails()
        case .xib: home.showLab()
        case .sheet: home.presentSwiftUI()
        case .fullScreen: home.presentUIKit()
        }
    }
}

private struct RecoveryFailure: Sendable {
    let code: String
    let message: String
    let style: AppAlertStyle
    static let cases = [AppAlertStyle.uikit, .swiftUI].flatMap { style in
        [("INVALID", DemoError.invalidCode), ("EXPIRED", .expiredCode), ("NETWORK-FAIL", .network)]
            .map { RecoveryFailure(code: $0.0, message: $0.1.localizedDescription, style: style) }
    }
}

/// Keeps original controllers alive so identity comparisons cannot pass through address reuse.
@MainActor private struct RecoverySnapshot {
    let controllers: [UIViewController]
    let modal: UIViewController?
    let session: UserSession?
    let credentials: [Credential]
    let permissions: Set<String>
    let home: HomeCoordinator?

    init(app: AppCoordinator, controllers: [UIViewController], modal: UIViewController?) {
        self.controllers = controllers; self.modal = modal
        session = app.session.session; credentials = app.session.credentials
        permissions = app.session.permissions; home = app.home
    }
    func expectNavigation(app: AppCoordinator, controllers: [UIViewController], modal: UIViewController?) {
        #expect(controllers.map(ObjectIdentifier.init) == self.controllers.map(ObjectIdentifier.init))
        #expect(modal === self.modal)
        #expect(app.home === home)
        #expect(app.redeem == nil && app.onboarding == nil)
        #expect(app.session.session == session)
    }
    func expectUnchangedData(_ app: AppCoordinator) {
        #expect(app.session.credentials == credentials)
        #expect(app.session.permissions == permissions)
    }
}

@MainActor struct ErrorRecoveryFlowTests {
    // Full business matrix, using real coordinators, use case, backend and alert
    // queue. RouterSpy records requests; it provides no native rendering evidence.
    @Test(arguments: RecoveryDestination.allCases, RecoveryFailure.cases)
    fileprivate func failuresPreserveEveryDestinationAndCancelAdvancesQueuedWork(
        destination: RecoveryDestination, failure: RecoveryFailure
    ) async throws {
        let backend = MockBackend(delay: .zero)
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend)
        let cleanup = LifecycleCleanup(gates: [])
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); await app.reset(authenticated: true)
            destination.open(using: try #require(app.home))
            (router.presentedController as? NavigationLabViewController)?.loadViewIfNeeded()
            (router.screens.last?.controller as? NavigationLabViewController)?.loadViewIfNeeded()
            let original = RecoverySnapshot(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
            app.demo.alertStyle = failure.style
            router.setSceneActive(true)
            app.submit(code: failure.code); await app.waitForOperation()
            let request = try #require(router.alerts.beginNext())
            #expect(request.style == failure.style && request.actions == [.retry, .cancel])
            #expect(request.message == failure.message && request.scope == .flow)
            #expect(app.flow == .redeeming)
            #expect(app.processor.active == .redeemCredential(accessCode: failure.code))
            original.expectNavigation(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
            original.expectUnchangedData(app)
            #expect(router.routes == destination.routes && router.presentedRoute == destination.modal)

            app.submit(code: failure.code) // Active duplicates must not become waiting work.
            app.submit(code: "ADD-CRED"); app.submit(code: "ADD-CRED")
            #expect(app.processor.pendingCount == 1)
            router.alerts.complete(id: request.id, action: .cancel)
            await app.waitForOperation()
            #expect(app.processor.active == nil && app.processor.pendingCount == 0)
            #expect(app.flow == .authenticated)
            #expect(app.session.credentials.count == 2)
            #expect(app.session.permissions == ["library", "premium"])
            #expect(await backend.ownedCredentials(accountID: "demo") == app.session.credentials)
            original.expectNavigation(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
            #expect(router.routes == destination.routes && router.presentedRoute == destination.modal)
            let metrics = await backend.metrics()
            #expect(metrics.loginCount == 0 && metrics.createdCount == 0 && metrics.phoneAssociationCount == 0)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI], [false, true])
    func repeatedRetryFailureKeepsOriginalTransactionUntilCancelOrSuccess(style: AppAlertStyle, recover: Bool) async throws {
        let backend = MockBackend(delay: .zero)
        let repository = RepeatedFailureRepository(backend: backend, failures: recover ? 2 : 3)
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend, repository: repository)
        let cleanup = LifecycleCleanup(gates: []); cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); await app.reset(authenticated: true)
            app.home?.showSecondary(); app.home?.presentSwiftUI()
            let original = RecoverySnapshot(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
            app.demo.alertStyle = style; router.setSceneActive(true)
            app.submit(code: "ADD-CRED"); await app.waitForOperation()
            app.submit(code: "EXISTING-USER")
            var previousID: UUID?
            for attempt in 1...(recover ? 2 : 3) {
                let request = try #require(router.alerts.beginNext())
                #expect(request.style == style && request.message == DemoError.network.localizedDescription)
                #expect(request.id != previousID)
                if let previousID {
                    router.alerts.complete(id: previousID, action: .cancel)
                    #expect(router.alerts.current?.id == request.id)
                }
                app.submit(code: "ADD-CRED"); app.submit(code: "EXISTING-USER")
                #expect(app.processor.pendingCount == 1)
                #expect(await repository.attempts == attempt)
                #expect(app.processor.active == .redeemCredential(accessCode: "ADD-CRED"))
                original.expectNavigation(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
                original.expectUnchangedData(app)
                previousID = request.id
                router.alerts.complete(id: request.id, action: !recover && attempt == 3 ? .cancel : .retry)
                await app.waitForOperation()
            }
            #expect(await repository.attempts == 3)
            #expect(app.processor.active == nil && app.processor.pendingCount == 0)
            #expect(router.alerts.current == nil && router.alerts.pendingCount == 0)
            #expect(app.session.credentials.count == (recover ? 3 : 2))
            #expect(app.session.permissions == (recover ? ["library", "members", "premium"] : ["library", "members"]))
            original.expectNavigation(app: app, controllers: router.screens.map(\.controller), modal: router.presentedController)
            let metrics = await backend.metrics()
            #expect(metrics.loginCount == 0 && metrics.createdCount == 0 && metrics.phoneAssociationCount == 0)
        }
    }
}

@Suite(.serialized) @MainActor struct ErrorRecoveryPresentationTests {
    // Real renderers and native cleanup; select() is their typed adapter boundary.
    // Actual alert button taps and OS URL delivery are tested in NavigationUITests.
    @Test(arguments: RecoveryDestination.allCases, [AppAlertStyle.uikit, .swiftUI])
    fileprivate func nativeRecoveryPreservesFeatureAndAllowsFurtherNavigation(destination: RecoveryDestination, style: AppAlertStyle) async throws {
        let backend = MockBackend(delay: .zero)
        try await withNavigationWindow(backend: backend) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            await app.reset(authenticated: true)
            destination.open(using: try #require(app.home))
            try await waitForNavigationCondition { router.routes == destination.routes && router.presentedRoute == destination.modal && Self.featureIsReady(navigation) }
            let original = RecoverySnapshot(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            app.demo.alertStyle = style
            app.submit(code: "NETWORK-FAIL"); await app.waitForOperation()
            try await Self.waitForAlert(navigation)
            original.expectUnchangedData(app)
            #expect(app.session.session == original.session && app.onboarding == nil && app.redeem == nil)
            app.submit(code: "ADD-CRED")
            let retry = destination == .secondary || destination == .xib || destination == .fullScreen
            let presentation = try #require(router.alertPresentation)
            presentation.select(retry ? .retry : .cancel)
            try await waitForNavigationCondition { !router.hasAlertPresentation && app.processor.active == nil && app.session.credentials.count == (retry ? 3 : 2) && Self.featureIsReady(navigation) }
            original.expectNavigation(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            #expect(app.session.permissions == (retry ? ["library", "premium", "recovered"] : ["library", "premium"]))
            #expect(router.routes == destination.routes && router.presentedRoute == destination.modal)
            #expect(app.processor.pendingCount == 0)
            let metrics = await backend.metrics()
            #expect(metrics.loginCount == 0 && metrics.createdCount == 0 && metrics.phoneAssociationCount == 0)
            // Recovery must leave ordinary Back, dismissal and the next presentation usable.
            if destination.modal != nil {
                app.home?.dismissPresentedScreen()
                try await waitForNavigationCondition { navigation.presentedViewController == nil && Self.featureIsReady(navigation) }
            } else if destination.routes.count > 1 {
                router.pop()
                try await waitForNavigationCondition { router.routes == [.home] && Self.featureIsReady(navigation) }
            }
            app.home?.presentSwiftUI()
            try await waitForNavigationCondition { router.presentedRoute == .credentialSheet && Self.featureIsReady(navigation) }
            app.home?.dismissPresentedScreen()
            try await waitForNavigationCondition { navigation.presentedViewController == nil && Self.featureIsReady(navigation) }
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func failureReturnedWhileInactiveWaitsAndPreservesFullScreen(style: AppAlertStyle) async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .redeem, position: .before, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator; cleanup.track(app)
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            await app.reset(authenticated: true)
            app.home?.presentUIKit()
            try await waitForNavigationCondition { router.presentedRoute == .uikitFullScreen && Self.featureIsReady(navigation) }
            let original = RecoverySnapshot(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            app.demo.alertStyle = style
            app.submit(code: "NETWORK-FAIL")
            try await waitForNavigationCondition { gate.arrivals == 1 }
            router.setSceneActive(false); gate.release()
            await app.waitForOperation()
            #expect(!router.hasAlertPresentation)
            #expect(app.processor.active == .redeemCredential(accessCode: "NETWORK-FAIL"))
            original.expectNavigation(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            original.expectUnchangedData(app)
            router.setSceneActive(true)
            try await Self.waitForAlert(navigation)
            let presentation = try #require(router.alertPresentation)
            presentation.select(.cancel)
            try await waitForNavigationCondition { !router.hasAlertPresentation && app.processor.active == nil && Self.featureIsReady(navigation) }
            original.expectNavigation(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            original.expectUnchangedData(app)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI], [false, true])
    func stopOrResetAfterSelectionSuppressesRetryAndQueuedWork(style: AppAlertStyle, reset: Bool) async throws {
        let backend = MockBackend(delay: .zero)
        let repository = RepeatedFailureRepository(backend: backend, failures: 3)
        try await withNavigationWindow(backend: backend, repository: repository) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            await app.reset(authenticated: true)
            app.home?.presentSwiftUI()
            try await waitForNavigationCondition { router.presentedRoute == .credentialSheet && Self.featureIsReady(navigation) }
            let original = RecoverySnapshot(app: app, controllers: navigation.viewControllers, modal: navigation.presentedViewController)
            app.demo.alertStyle = style
            app.submit(code: "ADD-CRED"); await app.waitForOperation()
            try await Self.waitForAlert(navigation)
            app.submit(code: "EXISTING-USER")
            let presentation = try #require(router.alertPresentation)
            presentation.select(.retry)
            // Same main-actor turn, before scheduled dismissal. This is deliberately
            // not represented as a native tap/auto-dismissal race.
            if reset { await app.reset(authenticated: false) } else { app.stop() }
            try await waitForNavigationCondition { !router.hasAlertPresentation && Self.featureIsReady(navigation) }
            presentation.select(.retry); presentation.select(.cancel) // Obsolete adapter calls.
            await app.waitForOperation()
            #expect(await repository.attempts == 1)
            #expect(app.processor.active == nil && app.processor.pendingCount == 0)
            #expect(!router.hasAlertPresentation)
            #expect(app.home == nil && app.onboarding == nil && app.redeem == nil)
            if reset {
                #expect(router.routes == [.welcome] && navigation.presentedViewController == nil)
                #expect(!app.session.isAuthenticated && app.session.credentials.isEmpty)
                app.submit(code: "NEW-USER"); await app.waitForOperation()
                try await waitForNavigationCondition { router.routes == [.welcome, .redeem, .phone] && Self.featureIsReady(navigation) }
                app.onboarding?.skip()
                try await waitForNavigationCondition { router.routes == [.home] && Self.featureIsReady(navigation) }
                #expect(!router.backBlocked && app.session.credentials.count == 1)
            } else {
                #expect(navigation.viewControllers == original.controllers)
                #expect(navigation.presentedViewController === original.modal)
                #expect(app.session.session == original.session)
                original.expectUnchangedData(app)
                #expect(await backend.ownedCredentials(accountID: "demo") == original.credentials)
            }
        }
    }

    private static func featureIsReady(_ navigation: UINavigationController) -> Bool {
        let visible = AlertPresentation.visibleController(from: navigation)
        return visible.viewIfLoaded?.window != nil && !visible.isBeingPresented && !visible.isBeingDismissed &&
            visible.transitionCoordinator == nil && navigation.transitionCoordinator == nil
    }
    private static func waitForAlert(_ navigation: UINavigationController) async throws {
        try await waitForNavigationCondition {
            AlertPresentation.visibleController(from: navigation) is UIAlertController && featureIsReady(navigation)
        }
    }
}

/// Fails the first N ADD-CRED attempts, then delegates to the deterministic backend.
/// Other codes remain real backend work, so queued success is independently observable.
private actor RepeatedFailureRepository: CredentialRepository {
    let backend: MockBackend
    let failures: Int
    private(set) var attempts = 0
    init(backend: MockBackend, failures: Int) { self.backend = backend; self.failures = failures }
    func resolveAccount(code: String) async throws -> Account? { try await backend.resolveAccount(code: code) }
    func createAccount(code: String) async throws -> Account { try await backend.createAccount(code: code) }
    func login(account: Account) async throws -> UserSession { try await backend.login(account: account) }
    func redeem(code: String, session: UserSession) async throws -> [Credential] {
        if code == "ADD-CRED" {
            attempts += 1
            if attempts <= failures { throw DemoError.network }
        }
        return try await backend.redeem(code: code, session: session)
    }
    func associatePhone(accountID: String, simulateFailure: Bool) async throws {
        try await backend.associatePhone(accountID: accountID, simulateFailure: simulateFailure)
    }
}
