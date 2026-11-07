import Testing
import Combine
import UIKit
@testable import CoordinatorNavigationDemo

@MainActor struct FlowTests {
    func makeApp() -> (AppCoordinator, RouterSpy, MockBackend) {
        let router = RouterSpy()
        let backend = MockBackend(delay: .zero)
        let app = AppCoordinator(router: router, backend: backend)
        app.start()
        return (app, router, backend)
    }
    @Test func coldStartLoginSessionTransitionAndSkip() async {
        let (app, router, _) = makeApp()
        app.receive(URL(string: "credentialdemo://redeem?code=NEW-USER")!)
        await app.waitForOperation()
        #expect(app.session.isAuthenticated)
        #expect(app.flow == .phoneAssociation)
        #expect(router.routes == [.welcome, .redeem, .phone])
        #expect(router.backBlocked)
        app.onboarding?.skip()
        #expect(app.flow == .authenticated)
        #expect(router.routes == [.home])
        #expect(!router.backBlocked)
        #expect(app.children.count == 1)
    }
    @Test func authenticatedStackIsPreservedAndUpdatesObserved() async {
        let (app, router, backend) = makeApp()
        await app.reset(authenticated: true)
        app.home?.showSecondary()
        let before = router.routes
        app.submit(code: "ADD-CRED")
        await app.waitForOperation()
        #expect(router.routes == before)
        #expect(app.onboarding == nil)
        #expect(app.session.permissions.contains("premium"))
        #expect(app.session.credentials.count == 2)
        #expect(await backend.metrics().loginCount == 0)
    }
    @Test func duplicatesAndQueueStayProtectedUntilCompletion() async {
        let (app, router, _) = makeApp()
        app.submit(code: "NEW-USER")
        app.submit(code: "NEW-USER")
        app.submit(code: "ADD-CRED")
        await app.waitForOperation()
        #expect(app.processor.pendingCount == 1)
        #expect(router.routes.last == .phone)
        app.onboarding?.skip()
        await app.waitForOperation()
        #expect(app.processor.pendingCount == 0)
        #expect(app.processor.active == nil)
        #expect(router.routes == [.home])
        #expect(app.session.credentials.count == 2)
    }
    @Test func associationFailureRemainsThenRetryCompletes() async {
        let (app, router, _) = makeApp()
        app.submit(code: "EXISTING-USER")
        await app.waitForOperation()
        let onboarding = app.onboarding!
        onboarding.associate(simulateFailure: true)
        await onboarding.waitForOperation()
        #expect(onboarding.model.error != nil)
        #expect(router.routes.last == .phone)
        onboarding.associate(simulateFailure: false)
        await onboarding.waitForOperation()
        #expect(router.routes == [.home])
    }
    @Test func invalidCodeHasRecoverableError() async {
        let (app, router, _) = makeApp()
        app.submit(code: "INVALID")
        await app.waitForOperation()
        #expect(!app.session.isAuthenticated)
        #expect(app.redeem?.model.error != nil)
        app.redeem?.close()
        #expect(router.routes == [.welcome])
        #expect(app.processor.active == nil)
    }
    @Test func callerCancellationDoesNotStrandReset() async {
        let (app, router, _) = makeApp()
        let resetting = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await app.reset(authenticated: true)
        }
        await resetting.value
        #expect(!app.demo.busy)
        #expect(router.routes == [.home])
        await app.reset(authenticated: false)
        #expect(router.routes == [.welcome])
        #expect(!app.session.isAuthenticated)
    }
    @Test func stoppedCoordinatorCannotBeRevivedByReset() async {
        let (app, router, _) = makeApp()
        // A lifecycle observer stops the app as reset begins. Suspended reset work
        // must not install a new Home flow when it resumes.
        let observation = app.demo.$busy.dropFirst().sink { busy in
            if busy { app.stop() }
        }
        await app.reset(authenticated: true)
        #expect(app.children.isEmpty)
        #expect(!app.session.isAuthenticated)
        #expect(router.routes == [.welcome])
        withExtendedLifetime(observation) {}
    }
    @Test func resetCancelsObsoleteFlow() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .milliseconds(100)))
        app.start()
        app.submit(code: "NEW-USER")
        await app.reset(authenticated: false)
        #expect(router.routes == [.welcome])
        #expect(app.children.isEmpty)
        #expect(!app.session.isAuthenticated)
    }
}

@MainActor struct RouterTests {
    @Test func pushDuplicatePopAndProtection() {
        let nav = PolicyNavigationController()
        let router = NavigationRouter(navigationController: nav)
        router.setRoot(UIViewController(), route: .welcome)
        router.push(UIViewController(), route: .secondary, policy: .allowed)
        router.push(UIViewController(), route: .secondary, policy: .allowed)
        #expect(router.routes == [.welcome, .secondary])
        #expect(nav.interactivePopGestureRecognizer?.isEnabled == true)
        router.push(UIViewController(), route: .phone, policy: .blocked)
        router.pop()
        router.popTo(.welcome)
        _ = nav.popViewController(animated: false)
        #expect(router.routes == [.welcome, .secondary, .phone])
        #expect(nav.topViewController!.navigationItem.hidesBackButton)
        #expect(nav.interactivePopGestureRecognizer?.isEnabled == false)
        router.replaceStack([Screen(controller: UIViewController(), route: .home)])
        router.push(UIViewController(), route: .secondary, policy: .allowed)
        router.pop()
        #expect(router.routes == [.home])
        #expect(!router.backBlocked)
    }
    @Test func xibOutletsAndActionsLoad() {
        let phone = AssociatePhoneViewController(model: PhoneViewModel(), associate: { _ in }, skip: {})
        phone.loadViewIfNeeded()
        #expect(phone.associateButton != nil)
        #expect(phone.skipButton != nil)
        let lab = NavigationLabViewController(openSwiftUI: {}, openUIKit: {})
        lab.loadViewIfNeeded()
        #expect(lab.swiftUIButton != nil)
    }
}

@MainActor final class RouterSpy: NavigationRouting {
    var screens: [Screen] = []
    let alerts = AppAlertQueue()
    var onChange: (() -> Void)?
    var presentedRoute: PresentationRoute?
    var presentedController: UIViewController?
    var routes: [Route] { screens.map(\.route) }
    var backBlocked: Bool { screens.last?.policy == .blocked }
    func push(_ controller: UIViewController, route: Route, policy: BackNavigationPolicy) {
        guard !routes.contains(route) else { return }
        screens.append(Screen(controller: controller, route: route, policy: policy)); onChange?()
    }
    func pop() { guard !backBlocked, screens.count > 1 else { return }; screens.removeLast(); onChange?() }
    func popTo(_ route: Route) { guard !backBlocked, let index = routes.firstIndex(of: route) else { return }; screens = Array(screens.prefix(index + 1)); onChange?() }
    func replaceStack(_ screens: [Screen]) { alerts.cancel(scope: .flow); dismiss(); self.screens = screens; onChange?() }
    func setRoot(_ controller: UIViewController, route: Route) { replaceStack([Screen(controller: controller, route: route)]) }
    func present(_ controller: UIViewController, route: PresentationRoute) {
        guard presentedController == nil else { return }
        presentedController = controller; presentedRoute = route; onChange?()
    }
    func dismiss() { presentedController = nil; presentedRoute = nil; onChange?() }
    @discardableResult func showAlert(_ request: AppAlertRequest, completion: @escaping @MainActor (AppAlertAction) -> Void) -> AlertAdmission { alerts.enqueue(request, completion: completion) }
    func setSceneActive(_ active: Bool) { alerts.sceneIsActive = active }
    func cancelAlerts() { alerts.cancelAll() }
    func cancelPendingNavigation() {} // This synchronous spy never has waiting commands.
}

@MainActor struct CompositionTests {
    @Test func diagnosticsCannotBecomeANavigationChild() {
        let composition = AppComposition()
        composition.rootViewController.loadViewIfNeeded()
        composition.start()
        let nav = composition.navigationController
        #expect(nav.parent === composition.rootViewController)
        #expect(composition.router.routes == [.welcome])
        #expect(nav.viewControllers.count == 1)
        #if DEBUG
        let overlay = composition.rootViewController.children.first { $0 !== nav }
        #expect(overlay != nil)
        #expect(overlay?.parent === composition.rootViewController)
        #expect(nav.children.allSatisfy { $0 !== overlay })
        #endif
        // Repeated startup must not install another overlay or replace the root.
        let root = nav.topViewController
        let childCount = composition.rootViewController.children.count
        composition.start()
        #expect(nav.topViewController === root)
        #expect(composition.rootViewController.children.count == childCount)
    }
}

@MainActor struct PresentationTests {
    @Test func swiftUISheetPreservesSecondaryAndDismissesThroughRouter() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        app.start()
        await app.reset(authenticated: true)
        app.home?.showSecondary()
        let controllers = router.screens.map(\.controller)
        app.home?.presentSwiftUI()
        #expect(router.presentedRoute == .credentialSheet)
        #expect(router.presentedController?.modalPresentationStyle == .pageSheet)
        #expect(router.routes == [.home, .secondary])
        #expect(app.demo.presentedScreen == "credentialSheet")
        app.home?.dismissPresentedScreen()
        #expect(router.presentedRoute == nil)
        #expect(router.screens.map(\.controller) == controllers)
        #expect(app.demo.presentedScreen == nil)
    }
    @Test func fullScreenUsesXIBAndHasDismissAction() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        app.start()
        await app.reset(authenticated: true)
        app.home?.presentUIKit()
        let controller = router.presentedController as? NavigationLabViewController
        controller?.loadViewIfNeeded()
        #expect(controller?.nibName == "NavigationLabViewController")
        #expect(controller?.modalPresentationStyle == .fullScreen)
        #expect(controller?.dismissButton?.isHidden == false)
        #expect(router.routes == [.home])
        controller?.dismissButton?.sendActions(for: .touchUpInside)
        #expect(router.presentedController == nil)
        #expect(router.routes == [.home])
    }
    @Test func resetRemovesPresentationAndDuplicateDoesNotReplaceIt() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        app.start()
        await app.reset(authenticated: true)
        app.home?.presentSwiftUI()
        let original = router.presentedController
        app.home?.presentUIKit()
        #expect(router.presentedController === original)
        await app.reset(authenticated: false)
        #expect(router.presentedController == nil)
        #expect(router.routes == [.welcome])
    }
    @Test func presentingWithoutAWindowDoesNotStrandRouter() {
        let router = NavigationRouter(navigationController: PolicyNavigationController())
        router.setRoot(UIViewController(), route: .home)
        router.present(UIViewController(), route: .credentialSheet)
        router.push(UIViewController(), route: .secondary)
        #expect(router.presentedRoute == nil)
        #expect(router.routes == [.home, .secondary])
    }
}

@MainActor struct GlobalAlertFlowTests {
    @Test func backgroundRedeemFailureWaitsForActivationAndPreservesDetails() async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        app.start(); await app.reset(authenticated: true)
        app.home?.showDetails()
        let before = router.screens.map(\.controller)
        app.submit(code: "INVALID"); await app.waitForOperation()
        #expect(router.alerts.current == nil)
        #expect(router.alerts.pendingCount == 1)
        #expect(app.processor.active != nil)
        router.setSceneActive(true)
        let alert = try #require(router.alerts.beginNext())
        #expect(alert.title == "Unable to Redeem")
        router.alerts.complete(id: alert.id, action: .cancel)
        #expect(app.processor.active == nil)
        #expect(app.session.isAuthenticated)
        #expect(router.screens.map(\.controller) == before)
    }
    @Test func alertRetryUsesExistingSessionAndPreservesModal() async throws {
        let router = RouterSpy()
        let backend = MockBackend(delay: .zero)
        let app = AppCoordinator(router: router, backend: backend)
        app.start(); await app.reset(authenticated: true)
        router.setSceneActive(true)
        app.demo.alertStyle = .swiftUI
        app.home?.presentSwiftUI()
        let modal = router.presentedController
        app.submit(code: "NETWORK-FAIL"); await app.waitForOperation()
        let alert = try #require(router.alerts.beginNext())
        #expect(alert.style == .swiftUI)
        router.alerts.complete(id: alert.id, action: .retry)
        await app.waitForOperation()
        #expect(app.session.credentials.count == 2)
        #expect(await backend.metrics().loginCount == 0)
        #expect(router.presentedController === modal)
        #expect(router.routes == [.home])
    }
    @Test func resetDiscardsQueuedAlertAndItsCallback() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        app.start(); await app.reset(authenticated: true)
        app.submit(code: "EXPIRED"); await app.waitForOperation()
        #expect(router.alerts.pendingCount == 1)
        await app.reset(authenticated: false)
        router.setSceneActive(true)
        #expect(router.alerts.beginNext() == nil)
        #expect(!app.session.isAuthenticated)
        #expect(router.routes == [.welcome])
    }
}

@MainActor struct ColdURLStartupTests {
    @Test func authenticatedSetupCompletesBeforeColdURLIsRedeemed() async throws {
        let composition = AppComposition(backend: MockBackend(delay: .zero))
        let link = try #require(URL(string: "credentialdemo://redeem?code=ADD-CRED"))
        await composition.start(initialURLs: [link], authenticated: true)
        await composition.coordinator.waitForOperation()
        #expect(composition.coordinator.session.credentials.count == 2)
        #expect(composition.coordinator.session.permissions.contains("premium"))
        #expect(composition.coordinator.demo.loginCount == 0)
        #expect(composition.coordinator.onboarding == nil)
        #expect(composition.router.routes == [.home])
        composition.coordinator.stop()
    }

    @Test func unauthenticatedColdURLPushesPhoneAboveRedeem() async throws {
        let composition = AppComposition(backend: MockBackend(delay: .zero))
        let link = try #require(URL(string: "credentialdemo://redeem?code=NEW-USER"))
        await composition.start(initialURLs: [link], authenticated: false)
        await composition.coordinator.waitForOperation()
        #expect(composition.router.routes == [.welcome, .redeem, .phone])
        #expect(composition.navigationController.topViewController is AssociatePhoneViewController)
        #expect(composition.router.backBlocked)
        composition.coordinator.stop()
    }
}

/// These tests need the host app's real scene; none use a detached router or RouterSpy.
@Suite(.serialized) @MainActor struct NativeAlertLifecycleTests {
    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func alertCancellationKeepsPhoneProtectedAndSkipStillInstallsHome(style: AppAlertStyle) async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let link = try #require(URL(string: "credentialdemo://redeem?code=NEW-USER"))
            await composition.start(initialURLs: [link], authenticated: false)
            await composition.coordinator.waitForOperation()
            try await waitForNavigationCondition { composition.router.routes.last == .phone &&
                composition.navigationController.topViewController?.viewIfLoaded?.window != nil }
            let phone = try #require(composition.navigationController.topViewController)
            composition.router.setSceneActive(true)
            composition.router.showAlert(.demo(style: style))
            try await waitForNavigationCondition { nativeAlertIsVisible(in: composition) }
            composition.router.cancelAlerts()
            try await waitForNavigationCondition { !composition.router.hasAlertPresentation && AlertPresentation.visibleController(from: composition.rootViewController) === phone }
            composition.router.pop()
            #expect(composition.navigationController.topViewController === phone)
            #expect(composition.router.backBlocked)
            composition.coordinator.onboarding?.skip()
            try await waitForNavigationCondition { composition.router.routes == [.home] }
            #expect(!composition.router.backBlocked)
        }
    }

    @Test func swiftUIAlertDoesNotAddChildrenToTheUnderlyingHostingController() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let content = try #require(composition.navigationController.topViewController)
            let originalChildren = content.children
            composition.router.setSceneActive(true)
            composition.router.showAlert(.demo(style: .swiftUI))
            try await waitForNavigationCondition { nativeAlertIsVisible(in: composition) }
            #expect(content.children == originalChildren)
            composition.router.cancelAlerts()
            try await waitForNavigationCondition { !composition.router.hasAlertPresentation && AlertPresentation.visibleController(from: composition.rootViewController) === content }
            #expect(content.children == originalChildren)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func cancellationReleasesQueuedNavigationWithoutInvokingTheAction(style: AppAlertStyle) async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            var actionCount = 0
            composition.router.setSceneActive(true)
            composition.router.showAlert(.demo(style: style)) { _ in actionCount += 1 }
            try await waitForNavigationCondition { nativeAlertIsVisible(in: composition) }
            let next = UIViewController()
            composition.router.push(next, route: .secondary, policy: .allowed)
            #expect(composition.router.routes == [.welcome])
            composition.router.cancelAlerts()
            try await waitForNavigationCondition { composition.router.routes == [.welcome, .secondary] &&
                composition.navigationController.transitionCoordinator == nil }
            #expect(composition.navigationController.topViewController === next)
            #expect(actionCount == 0)
            #expect(AlertPresentation.visibleController(from: composition.rootViewController) === next)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func cancellingAlertPreservesTheExactFeatureModal(style: AppAlertStyle) async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let modal = UIViewController()
            modal.view.backgroundColor = .systemBackground
            modal.modalPresentationStyle = .fullScreen
            composition.router.present(modal, route: .uikitFullScreen)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            composition.router.setSceneActive(true)
            composition.router.showAlert(.demo(style: style))
            try await waitForNavigationCondition { nativeAlertIsVisible(in: composition) }
            composition.router.cancelAlerts()
            try await waitForNavigationCondition { !composition.router.hasAlertPresentation && AlertPresentation.visibleController(from: composition.rootViewController) === modal }
            #expect(modal.presentingViewController != nil)
            #expect(composition.router.presentedRoute == .uikitFullScreen)
            #expect(composition.router.routes == [.welcome])
        }
    }

    @Test func inactiveBusinessFailureWaitsAboveTheOriginalModalAndResetRemovesIt() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            await composition.start(initialURLs: [], authenticated: true)
            let originalSession = composition.coordinator.session.session
            composition.coordinator.home?.presentUIKit()
            try await waitForNavigationCondition { composition.router.presentedRoute == .uikitFullScreen &&
                AlertPresentation.visibleController(from: composition.rootViewController) is NavigationLabViewController }
            let modal = AlertPresentation.visibleController(from: composition.rootViewController)
            composition.router.setSceneActive(false)
            composition.coordinator.submit(code: "NETWORK-FAIL")
            await composition.coordinator.waitForOperation()
            #expect(composition.coordinator.processor.active != nil)
            #expect(AlertPresentation.visibleController(from: composition.rootViewController) === modal)
            #expect(composition.coordinator.session.session == originalSession)
            composition.router.setSceneActive(true)
            try await waitForNavigationCondition { nativeAlertIsVisible(in: composition) }
            #expect(modal.presentingViewController != nil)
            await composition.coordinator.reset(authenticated: false)
            try await waitForNavigationCondition { composition.router.routes == [.welcome] && composition.router.presentedRoute == nil }
            #expect(!composition.coordinator.session.isAuthenticated)
            #expect(composition.coordinator.processor.active == nil)
            #expect(!(AlertPresentation.visibleController(from: composition.rootViewController) is UIAlertController))
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func cancellingBeforePresentationCompletesStillAllowsTheNextScreen(style: AppAlertStyle) async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            router.setSceneActive(true)
            router.showAlert(.demo(style: style))
            router.cancelAlerts() // Before UIKit completes or SwiftUI's deferred binding starts.
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary] }
        }
    }
}

@MainActor private func nativeAlertIsVisible(in composition: AppComposition) -> Bool {
    let visible = AlertPresentation.visibleController(from: composition.rootViewController)
    // The transparent SwiftUI host alone is insufficient: wait for the native alert.
    return visible is UIAlertController && visible.viewIfLoaded?.window != nil &&
        visible.presentingViewController != nil &&
        !visible.isBeingPresented && !visible.isBeingDismissed
}
