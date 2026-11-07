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
    func replaceStack(_ screens: [Screen]) { dismiss(); self.screens = screens; onChange?() }
    func setRoot(_ controller: UIViewController, route: Route) { replaceStack([Screen(controller: controller, route: route)]) }
    func present(_ controller: UIViewController, route: PresentationRoute) {
        guard presentedController == nil else { return }
        presentedController = controller; presentedRoute = route; onChange?()
    }
    func dismiss() { presentedController = nil; presentedRoute = nil; onChange?() }
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
