import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct QueuePolicyTests {
    enum SaturationPoint: Equatable, Sendable { case beforeRedeem, afterRedeemAdmission }

    @Test(arguments: [SaturationPoint.beforeRedeem, .afterRedeemAdmission])
    func saturatedNavigationStillReachesProtectedPhoneAndSkipCompletes(point: SaturationPoint) async throws {
        try await withNavigationWindow(maximumPendingNavigation: 2) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let original = app.processor.onIntent
            defer { app.processor.onIntent = original }
            router.showAlert(.demo(style: .uikit))
            try await waitForNavigationCondition { AlertPresentation.visibleController(from: harness.composition.rootViewController) is UIAlertController }
            let secondary = UIViewController()
            let details = UIViewController()
            if point == .beforeRedeem {
                router.push(secondary, route: .secondary, policy: .allowed)
                router.push(details, route: .details, policy: .allowed)
            } else {
                app.processor.onIntent = { [weak router] intent in
                    original?(intent) // Enqueues Redeem before its async backend task runs.
                    router?.push(secondary, route: .secondary, policy: .allowed)
                }
            }
            app.submit(code: "NEW-USER")
            await app.waitForOperation()
            #expect(app.flow == .phoneAssociation)
            #expect(app.processor.active != nil)
            router.cancelAlerts()
            try await waitForNavigationCondition { navigation.topViewController is AssociatePhoneViewController &&
                navigation.transitionCoordinator == nil }
            #expect(router.backBlocked)
            #expect(navigation.viewControllers.contains { $0 === secondary })
            if point == .beforeRedeem {
                #expect(navigation.viewControllers.contains { $0 === details })
                #expect(router.routes == [.welcome, .secondary, .details, .redeem, .phone])
            } else {
                #expect(router.routes == [.welcome, .redeem, .secondary, .phone])
            }
            let onboarding = try #require(app.onboarding)
            onboarding.skip()
            try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
            #expect(app.processor.active == nil)
            #expect(app.session.isAuthenticated)
        }
    }

    @Test func fullNavigationQueueRejectsNewestAndStillAdmitsFlowReplacement() async throws {
        try await withNavigationWindow(maximumPendingNavigation: 2) { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            let original = router.onRejectedNavigation
            defer { router.onRejectedNavigation = original; probe.restore() }
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            router.pop()
            router.push(UIViewController(), route: .details, policy: .allowed)
            weak var duplicate: UIViewController?
            weak var overflow: UIViewController?
            do {
                let next = UIViewController(); duplicate = next
                router.push(next, route: .details, policy: .allowed)
                let extra = UIViewController(); overflow = extra
                router.push(extra, route: .lab, policy: .allowed)
            }
            #expect(duplicate == nil)
            #expect(overflow == nil)
            #expect(rejected == [.queueFull])
            let root = UIViewController()
            router.setRoot(root, route: .home)
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[0] === root)
            #expect(rejected == [.queueFull])
        }
    }

    @Test func waitingAlertGetsATurnBeforeAnAcceptedNavigationBurstFinishes() async throws {
        try await withNavigationWindow(maximumNavigationBurst: 2) { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            router.push(UIViewController(), route: .details, policy: .allowed)
            router.pop()
            router.push(UIViewController(), route: .lab, policy: .allowed)
            router.popTo(.welcome)
            router.showAlert(.demo(style: .uikit))
            probe.heldPush.finish()
            try await waitForNavigationCondition { AlertPresentation.visibleController(from: harness.composition.rootViewController) is UIAlertController }
            #expect(router.routes == [.welcome, .secondary, .details])
            router.cancelAlerts()
            try await waitForNavigationCondition { router.routes == [.welcome] && navigation.transitionCoordinator == nil }
        }
    }

    @Test(arguments: [AppAlertScope.global, .flow])
    func visibleAlertLifetimeMatchesItsScopeDuringRootReplacement(scope: AppAlertScope) async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            var actions = 0
            router.showAlert(AppAlertRequest(key: "lifetime", style: .uikit, title: "Notice", message: "", scope: scope)) { _ in actions += 1 }
            try await waitForNavigationCondition { AlertPresentation.visibleController(from: harness.composition.rootViewController) is UIAlertController }
            let alert = AlertPresentation.visibleController(from: harness.composition.rootViewController)
            let root = UIViewController()
            router.setRoot(root, route: .home)
            if scope == .global {
                #expect(router.routes == [.welcome])
                #expect(AlertPresentation.visibleController(from: harness.composition.rootViewController) === alert)
                router.cancelAlerts() // Explicit administrative cancellation, not normal flow completion.
            }
            try await waitForNavigationCondition { router.routes == [.home] && !router.hasAlertPresentation }
            #expect(navigation.topViewController === root)
            #expect(actions == 0)
        }
    }

    @Test func inactiveGlobalNoticeIsDeliveredAfterTheNewRootAndFlowNoticeIsRemoved() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            router.setSceneActive(false)
            router.showAlert(AppAlertRequest(key: "old-flow", style: .uikit, title: "Old Flow", message: ""))
            router.showAlert(AppAlertRequest(key: "global", style: .uikit, title: "Global Notice", message: "", scope: .global))
            let root = UIViewController()
            router.setRoot(root, route: .home)
            router.setSceneActive(true)
            try await waitForNavigationCondition { AlertPresentation.visibleController(from: harness.composition.rootViewController) is UIAlertController }
            let alert = try #require(AlertPresentation.visibleController(from: harness.composition.rootViewController) as? UIAlertController)
            #expect(alert.title == "Global Notice")
            #expect(navigation.topViewController === root)
            #expect(router.routes == [.home])
        }
    }

    @Test func globalNoticeCapacityCannotHideTheSingleActiveRedeemRecovery() async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        app.start(); await app.reset(authenticated: true)
        for index in 0..<8 {
            router.showAlert(AppAlertRequest(key: "notice-\(index)", style: .uikit, title: "Notice \(index)", message: "", scope: .global)) { _ in }
        }
        app.submit(code: "INVALID"); await app.waitForOperation()
        #expect(router.alerts.pendingCount == 9)
        #expect(app.processor.active != nil)
        router.setSceneActive(true)
        for index in 0..<8 {
            let notice = try #require(router.alerts.beginNext())
            #expect(notice.title == "Notice \(index)")
            router.alerts.complete(id: notice.id, action: .ok)
        }
        let recovery = try #require(router.alerts.beginNext())
        #expect(recovery.title == "Unable to Redeem")
        router.alerts.complete(id: recovery.id, action: .cancel)
        #expect(app.processor.active == nil)
        #expect(app.session.isAuthenticated)
        #expect(router.routes == [.home])
    }

    @Test func rejectedRecoveryDoesNotWaitForeverForAnUnownedCallback() async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        app.start(); await app.reset(authenticated: true)
        for index in 0..<9 {
            router.showAlert(AppAlertRequest(key: "flow-\(index)", style: .uikit, title: "Flow", message: "")) { _ in }
        }
        app.submit(code: "INVALID"); await app.waitForOperation()
        #expect(app.processor.active == nil)
        #expect(app.session.isAuthenticated)
        #expect(router.routes == [.home])
        #expect(router.alerts.pendingCount == 9)
    }

    @Test func resetBuffersOnlyDistinctValidatedIntentsAndRejectsNewestAtCapacity() async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero), maximumPendingIntents: 2)
        let originalChange = router.onChange
        let originalIntent = app.processor.onIntent
        defer { router.onChange = originalChange; app.processor.onIntent = originalIntent; app.stop() }
        var injected = false
        var delivered: [AppIntent] = []
        app.processor.onIntent = { intent in delivered.append(intent); originalIntent?(intent) }
        router.onChange = {
            originalChange?()
            if !injected, app.demo.busy, router.routes == [.home] {
                injected = true
                app.receive(URL(string: "credentialdemo://unsupported")!)
                for code in ["ADD-CRED", "ADD-CRED", "INVALID", "EXPIRED"] {
                    app.receive(URL(string: "credentialdemo://redeem?code=\(code)")!)
                }
            }
        }
        app.start(); await app.reset(authenticated: true)
        await app.waitForOperation()
        #expect(injected)
        #expect(delivered == [.redeemCredential(accessCode: "ADD-CRED"), .redeemCredential(accessCode: "INVALID")])
        #expect(router.alerts.pendingCount == 3) // Unsupported, capacity notice, then flow recovery.
        #expect(app.session.credentials.count == 2)
    }
}
