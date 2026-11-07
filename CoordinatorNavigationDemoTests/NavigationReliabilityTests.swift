import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct NavigationReliabilityTests {
    @Test func cancelledInteractivePresentationPreservesModalAndReleasesWaitingNavigation() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let root = try #require(navigation.topViewController)
            let modal = UIViewController()
            let probe = InteractivePresentationProbe()
            probe.configure(modal)
            defer { probe.cancelIfNeeded() }
            router.present(modal, route: .credentialSheet)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            probe.beginDismissal(of: modal)
            try await waitForNavigationCondition { probe.interactiveDismissalStarted }
            #expect(modal.transitionCoordinator?.isInteractive == true)
            #expect(probe.adaptiveCallbackForwarded)
            #expect(probe.completionRegistered)
            let presentationController = try #require(modal.presentationController)
            let secondary = UIViewController()
            router.push(secondary, route: .secondary, policy: .allowed)
            #expect(router.routes == [.welcome])
            probe.cancelIfNeeded()
            try await waitForNavigationCondition { probe.cancelledCompletionObserved &&
                router.routes == [.welcome, .secondary] && navigation.transitionCoordinator == nil &&
                modal.transitionCoordinator == nil && !modal.isBeingDismissed }
            #expect(navigation.presentedViewController === modal)
            #expect(router.presentedRoute == .credentialSheet)
            #expect(navigation.viewControllers[0] === root)
            #expect(navigation.topViewController === secondary)
            router.dismiss()
            let nextModal = UIViewController()
            nextModal.modalPresentationStyle = .pageSheet
            router.present(nextModal, route: .credentialSheet)
            try await waitForNavigationCondition { navigation.presentedViewController === nextModal && !nextModal.isBeingPresented }
            #expect(modal.presentingViewController == nil)
            #expect(navigation.topViewController === secondary)
            withExtendedLifetime(presentationController) {
                // Programmatic Done has its own completion; the fixture must
                // not inject a second adaptive completion after cancellation.
                #expect(probe.forwardedDidDismissCount == 0)
            }
        }
    }

    @Test func observerCanReplaceTheRootAfterACompletedPushWithoutReplayingOldCommands() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            let original = router.onChange
            defer { router.onChange = original; probe.restore() }
            let root = UIViewController()
            let details = UIViewController()
            var replaced = false
            router.onChange = {
                original?()
                if probe.deliveringDidShow, !replaced, router.routes.last == .secondary {
                    replaced = true
                    router.setRoot(root, route: .home)
                    router.push(details, route: .details, policy: .allowed)
                }
            }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            weak var obsolete: UIViewController?
            do {
                let phone = UIViewController()
                obsolete = phone
                router.push(phone, route: .phone, policy: .blocked)
            }
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.home, .details] && navigation.transitionCoordinator == nil }
            #expect(replaced)
            #expect(obsolete == nil)
            #expect(navigation.viewControllers[0] === root)
            #expect(navigation.topViewController === details)
            #expect(!probe.beganTransitionInsideDidShow)
            #expect(!router.backBlocked)
        }
    }

    @Test func observerCanCancelWaitingCommandsAndSubmitReplacementWork() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            let original = router.onChange
            defer { router.onChange = original; probe.restore() }
            let details = UIViewController()
            var cancelled = false
            router.onChange = {
                original?()
                if probe.deliveringDidShow, !cancelled, router.routes.last == .secondary {
                    cancelled = true
                    router.cancelPendingNavigation()
                    router.push(details, route: .details, policy: .allowed)
                }
            }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            weak var obsolete: UIViewController?
            do {
                let phone = UIViewController()
                obsolete = phone
                router.push(phone, route: .phone, policy: .blocked)
            }
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(cancelled)
            #expect(obsolete == nil)
            #expect(navigation.topViewController === details)
            #expect(!probe.beganTransitionInsideDidShow)
        }
    }

    @Test func rejectionCallbackCanRecoverWithAValidRootAndPush() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let owned = try #require(navigation.topViewController)
            let root = UIViewController()
            let details = UIViewController()
            var rejected: [NavigationRejection] = []
            let originalRejection = router.onRejectedNavigation
            defer { router.onRejectedNavigation = originalRejection }
            router.onRejectedNavigation = { reason in
                rejected.append(reason)
                if rejected.count == 1 {
                    router.setRoot(root, route: .home)
                    router.push(details, route: .details, policy: .allowed)
                }
            }
            router.push(owned, route: .lab, policy: .blocked)
            try await waitForNavigationCondition { router.routes == [.home, .details] && navigation.transitionCoordinator == nil }
            #expect(rejected == [.controllerInUse])
            #expect(navigation.viewControllers[0] === root)
            #expect(navigation.topViewController === details)
            #expect(!router.backBlocked)
        }
    }

    enum DisconnectPoint: Sendable { case push, modal, alert }

    @Test(arguments: [DisconnectPoint.push, .modal, .alert])
    func sceneDisconnectDropsWaitingWorkAndReleasesItsNavigation(point: DisconnectPoint) async throws {
        try await withSceneDelegateWindow { harness in
            weak var weakRouter: NavigationRouter?
            weak var weakNavigation: PolicyNavigationController?
            weak var weakRoot: UIViewController?
            weak var weakModal: UIViewController?
            var actionCount = 0
            do {
                let navigation = try harness.navigationController()
                let router = try #require(navigation.delegate as? NavigationRouter)
                weakRouter = router
                weakNavigation = navigation
                weakRoot = harness.delegate.window?.rootViewController
                let probe = NavigationTransitionProbe(navigation: navigation)
                let presentation = InteractivePresentationProbe(holdPresentation: true)
                defer { probe.restore(); presentation.heldPresentation.finish(); presentation.cancelIfNeeded() }
                switch point {
                case .push:
                    router.push(UIViewController(), route: .secondary, policy: .allowed)
                    try await waitForNavigationCondition { probe.heldPush.started }
                case .modal:
                    let modal = UIViewController()
                    weakModal = modal
                    presentation.configure(modal)
                    router.present(modal, route: .credentialSheet)
                    try await waitForNavigationCondition { presentation.heldPresentation.started }
                case .alert:
                    router.showAlert(.demo(style: .uikit)) { _ in actionCount += 1 }
                    try await waitForNavigationCondition {
                        guard let root = harness.delegate.window?.rootViewController else { return false }
                        let visible = AlertPresentation.visibleController(from: root)
                        return visible is UIAlertController && visible.isBeingPresented
                    }
                }
                weak var waiting: UIViewController?
                do {
                    let phone = UIViewController()
                    waiting = phone
                    router.push(phone, route: .phone, policy: .blocked)
                }
                harness.delegate.sceneDidDisconnect(harness.scene)
                #expect(harness.delegate.window == nil)
                #expect(waiting == nil)
                probe.heldPush.finish()
                presentation.heldPresentation.finish()
                try await waitForNavigationCondition { navigation.transitionCoordinator == nil && !router.hasAlertPresentation &&
                    weakModal?.transitionCoordinator == nil && weakModal?.isBeingPresented != true }
                #expect(!router.routes.contains(.phone))
                #expect(actionCount == 0)
            }
            // The test owns this UIWindow independently of SceneDelegate. Release
            // that fixture ownership after native completion, as UIKit does when
            // removing a disconnected scene's window.
            await harness.releaseWindow()
            try await waitForNavigationCondition { weakRouter == nil && weakNavigation == nil && weakRoot == nil && weakModal == nil }
            #expect(actionCount == 0)
        }
    }
}
