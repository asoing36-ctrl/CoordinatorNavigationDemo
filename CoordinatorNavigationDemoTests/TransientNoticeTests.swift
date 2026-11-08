import Testing
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct TransientNoticeTests {
    @Test(arguments: [AppAlertStyle.uikit, .swiftUI], [false, true])
    func timedAlertExpiresWithoutActionAndPreservesFeatureModal(style: AppAlertStyle, modal: Bool) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            await app.reset(authenticated: true)
            app.home?.showSecondary()
            try await waitForNavigationCondition { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            if modal {
                app.home?.presentUIKit()
                try await waitForNavigationCondition { router.presentedRoute == .uikitFullScreen && Self.ready(navigation) }
            }
            let stack = navigation.viewControllers
            let feature = navigation.presentedViewController
            var actions: [AppAlertAction] = []
            #expect(router.showAlert(.timedDemo(style: style)) { actions.append($0) } == .accepted)
            router.showAlert(.demo(style: .uikit)) { actions.append($0) }
            try await Self.waitForAlert("Timed \(style == .uikit ? "UIKit" : "SwiftUI") Alert", navigation: navigation)
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            clock.advance(by: .seconds(4))
            try await Self.waitForAlert("UIKit Alert", navigation: navigation)
            #expect(actions.isEmpty) // Expiry must never synthesize OK or Cancel.
            let next = try #require(router.alertPresentation)
            next.select(.ok)
            try await waitForNavigationCondition { !router.hasAlertPresentation && Self.ready(navigation) }
            #expect(actions == [.ok])
            #expect(navigation.viewControllers == stack && navigation.presentedViewController === feature)
            #expect(router.routes == [.home, .secondary] && app.session.credentials.count == 1)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func inactiveTimeDoesNotExpireAnAlert(style: AppAlertStyle) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let router = harness.composition.router
            router.showAlert(.timedDemo(style: style))
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            clock.advance(by: .seconds(1)); router.setSceneActive(false)
            try await waitForNavigationCondition { clock.waitingCount == 0 }
            clock.advance(by: .seconds(100))
            #expect(router.hasAlertPresentation)
            router.setSceneActive(true)
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            clock.advance(by: .seconds(2)); #expect(router.hasAlertPresentation)
            clock.advance(by: .seconds(1))
            try await waitForNavigationCondition { !router.hasAlertPresentation }
            #expect(router.routes == [.welcome])
        }
    }

    @Test(arguments: [false, true])
    func snackbarAllowsNavigationAndOnlyConsumesBannerTouches(timed: Bool) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            await app.reset(authenticated: true)
            try await waitForNavigationCondition { router.routes == [.home] && Self.ready(navigation) }
            let mainWindow = try #require(navigation.view.window)
            var actions: [AppAlertAction] = []
            router.showAlert(.snackbarDemo(timed: timed)) { actions.append($0) }
            try await waitForNavigationCondition { Self.snackbarIsReady(mainWindow) }
            let overlay = try #require(Self.snackbarWindow(mainWindow))
            #expect(mainWindow.isKeyWindow && !overlay.isKeyWindow && !overlay.canBecomeKey)
            #expect(overlay.hitTest(CGPoint(x: overlay.bounds.midX, y: overlay.bounds.height * 0.25), with: nil) == nil)
            let dismiss = try #require(Self.dismissButton(in: overlay.rootViewController?.view))
            let center = dismiss.convert(CGPoint(x: dismiss.bounds.midX, y: dismiss.bounds.midY), to: overlay)
            #expect(overlay.hitTest(center, with: nil) != nil)
            app.home?.showSecondary()
            try await waitForNavigationCondition { router.routes == [.home, .secondary] && Self.ready(navigation) }
            app.home?.presentSwiftUI()
            try await waitForNavigationCondition { router.presentedRoute == .credentialSheet && Self.ready(navigation) }
            let feature = navigation.presentedViewController
            #expect(!overlay.isHidden && mainWindow.isKeyWindow)
            if timed {
                try await waitForNavigationCondition { clock.waitingCount == 1 }
                clock.advance(by: .seconds(4))
            } else {
                clock.advance(by: .seconds(100))
                #expect(!overlay.isHidden && clock.waitingCount == 0)
                dismiss.sendActions(for: .touchUpInside)
            }
            try await waitForNavigationCondition { overlay.isHidden && overlay.rootViewController == nil }
            #expect(actions == (timed ? [] : [.ok]))
            #expect(navigation.presentedViewController === feature && router.routes == [.home, .secondary])
            app.home?.dismissPresentedScreen()
            router.pop()
            try await waitForNavigationCondition { router.routes == [.home] && navigation.presentedViewController == nil && Self.ready(navigation) }
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func manualAcknowledgementWinsOverReadyExpiryExactlyOnce(style: AppAlertStyle) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let router = harness.composition.router
            var actions: [AppAlertAction] = []
            router.showAlert(.timedDemo(style: style)) { actions.append($0) }
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            let presentation = try #require(router.alertPresentation)
            clock.advance(by: .seconds(4))
            presentation.select(.ok) // Before the ready timer continuation gets its main-actor turn.
            try await waitForNavigationCondition { !router.hasAlertPresentation }
            presentation.select(.ok); clock.advance(by: .seconds(100))
            #expect(actions == [.ok])
            #expect(router.routes == [.welcome])
        }
    }

    @Test func boundedSnackbarQueueDeduplicatesAndDoesNotConsumeModalRecoveryCapacity() async throws {
        try await withNavigationWindow { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let mainWindow = try #require(navigation.view.window)
            var order: [Int] = []
            let active = AppAlertRequest.snackbarDemo(timed: false)
            #expect(router.showAlert(active) { _ in order.append(0) } == .accepted)
            try await waitForNavigationCondition { Self.snackbarIsReady(mainWindow) }
            #expect(router.showAlert(active) { _ in order.append(-1) } == .duplicate)
            for index in 1...4 {
                let request = AppAlertRequest(key: "notice-\(index)", style: .uikit, title: "Notice \(index)", message: "",
                    scope: .global, presentation: .snackbar)
                #expect(router.showAlert(request) { _ in order.append(index) } == .accepted)
            }
            let overflow = AppAlertRequest(key: "overflow", style: .uikit, title: "Overflow", message: "",
                scope: .global, presentation: .snackbar)
            #expect(router.showAlert(overflow) { _ in order.append(-1) } == .capacityExceeded)
            #expect(router.showAlert(.redeemFailure(message: "Recover", style: .uikit)) == .accepted)
            try await Self.waitForAlert("Unable to Redeem", navigation: navigation)
            let presentation = try #require(router.alertPresentation)
            presentation.select(.cancel)
            for title in ["Persistent snackbar", "Notice 1", "Notice 2", "Notice 3", "Notice 4"] {
                try await waitForNavigationCondition {
                    guard let overlay = Self.snackbarWindow(mainWindow) else { return false }
                    return Self.snackbarIsReady(mainWindow) && Self.label(in: overlay.rootViewController?.view)?.text == title
                }
                let overlay = try #require(Self.snackbarWindow(mainWindow))
                let button = try #require(Self.dismissButton(in: overlay.rootViewController?.view))
                button.sendActions(for: .touchUpInside)
            }
            #expect(order == [0, 1, 2, 3, 4])
            #expect(Self.snackbarWindow(mainWindow) == nil && !router.hasAlertPresentation)
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func modalAlertPausesSnackbarThenResumesItsRemainingTime(style: AppAlertStyle) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let mainWindow = try #require(navigation.view.window)
            router.showAlert(.snackbarDemo(timed: true))
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            let overlay = try #require(Self.snackbarWindow(mainWindow))
            clock.advance(by: .seconds(1))
            router.showAlert(.demo(style: style))
            try await Self.waitForAlert(style == .uikit ? "UIKit Alert" : "SwiftUI Alert", navigation: navigation)
            try await waitForNavigationCondition { overlay.isHidden && clock.waitingCount == 0 }
            clock.advance(by: .seconds(100))
            let presentation = try #require(router.alertPresentation)
            presentation.select(.ok)
            try await waitForNavigationCondition { !router.hasAlertPresentation && !overlay.isHidden && clock.waitingCount == 1 }
            clock.advance(by: .seconds(3))
            try await waitForNavigationCondition { overlay.isHidden && overlay.rootViewController == nil }
            #expect(router.routes == [.welcome])
        }
    }

    @Test(arguments: [false, true])
    func resetOrStopCancelsActiveAndQueuedNotices(reset: Bool) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            let mainWindow = try #require(navigation.view.window)
            var actions: [AppAlertAction] = []
            router.showAlert(.snackbarDemo(timed: true)) { actions.append($0) }
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            let overlay = try #require(Self.snackbarWindow(mainWindow))
            router.showAlert(.snackbarDemo(timed: false)) { actions.append($0) }
            router.setSceneActive(false)
            router.showAlert(.timedDemo(style: .swiftUI)) { actions.append($0) }
            if reset { await app.reset(authenticated: false) } else { app.stop() }
            clock.advance(by: .seconds(100))
            router.setSceneActive(true)
            try await waitForNavigationCondition { clock.waitingCount == 0 && overlay.isHidden && overlay.rootViewController == nil }
            #expect(!router.hasAlertPresentation && actions.isEmpty)
            #expect(Self.snackbarWindow(mainWindow) == nil)
            if reset {
                router.showAlert(.snackbarDemo(timed: false))
                try await waitForNavigationCondition { Self.snackbarWindow(mainWindow)?.isHidden == false }
            }
        }
    }

    @Test(arguments: [AppAlertStyle.uikit, .swiftUI])
    func timedNoticePreservesProtectedPhoneAndSnackbarSurvivesCompletion(style: AppAlertStyle) async throws {
        let clock = ManualNoticeClock()
        try await withNavigationWindow(noticeClock: clock) { harness in
            let app = harness.composition.coordinator
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            app.submit(code: "NEW-USER"); await app.waitForOperation()
            try await waitForNavigationCondition { navigation.topViewController is AssociatePhoneViewController && navigation.transitionCoordinator == nil }
            let phone = navigation.topViewController
            let mainWindow = try #require(navigation.view.window)
            router.showAlert(.snackbarDemo(timed: false))
            try await waitForNavigationCondition { Self.snackbarIsReady(mainWindow) }
            let overlay = try #require(Self.snackbarWindow(mainWindow))
            router.showAlert(.timedDemo(style: style))
            try await waitForNavigationCondition { clock.waitingCount == 1 }
            clock.advance(by: .seconds(4))
            try await waitForNavigationCondition { !router.hasAlertPresentation && Self.snackbarIsReady(mainWindow) }
            router.pop(); router.popTo(.welcome)
            #expect(navigation.topViewController === phone && router.backBlocked)
            #expect(app.flow == .phoneAssociation && navigation.interactivePopGestureRecognizer?.isEnabled == false)
            app.onboarding?.skip()
            try await waitForNavigationCondition { router.routes == [.home] && Self.ready(navigation) }
            #expect(!overlay.isHidden && !router.backBlocked)
            app.home?.showSecondary()
            try await waitForNavigationCondition { router.routes == [.home, .secondary] && Self.ready(navigation) }
            router.pop()
            try await waitForNavigationCondition { router.routes == [.home] && Self.ready(navigation) }
            let dismiss = try #require(Self.dismissButton(in: overlay.rootViewController?.view))
            dismiss.sendActions(for: .touchUpInside)
            #expect(overlay.isHidden)
        }
    }

    private static func ready(_ navigation: UINavigationController) -> Bool {
        let visible = AlertPresentation.visibleController(from: navigation)
        return visible.viewIfLoaded?.window != nil && !visible.isBeingPresented && !visible.isBeingDismissed &&
            visible.transitionCoordinator == nil && navigation.transitionCoordinator == nil
    }
    private static func waitForAlert(_ title: String, navigation: UINavigationController) async throws {
        try await waitForNavigationCondition {
            let visible = AlertPresentation.visibleController(from: navigation)
            return (visible as? UIAlertController)?.title == title && ready(navigation)
        }
    }
    private static func snackbarWindow(_ main: UIWindow) -> UIWindow? {
        main.windowScene?.windows.first { $0.rootViewController?.viewIfLoaded?.accessibilityIdentifier == "snackbarOverlay" }
    }
    private static func snackbarIsReady(_ main: UIWindow) -> Bool {
        guard let overlay = snackbarWindow(main), !overlay.isHidden,
              let button = dismissButton(in: overlay.rootViewController?.view) else { return false }
        return button.window === overlay && button.bounds.width > 0
    }
    private static func label(in view: UIView?) -> UILabel? {
        guard let view else { return nil }
        if let label = view as? UILabel, label.accessibilityIdentifier == "snackbarTitle" { return label }
        return view.subviews.lazy.compactMap { label(in: $0) }.first
    }
    private static func dismissButton(in view: UIView?) -> UIButton? {
        guard let view else { return nil }
        if let button = view as? UIButton, button.accessibilityIdentifier == "dismissSnackbar" { return button }
        return view.subviews.lazy.compactMap { dismissButton(in: $0) }.first
    }
}
