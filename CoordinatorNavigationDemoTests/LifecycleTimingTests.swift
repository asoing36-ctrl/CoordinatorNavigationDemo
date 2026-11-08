import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct LifecycleTimingTests {
    @Test(arguments: [GatedCredentialRepository.Stage.create, .login, .redeem])
    func resetAfterAHeldBusinessResultCannotApplyObsoleteSessionOrNavigation(stage: GatedCredentialRepository.Stage) async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: stage, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let router = harness.composition.router
            if stage == .redeem { await app.reset(authenticated: true) }
            app.submit(code: stage == .redeem ? "ADD-CRED" : "NEW-USER")
            try await waitForNavigationCondition { gate.arrivals == 1 }
            let reset = Task { await app.reset(authenticated: false) }
            cleanup.track(reset)
            try await waitForNavigationCondition { gate.cancellations > 0 }
            #expect(!router.routes.contains(.phone))
            gate.release()
            await reset.value
            try await waitForNavigationCondition { router.routes == [.welcome] && harness.composition.navigationController.transitionCoordinator == nil }
            #expect(!app.session.isAuthenticated)
            #expect(app.session.credentials.isEmpty)
            #expect(app.processor.active == nil)
            #expect(app.children.isEmpty)
            #expect(!app.demo.busy)
            #expect(await backend.metrics().createdCount == 0)
            #expect(await backend.metrics().loginCount == 0)
        }
    }

    @Test func stopIgnoresANonCooperativeLateRedeemResult() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .redeem, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let router = harness.composition.router
            app.submit(code: "NEW-USER")
            try await waitForNavigationCondition { gate.arrivals == 1 }
            app.stop()
            let controllers = harness.composition.navigationController.viewControllers
            gate.release()
            await app.waitForOperation()
            #expect(harness.composition.navigationController.viewControllers == controllers)
            #expect(!router.routes.contains(.phone))
            #expect(!router.routes.contains(.home))
            #expect(app.onboarding == nil)
            #expect(app.processor.active == nil)
            #expect(!app.session.isAuthenticated)
            // Client cancellation cannot undo the already completed mock server grant.
            #expect(await backend.ownedCredentials(accountID: "new").count == 1)
        }
    }

    @Test func resetJoinsCancelledPhoneWorkBeforeResettingTheEnvironment() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let trace = LifecycleTrace()
        let repository = GatedCredentialRepository(backend: backend, stage: .phone, position: .before, gate: gate, trace: trace)
        let environment = GatedMockEnvironment(backend: backend, trace: trace)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, environment: environment,
            beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let router = harness.composition.router
            app.submit(code: "EXISTING-USER"); await app.waitForOperation()
            try await waitForNavigationCondition { router.routes.last == .phone && harness.composition.navigationController.transitionCoordinator == nil }
            weak var oldChild = app.onboarding
            cleanup.phone = app.onboarding
            app.onboarding?.associate(simulateFailure: false)
            try await waitForNavigationCondition { gate.arrivals == 1 }
            let reset = Task { await app.reset(authenticated: true) }
            cleanup.track(reset)
            try await waitForNavigationCondition { gate.cancellations > 0 }
            gate.release()
            await reset.value
            await cleanup.joinPhone()
            try await waitForNavigationCondition { trace.events.contains(.phoneReturned) && router.routes == [.home] &&
                harness.composition.navigationController.transitionCoordinator == nil && oldChild == nil }
            #expect(trace.events == [.phoneReturned, .environmentReset])
            #expect(await backend.metrics().phoneAssociationCount == 0)
            #expect(app.session.session == UserSession(accountID: "demo"))
            #expect(app.session.credentials.count == 1)
            #expect(app.processor.active == nil)
        }
    }

    @Test func stoppedPhoneCompletionCannotInstallHomeAndChildIsReleasedAfterJoining() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let trace = LifecycleTrace()
        let repository = GatedCredentialRepository(backend: backend, stage: .phone, position: .before, gate: gate, trace: trace)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let navigation = harness.composition.navigationController
            app.submit(code: "NEW-USER"); await app.waitForOperation()
            try await waitForNavigationCondition { navigation.topViewController is AssociatePhoneViewController && navigation.transitionCoordinator == nil }
            weak var weakChild: OnboardingCoordinator?
            do {
                let child = try #require(app.onboarding)
                weakChild = child
                cleanup.phone = child
                child.associate(simulateFailure: false)
                try await waitForNavigationCondition { gate.arrivals == 1 }
                let originalSession = app.session.session
                app.stop()
                let originalStack = navigation.viewControllers
                gate.release()
                await child.waitForOperation()
                await cleanup.joinPhone()
                #expect(trace.events == [.phoneReturned])
                #expect(await backend.metrics().phoneAssociationCount == 1)
                #expect(navigation.viewControllers == originalStack)
                #expect(app.session.session == originalSession)
                #expect(app.children.isEmpty)
                #expect(app.processor.active == nil)
                #expect(!harness.composition.router.routes.contains(.home))
            }
            try await waitForNavigationCondition { weakChild == nil }
        }
    }

    @Test func oldAlertActionsCannotCancelOrRetryANewHeldTransaction() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .redeem, position: .before,
            gate: gate, codeFilter: "ADD-CRED")
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend, repository: repository)
        let cleanup = LifecycleCleanup(gates: [gate])
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); await app.reset(authenticated: true)
            app.submit(code: "INVALID"); await app.waitForOperation()
            let obsoleteAction = try #require(router.lastAlertAction)
            await app.reset(authenticated: true)
            let stack = router.screens.map(\.controller)
            app.submit(code: "ADD-CRED")
            try await waitForNavigationCondition { gate.arrivals == 1 }
            app.submit(code: "EXPIRED")
            obsoleteAction(.retry); obsoleteAction(.cancel)
            #expect(app.processor.active == .redeemCredential(accessCode: "ADD-CRED"))
            #expect(app.processor.pendingCount == 1)
            #expect(router.screens.map(\.controller) == stack)
            #expect(app.flow == .redeeming)
            gate.release()
            await app.waitForOperation()
            #expect(app.session.credentials.count == 2)
            #expect(app.processor.active == .redeemCredential(accessCode: "EXPIRED"))
            #expect(router.routes == [.home])
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI], [false, true])
    func selectedActionCompletesOnceOrIsCancelledBeforeDismissal(style: AppAlertStyle, cancelSelection: Bool) async throws {
        var ownedPresentation: AlertPresentation?
        var outcomes: [AppAlertAction?] = []
        var cleanupWaiter: CheckedContinuation<Void, Never>?
        try await withNavigationWindow(beforeClose: {
            guard let presentation = ownedPresentation else { return }
            presentation.cancel()
            if outcomes.isEmpty {
                await withCheckedContinuation { cleanupWaiter = $0 }
            }
        }) { harness in
            let router = harness.composition.router
            let modal = UIViewController()
            modal.modalPresentationStyle = .fullScreen
            router.present(modal, route: .uikitFullScreen)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            let presentation = AlertPresentation(request: .redeemFailure(message: "Recover", style: style), presenter: modal) {
                outcomes.append($0)
                cleanupWaiter?.resume(); cleanupWaiter = nil
            }
            ownedPresentation = presentation
            presentation.present()
            try await waitForNavigationCondition {
                let visible = AlertPresentation.visibleController(from: harness.composition.rootViewController)
                return visible is UIAlertController && visible.viewIfLoaded?.window != nil && !visible.isBeingPresented
            }
            // This is the renderer's typed selection boundary, not a synthetic tap.
            presentation.select(.retry)
            if cancelSelection { presentation.cancel() } // Before queued native dismissal.
            presentation.select(.cancel)
            try await waitForNavigationCondition { outcomes.count == 1 &&
                AlertPresentation.visibleController(from: harness.composition.rootViewController) === modal }
            #expect(outcomes == [cancelSelection ? nil : .retry])
            #expect(router.presentedRoute == .uikitFullScreen)
            presentation.cancel(); presentation.select(.retry)
            #expect(outcomes.count == 1)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI], [true, false])
    func phoneCompletionPreservesVisibleOrBufferedGlobalNotice(style: AppAlertStyle, active: Bool) async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .phone, position: .before, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, repository: repository, beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            app.submit(code: "NEW-USER"); await app.waitForOperation()
            try await waitForNavigationCondition { navigation.topViewController is AssociatePhoneViewController && navigation.transitionCoordinator == nil }
            let onboarding = try #require(app.onboarding)
            cleanup.phone = onboarding
            onboarding.associate(simulateFailure: false)
            try await waitForNavigationCondition { gate.arrivals == 1 }
            app.demo.alertStyle = style
            router.setSceneActive(active)
            app.receive(URL(string: "credentialdemo://unsupported")!)
            var originalNotice: UIAlertController?
            var originalOwner: UIViewController?
            if active {
                try await waitForNavigationCondition {
                    let visible = AlertPresentation.visibleController(from: harness.composition.rootViewController)
                    return visible is UIAlertController && visible.viewIfLoaded?.window != nil && !visible.isBeingPresented
                }
                originalNotice = try #require(AlertPresentation.visibleController(from: harness.composition.rootViewController) as? UIAlertController)
                originalOwner = try #require(navigation.presentedViewController)
            } else { #expect(!router.hasAlertPresentation) }
            gate.release()
            await onboarding.waitForOperation()
            await cleanup.joinPhone()
            #expect(app.flow == .authenticated)
            #expect(app.processor.active == nil)
            if active {
                let notice = try #require(originalNotice)
                let owner = try #require(originalOwner)
                // Let any wrongly queued cancellation begin; settle its real native
                // transition before checking ownership, so a fading alert cannot pass.
                await nextLifecycleMainQueueTurn()
                try await waitForNavigationCondition {
                    !notice.isBeingPresented && !notice.isBeingDismissed && notice.transitionCoordinator == nil &&
                    !owner.isBeingPresented && !owner.isBeingDismissed && owner.transitionCoordinator == nil &&
                    navigation.transitionCoordinator == nil
                }
                #expect(router.hasAlertPresentation)
                #expect(navigation.presentedViewController === owner)
                #expect(owner.viewIfLoaded?.window != nil)
                #expect(notice.viewIfLoaded?.window != nil)
                #expect(AlertPresentation.visibleController(from: harness.composition.rootViewController) === notice)
                #expect(router.routes.last == .phone)
                #expect(router.backBlocked)
                router.cancelAlerts() // Administrative cleanup, not simulated acknowledgment.
                try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
            } else {
                try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
                router.setSceneActive(true)
                try await waitForNavigationCondition { AlertPresentation.visibleController(from: harness.composition.rootViewController) is UIAlertController }
                let notice = try #require(AlertPresentation.visibleController(from: harness.composition.rootViewController) as? UIAlertController)
                #expect(notice.title == "Unsupported Link")
            }
            #expect(navigation.viewControllers.count == 1)
            #expect(!router.backBlocked)
            #expect(await backend.metrics().phoneAssociationCount == 1)
        }
    }

    @Test func obsoleteSeedCompletionCannotDrainTheReconnectedScenesStartupBuffer() async throws {
        let oldBackend = MockBackend(delay: .zero)
        let newBackend = MockBackend(delay: .zero)
        let oldGate = LifecycleGate()
        let newGate = LifecycleGate()
        let old = AppComposition(backend: oldBackend, environment: GatedMockEnvironment(backend: oldBackend, seedGate: oldGate))
        let fresh = AppComposition(backend: newBackend, environment: GatedMockEnvironment(backend: newBackend, seedGate: newGate))
        let cleanup = LifecycleCleanup(gates: [oldGate, newGate])
        cleanup.track(old.coordinator); cleanup.track(fresh.coordinator)
        try await withSceneDelegateWindow(composition: old, authenticated: true,
            initialURLs: [URL(string: "credentialdemo://redeem?code=NEW-USER")!],
            beforeClose: { await cleanup.finish() }) { harness in
            try await waitForNavigationCondition { oldGate.arrivals == 1 }
            let obsoleteStartup = try #require(harness.startupTask)
            let oldActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            oldActivity.webpageURL = URL(string: "https://demo.example.com/redeem?code=EXPIRED")!
            harness.delegate.scene(harness.scene, continue: oldActivity)
            try await harness.reconnect(composition: fresh, authenticated: true)
            try await waitForNavigationCondition { newGate.arrivals == 1 }
            let currentStartup = try #require(harness.startupTask)
            let newActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            newActivity.webpageURL = URL(string: "https://demo.example.com/redeem?code=ADD-CRED")!
            harness.delegate.scene(harness.scene, continue: newActivity)
            oldGate.release()
            await obsoleteStartup.value
            #expect(fresh.coordinator.demo.busy)
            #expect(!fresh.coordinator.session.isAuthenticated)
            newGate.release()
            await currentStartup.value
            await fresh.coordinator.waitForOperation()
            try await waitForNavigationCondition { fresh.router.routes == [.home] && fresh.navigationController.transitionCoordinator == nil }
            #expect(fresh.coordinator.session.credentials.count == 2)
            #expect(fresh.coordinator.session.permissions.contains("premium"))
            #expect(fresh.coordinator.processor.active == nil)
            #expect(!old.coordinator.session.isAuthenticated)
            #expect(old.coordinator.processor.active == nil)
            #expect(old.coordinator.onboarding == nil)
        }
    }
}
