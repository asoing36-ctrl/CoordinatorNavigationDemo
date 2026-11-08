import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct RouterLifecycleTests {
    @Test func inactiveReplacementWithModalWaitsForActivationBeforeCleanupAndRootChange() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let originalRoot = navigation.topViewController
            let modal = UIViewController()
            modal.modalPresentationStyle = .fullScreen
            router.present(modal, route: .uikitFullScreen)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            router.setSceneActive(false)
            let root = UIViewController()
            router.setRoot(root, route: .home)
            #expect(navigation.topViewController === originalRoot)
            #expect(router.routes == [.welcome])
            #expect(modal.presentingViewController != nil)
            router.setSceneActive(true)
            try await waitForNavigationCondition { router.routes == [.home] && router.presentedRoute == nil && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === root)
            #expect(modal.presentingViewController == nil)
        }
    }

    @Test func inactiveSceneDefersWindowedPushAndPresentationUntilActivation() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let root = navigation.viewControllers[0]
            router.setSceneActive(false)
            let secondary = UIViewController()
            let modal = UIViewController()
            modal.modalPresentationStyle = .pageSheet
            router.push(secondary, route: .secondary, policy: .allowed)
            router.present(modal, route: .credentialSheet)
            #expect(router.routes == [.welcome])
            #expect(modal.presentingViewController == nil)
            router.setSceneActive(true)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary] &&
                modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            #expect(navigation.viewControllers[0] === root)
            #expect(navigation.topViewController === secondary)
        }
    }

    @Test func inactiveRootReplacementDropsObsoleteWaitingRoutes() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.setSceneActive(false)
            router.push(UIViewController(), route: .details, policy: .allowed)
            let root = UIViewController()
            router.setRoot(root, route: .home)
            #expect(router.routes == [.home])
            router.setSceneActive(true)
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition(diagnostics: {
                "Routes: \(router.routes); native transition: \(navigation.transitionCoordinator != nil); Back blocked: \(router.backBlocked); rejected: \(rejected)"
            }) { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[0] === root)
            #expect(rejected.isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func immediatePushAfterVisibleReplacementWaitsForUIKit(reuseVisibleRoot: Bool) async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let current = try #require(navigation.topViewController)
            let root = reuseVisibleRoot ? current : UIViewController()
            let next = UIViewController()
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            router.setRoot(root, route: .home)
            router.push(next, route: .secondary, policy: .allowed)
            // A visible replacement owns this turn even if UIKit reports didShow
            // synchronously. The next command must not overlap its lifecycle.
            #expect(navigation.topViewController === root)
            try await waitForNavigationCondition { probe.heldPush.started }
            probe.heldPush.finish()
            try await waitForNavigationCondition(diagnostics: {
                "Routes: \(router.routes); native transition: \(navigation.transitionCoordinator != nil); rejected: \(rejected)"
            }) { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[0] === root)
            #expect(navigation.topViewController === next)
            router.pop()
            try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === root)
            #expect(rejected.isEmpty)
        }
    }

    @Test func updatingStackBehindFullScreenModalDoesNotWaitForHiddenAnimation() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let modal = UIViewController()
            modal.modalPresentationStyle = .fullScreen
            router.present(modal, route: .uikitFullScreen)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            let secondary = UIViewController()
            let details = UIViewController()
            router.push(secondary, route: .secondary, policy: .allowed)
            router.dismiss()
            router.push(details, route: .details, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] &&
                router.presentedRoute == nil && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[1] === secondary)
            #expect(navigation.topViewController === details)
            #expect(modal.presentingViewController == nil)
        }
    }

    @Test func aLongQueueOfNoOpBackRequestsStillAllowsTheNextValidPush() async throws {
        try await withNavigationWindow(maximumPendingNavigation: 1001) { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            for _ in 0..<1_000 { router.pop() }
            let details = UIViewController()
            router.push(details, route: .details, policy: .allowed)
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.welcome, .details] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers.count == 2)
            #expect(navigation.topViewController === details)
        }
    }

    @Test func observerNavigationWaitsUntilUIKitDelegateCallbackReturns() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            let originalObserver = router.onChange
            defer { router.onChange = originalObserver; probe.restore() }
            let details = UIViewController()
            var requested = false
            router.onChange = { [weak router] in
                originalObserver?()
                if probe.deliveringDidShow, !requested {
                    requested = true
                    router?.push(details, route: .details, policy: .allowed)
                }
            }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(requested)
            #expect(!probe.beganTransitionInsideDidShow)
            #expect(navigation.topViewController === details)
        }
    }

    @Test func reusingAControllerUnderAnotherRouteCannotCorruptOrStallNavigation() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let original = try #require(navigation.topViewController)
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(original, route: .details, policy: .blocked)
            #expect(router.routes == [.welcome])
            #expect(!router.backBlocked)
            #expect(rejected == [.controllerInUse])
            let next = UIViewController()
            router.push(next, route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[0] === original)
            #expect(navigation.topViewController === next)
        }
    }

    @Test func malformedReplacementCannotDiscardValidWaitingNavigation() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            let details = UIViewController()
            router.push(details, route: .details, policy: .allowed)
            let duplicate = UIViewController()
            router.replaceStack([Screen(controller: duplicate, route: .home), Screen(controller: duplicate, route: .lab)])
            router.replaceStack([Screen(controller: UIViewController(), route: .home), Screen(controller: UIViewController(), route: .home)])
            router.replaceStack([])
            #expect(rejected == [.invalidStack, .invalidStack, .invalidStack])
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === details)
        }
    }

    @Test func unsupportedStackControllersAreRejectedWithoutBreakingTheNextPush() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(UINavigationController(), route: .lab, policy: .allowed)
            router.push(UITabBarController(), route: .labDetail, policy: .allowed)
            router.push(UIAlertController(title: "Modal only", message: nil, preferredStyle: .alert), route: .phone, policy: .blocked)
            #expect(rejected == [.unsupportedStackController, .unsupportedStackController, .unsupportedStackController])
            #expect(router.routes == [.welcome])
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary] && navigation.transitionCoordinator == nil }
        }
    }

    @Test func foreignChildCannotBePushedPresentedOrInstalledAsRoot() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let owner = UIViewController()
            let child = UIViewController()
            owner.addChild(child)
            owner.view.addSubview(child.view)
            child.didMove(toParent: owner)
            defer {
                child.willMove(toParent: nil)
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(child, route: .details, policy: .allowed)
            router.present(child, route: .credentialSheet)
            router.setRoot(child, route: .home)
            #expect(rejected == [.controllerInUse, .controllerInUse, .controllerInUse])
            #expect(router.routes == [.welcome])
            #expect(child.parent === owner)
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary] && navigation.transitionCoordinator == nil }
        }
    }

    @Test func duplicatePushBurstReleasesRedundantWaitingControllers() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            let first = UIViewController()
            router.push(first, route: .details, policy: .allowed)
            weak var lastDuplicate: UIViewController?
            // As in the saturation test, drain UIKit construction temporaries
            // before asserting that the router released redundant candidates.
            autoreleasepool {
                for _ in 0..<100 {
                    let duplicate = UIViewController()
                    lastDuplicate = duplicate
                    router.push(duplicate, route: .details, policy: .allowed)
                }
            }
            #expect(lastDuplicate == nil)
            probe.heldPush.finish()
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === first)
            #expect(navigation.viewControllers.count == 3)
        }
    }

    @Test func protectedBackIsBlockedAndReplacementRestoresOrdinaryBack() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            var rejected: [NavigationRejection] = []
            router.onRejectedNavigation = { rejected.append($0) }
            router.push(UIViewController(), route: .secondary, policy: .allowed)
            router.push(UIViewController(), route: .phone, policy: .blocked)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .phone] && navigation.transitionCoordinator == nil }
            let protected = try #require(navigation.topViewController)
            let gesture = try #require(navigation.interactivePopGestureRecognizer)
            router.pop()
            router.popTo(.welcome)
            #expect(navigation.popViewController(animated: false) == nil)
            #expect(navigation.popToRootViewController(animated: false) == nil)
            #expect(navigation.popToViewController(navigation.viewControllers[0], animated: false) == nil)
            #expect(navigation.topViewController === protected)
            #expect(protected.navigationItem.hidesBackButton)
            #expect(!gesture.isEnabled)
            #expect(!router.gestureRecognizerShouldBegin(gesture))
            let root = UIViewController()
            router.setRoot(root, route: .home)
            let next = UIViewController()
            router.push(next, route: .secondary, policy: .allowed)
            try await waitForNavigationCondition(diagnostics: {
                "Routes: \(router.routes); native transition: \(navigation.transitionCoordinator != nil); Back blocked: \(router.backBlocked); rejected: \(rejected)"
            }) { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            #expect(rejected.isEmpty)
            #expect(!router.backBlocked)
            #expect(gesture.isEnabled)
            #expect(!next.navigationItem.hidesBackButton)
            _ = navigation.popViewController(animated: true)
            try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === root)
        }
    }

    @Test func modalDismissalFinishesBeforeQueuedPushAndPreservesHistory() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let secondary = UIViewController()
            router.push(secondary, route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { router.routes.last == .secondary && navigation.transitionCoordinator == nil }
            let original = navigation.viewControllers
            let modal = UIViewController()
            modal.modalPresentationStyle = .fullScreen
            router.present(modal, route: .uikitFullScreen)
            try await waitForNavigationCondition { modal.viewIfLoaded?.window != nil && !modal.isBeingPresented }
            let details = UIViewController()
            router.dismiss()
            router.push(details, route: .details, policy: .allowed)
            try await waitForNavigationCondition { router.routes == [.welcome, .secondary, .details] &&
                router.presentedRoute == nil && navigation.transitionCoordinator == nil }
            #expect(Array(navigation.viewControllers.prefix(2)) == original)
            #expect(navigation.topViewController === details)
            #expect(modal.presentingViewController == nil)
        }
    }

    @Test(arguments: [false, true])
    func rootReplacementWaitsForModalPresentationAndDismissal(fullScreen: Bool) async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let modal = UIViewController()
            modal.modalPresentationStyle = fullScreen ? .fullScreen : .pageSheet
            router.present(modal, route: fullScreen ? .uikitFullScreen : .credentialSheet)
            let root = UIViewController()
            router.setRoot(root, route: .home)
            try await waitForNavigationCondition { router.routes == [.home] && router.presentedRoute == nil &&
                navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers.count == 1)
            #expect(navigation.topViewController === root)
            #expect(navigation.presentedViewController == nil)
            #expect(modal.presentingViewController == nil)
        }
    }

    @Test func dismissThenPresentChangesOnlyTheModal() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let original = navigation.viewControllers
            let first = UIViewController()
            first.modalPresentationStyle = .fullScreen
            router.present(first, route: .uikitFullScreen)
            try await waitForNavigationCondition { first.viewIfLoaded?.window != nil && !first.isBeingPresented }
            let next = UIViewController()
            next.modalPresentationStyle = .pageSheet
            router.dismiss()
            router.present(next, route: .credentialSheet)
            try await waitForNavigationCondition { next.viewIfLoaded?.window != nil && !next.isBeingPresented && router.presentedRoute == .credentialSheet }
            #expect(first.presentingViewController == nil)
            #expect(navigation.viewControllers == original)
            #expect(navigation.presentedViewController === next)
        }
    }

    @Test func endingFlowDiscardsProtectedScreenQueuedBehindAnActivePush() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let navigation = composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            composition.router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            #expect(navigation.transitionCoordinator != nil)
            weak var waiting: UIViewController?
            do {
                let protected = UIViewController()
                waiting = protected
                composition.router.push(protected, route: .phone, policy: .blocked)
            }
            #expect(waiting != nil)
            #expect(composition.router.routes == [.welcome, .secondary])
            composition.coordinator.stop()
            #expect(waiting == nil)
            probe.heldPush.finish()
            try await waitForNavigationCondition { navigation.transitionCoordinator == nil }
            #expect(composition.router.routes == [.welcome, .secondary])
            #expect(navigation.viewControllers.count == 2)
        }
    }

    @Test func stackReplacementWaitsForActivePushAndDiscardsWaitingRoutes() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let navigation = composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            composition.router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            composition.router.push(UIViewController(), route: .phone, policy: .blocked)
            let root = UIViewController()
            composition.router.replaceStack([Screen(controller: root, route: .home)])
            probe.heldPush.finish()
            try await waitForNavigationCondition { composition.router.routes == [.home] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === root)
            #expect(navigation.viewControllers.count == 1)
            #expect(!composition.router.backBlocked)
        }
    }

    @Test func stoppedQueueReleasesPendingModalAndAllowsAnAuthorizedNewRoot() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let navigation = composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            composition.router.push(UIViewController(), route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            weak var queuedModal: UIViewController?
            do {
                let modal = UIViewController()
                queuedModal = modal
                composition.router.present(modal, route: .credentialSheet)
            }
            #expect(queuedModal != nil)
            composition.coordinator.stop()
            #expect(queuedModal == nil)
            let newRoot = UIViewController()
            composition.router.setRoot(newRoot, route: .home)
            probe.heldPush.finish()
            try await waitForNavigationCondition { composition.router.routes == [.home] && navigation.transitionCoordinator == nil }
            #expect(navigation.topViewController === newRoot)
            #expect(navigation.presentedViewController == nil)
            #expect(composition.router.presentedRoute == nil)
        }
    }

    @Test func normalCompletionDrainsOnceAndSuppressesDuplicateQueuedPushes() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let navigation = composition.navigationController
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            let secondary = UIViewController()
            let details = UIViewController()
            composition.router.push(secondary, route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { probe.heldPush.started }
            composition.router.push(details, route: .details, policy: .allowed)
            composition.router.push(UIViewController(), route: .details, policy: .allowed)
            #expect(composition.router.routes == [.welcome, .secondary])
            probe.heldPush.finish()
            try await waitForNavigationCondition { composition.router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers.count == 3)
            #expect(navigation.viewControllers[1] === secondary)
            #expect(navigation.topViewController === details)
        }
    }

    @Test func cancelledInteractivePopRestoresMetadataBeforeReleasingQueuedWork() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            let navigation = composition.navigationController
            let secondary = UIViewController()
            composition.router.push(secondary, route: .secondary, policy: .allowed)
            try await waitForNavigationCondition { navigation.transitionCoordinator == nil && composition.router.routes.last == .secondary }
            let probe = NavigationTransitionProbe(navigation: navigation)
            defer { probe.restore() }
            probe.prepareInteractivePop()
            composition.router.pop()
            try await waitForNavigationCondition { probe.popAnimator?.started == true }
            #expect(navigation.transitionCoordinator?.isInteractive == true)
            let details = UIViewController()
            composition.router.push(details, route: .details, policy: .allowed)
            probe.cancelInteractivePop()
            try await waitForNavigationCondition { probe.popAnimator?.completed == true &&
                composition.router.routes == [.welcome, .secondary, .details] && navigation.transitionCoordinator == nil }
            #expect(navigation.viewControllers[1] === secondary)
            #expect(navigation.topViewController === details)
            composition.router.popTo(.secondary)
            try await waitForNavigationCondition { navigation.transitionCoordinator == nil && composition.router.routes == [.welcome, .secondary] }
        }
    }

    @Test func stopInvalidatesWaitingPushBeforeAlertCleanupCanDrainIt() async throws {
        try await withNavigationWindow { harness in
            let composition = harness.composition
            composition.router.setSceneActive(true)
            composition.router.showAlert(.demo(style: .uikit))
            try await waitForNavigationCondition { AlertPresentation.visibleController(from: composition.rootViewController) is UIAlertController }
            weak var queuedPhone: UIViewController?
            do {
                let phone = UIViewController()
                queuedPhone = phone
                composition.router.push(phone, route: .phone, policy: .blocked)
            }
            composition.coordinator.stop()
            #expect(queuedPhone == nil)
            try await waitForNavigationCondition { !composition.router.hasAlertPresentation }
            #expect(composition.router.routes == [.welcome])
            #expect(!composition.router.backBlocked)
        }
    }
}
