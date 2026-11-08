import XCTest

@MainActor final class NavigationUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }
    override func tearDown() async throws {
        if let app { app.terminate() }
        app = nil
        try await super.tearDown()
    }
    private func launch(_ args: [String] = []) {
        app.launchArguments = args
        app.launch()
        XCTAssertEqual(app.state, .runningForeground, "The app must finish launching in the foreground")
    }
    private func assertWelcome(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["Navigation Demo"].waitForExistence(timeout: 10),
                      "Default launch must render Welcome instead of a blank window", file: file, line: line)
        XCTAssertTrue(app.textFields["accessCode"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.textFields["accessCode"].isHittable,
                      "Welcome content must be visible and accept touches", file: file, line: line)
    }
    private func findAndTap(_ id: String) {
        let button = app.buttons[id]
        for _ in 0..<6 {
            if button.exists && button.isHittable { button.tap(); return }
            app.swipeUp()
        }
        XCTFail("Button unavailable: \(id)")
    }
    private func assertPhoneProtected() {
        XCTAssertTrue(app.buttons["skipPhone"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars.buttons["Redeem"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Back"].exists)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)))
        XCTAssertTrue(app.buttons["skipPhone"].exists)
    }
    func testSwipeBackWorksForSwiftUIAndXIBAfterProtectedFlowCompletes() {
        launch(["--link", "NEW-USER"])
        assertPhoneProtected()
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        for (button, title) in [("openSecondary", "Secondary"), ("openUIKit", "UIKit Lab")] {
            findAndTap(button)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
            start.press(forDuration: 0.1, thenDragTo: end)
            XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.navigationBars[title].exists)
        }
        XCTAssertFalse(app.buttons["skipPhone"].exists)
    }
    func testDefaultLaunchAndOnscreenRedeemNavigation() {
        // No launch shortcuts: exercise the same entry point and controls as a person.
        launch()
        assertWelcome()
        findAndTap("injectLink")
        assertPhoneProtected()
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome Library"].exists)
        findAndTap("openSecondary")
        XCTAssertTrue(app.navigationBars["Secondary"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testDefaultLaunchAuthenticationAndResetControls() {
        launch()
        assertWelcome()
        findAndTap("startAuthenticated")
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Starter Library"].exists)
        findAndTap("resetDemo")
        XCTAssertTrue(app.navigationBars["Navigation Demo"].waitForExistence(timeout: 5))
        // Reset installs a fresh root rather than leaving Home behind it.
        XCTAssertEqual(app.navigationBars.buttons.count, 0)
        findAndTap("loginAccount")
        assertPhoneProtected()
        app.buttons["associatePhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Member Library"].exists)
    }
    func testDiagnosticsOverlayLeavesNavigationUsable() {
        launch()
        assertWelcome()
        let toggle = app.buttons["toggleDiagnostics"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["overlayStack"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["overlayStack"].label, "Stack: welcome")
        toggle.tap()
        XCTAssertTrue(app.buttons["injectLink"].isHittable)
        app.buttons["injectLink"].tap()
        assertPhoneProtected()
        toggle.tap()
        XCTAssertEqual(app.staticTexts["overlayStack"].label, "Stack: welcome → redeem → phone")
        toggle.tap()
        XCTAssertTrue(app.buttons["skipPhone"].isHittable)
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertEqual(app.staticTexts["overlayStack"].label, "Stack: home")
        toggle.tap()
        findAndTap("openUIKit")
        XCTAssertTrue(app.buttons["labOpenSwiftUI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["labOpenSwiftUI"].isHittable)
    }
    func testSwiftUISheetControlsKeepDistinctAccessibilityIdentifiers() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentSwiftUI")
        let done = app.buttons["dismissSwiftUIModal"]
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "The sheet container must not overwrite the Done button identifier")
        XCTAssertTrue(done.isHittable)
        XCTAssertEqual(app.staticTexts["presentedSwiftUITitle"].label, "Credential sheet")
        XCTAssertEqual(app.staticTexts["modalStack"].label, "Underlying stack: home")
        XCTAssertFalse(app.buttons["presentedSwiftUIScreen"].exists,
                       "A screen-level identifier must not leak onto descendant controls")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Home"].exists)
    }
    func testSwiftUISheetDismissalPreservesSecondaryAndBack() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("openSecondary")
        XCTAssertTrue(app.navigationBars["Secondary"].waitForExistence(timeout: 5))
        findAndTap("presentSwiftUI")
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["modalStack"].label, "Underlying stack: home → secondary")
        app.buttons["dismissSwiftUIModal"].tap()
        XCTAssertTrue(app.buttons["presentSwiftUI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Secondary"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testSheetSwipeDismissalAllowsPresentingAgain() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentSwiftUI")
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        let sheet = app.buttons["dismissSwiftUIModal"]
        XCTAssertEqual(app.staticTexts["modalStack"].label, "Underlying stack: home")
        // Use UIKit's native drag target. The title belongs to SwiftUI content;
        // dragging from its left-aligned center to screen center was diagonal.
        let grabbers = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Grabber"))
        let grabber = grabbers.firstMatch
        XCTAssertTrue(grabber.waitForExistence(timeout: 5), "The native sheet grabber must be accessible")
        XCTAssertEqual(grabbers.count, 1, "The gesture must target the one presented sheet")
        XCTAssertTrue(grabber.isHittable)
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let distance = app.frame.maxY - grabber.frame.midY - 32
        XCTAssertGreaterThan(distance, 0)
        let end = start.withOffset(CGVector(dx: 0, dy: distance))
        let originalStart = start.screenPoint
        let originalEnd = end.screenPoint
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        guard sheet.waitForNonExistence(timeout: 5) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Sheet after native grabber drag"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let state = XCTAttachment(string: "Start: \(originalStart), end: \(originalEnd), app: \(app.frame), grabber exists: \(grabber.exists), sheet exists: \(sheet.exists)")
            state.name = "Sheet gesture geometry"
            state.lifetime = .keepAlways
            add(state)
            XCTFail("One vertical native-grabber drag must dismiss the sheet before another presentation")
            return
        }
        let home = app.navigationBars["Home"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: home)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                       "Home must be interactive after the native sheet dismisses")
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        app.buttons["dismissUIKitModal"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentSwiftUI")
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        let title = app.staticTexts["presentedSwiftUITitle"]
        let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Gesture smoke coverage: a short drag alone does not prove that an
        // interactive dismissal engaged. Native tests cover the cancellation path.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 30)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].isHittable)
        app.buttons["dismissSwiftUIModal"].tap()
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        app.buttons["dismissUIKitModal"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testUIKitFullScreenDismissesAndCanNavigateToSwiftUI() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Home"].isHittable)
        app.buttons["dismissUIKitModal"].tap()
        XCTAssertTrue(app.buttons["presentUIKit"].waitForExistence(timeout: 5))
        app.buttons["presentUIKit"].tap()
        XCTAssertTrue(app.buttons["labOpenSwiftUI"].waitForExistence(timeout: 5))
        app.buttons["labOpenSwiftUI"].tap()
        XCTAssertTrue(app.navigationBars["Credential Details"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["dismissUIKitModal"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testUIKitModalCanSwitchToSwiftUISheet() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["labPresentSwiftUI"].waitForExistence(timeout: 5))
        app.buttons["labPresentSwiftUI"].tap()
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["modalStack"].label, "Underlying stack: home")
        app.buttons["dismissSwiftUIModal"].tap()
        XCTAssertTrue(app.buttons["presentUIKit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Home"].exists)
    }
    func testUIKitLabPresentsSwiftUISheetWithoutPushing() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("openUIKit")
        XCTAssertTrue(app.buttons["labPresentSwiftUI"].waitForExistence(timeout: 5))
        app.buttons["labPresentSwiftUI"].tap()
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["modalStack"].label, "Underlying stack: home → lab")
        app.buttons["dismissSwiftUIModal"].tap()
        XCTAssertTrue(app.buttons["labPresentSwiftUI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["UIKit Lab"].exists)
    }
    private func acknowledgeAlert(_ title: String, action: String = "OK") {
        let alert = app.alerts[title]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons[action].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
    }
    private func instanceIdentity() -> String {
        app.buttons["toggleDiagnostics"].tap()
        let identity = app.staticTexts["instanceIdentity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        let value = identity.label
        app.buttons["toggleDiagnostics"].tap()
        return value
    }
    private func deliverToExistingApplication(_ link: String) {
        // XCUIApplication.open launches again. System dispatch delivers to the existing scene.
        XCUIDevice.shared.system.open(URL(string: link)!)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
    private func assertLoginRequests(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        let label = app.staticTexts["loginCount"]
        for _ in 0..<6 {
            if label.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(label.label, "Login requests: \(count)", file: file, line: line)
    }
    func testBothNativeAlertStylesFromSwiftUIAndXIB() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("showUIKitAlert"); acknowledgeAlert("UIKit Alert")
        findAndTap("showSwiftUIAlert"); acknowledgeAlert("SwiftUI Alert")
        // Scroll back to the Home navigation actions.
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        findAndTap("openUIKit")
        XCTAssertTrue(app.navigationBars["UIKit Lab"].waitForExistence(timeout: 5))
        findAndTap("showSwiftUIAlert"); acknowledgeAlert("SwiftUI Alert")
        findAndTap("showUIKitAlert"); acknowledgeAlert("UIKit Alert")
        XCTAssertTrue(app.navigationBars["UIKit Lab"].exists)
    }
    func testAlertsAboveSheetAndFullScreenPreserveThem() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("presentSwiftUI")
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5))
        findAndTap("showUIKitAlert"); acknowledgeAlert("UIKit Alert")
        findAndTap("showSwiftUIAlert"); acknowledgeAlert("SwiftUI Alert")
        XCTAssertTrue(app.buttons["dismissSwiftUIModal"].isHittable)
        app.buttons["dismissSwiftUIModal"].tap()
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        findAndTap("showSwiftUIAlert"); acknowledgeAlert("SwiftUI Alert")
        findAndTap("showUIKitAlert"); acknowledgeAlert("UIKit Alert")
        findAndTap("dismissUIKitModal")
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testGlobalAlertOverProtectedPhonePreservesItsBackPolicy() {
        launch(["--link", "NEW-USER"])
        assertPhoneProtected()
        let identity = instanceIdentity()
        deliverToExistingApplication("credentialdemo://unsupported")
        acknowledgeAlert("Unsupported Link")
        XCTAssertEqual(instanceIdentity(), identity)
        assertPhoneProtected()
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testAuthenticatedDeepLinkErrorIsGlobalAndCancelPreservesStack() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let identity = instanceIdentity()
        findAndTap("openDetails")
        XCTAssertTrue(app.navigationBars["Credential Details"].waitForExistence(timeout: 5))
        deliverToExistingApplication("credentialdemo://redeem?code=INVALID")
        acknowledgeAlert("Unable to Redeem", action: "Cancel")
        XCTAssertEqual(instanceIdentity(), identity)
        XCTAssertTrue(app.navigationBars["Credential Details"].exists)
        XCTAssertEqual(app.staticTexts["credentialCount"].label, "Credentials: 1")
    }
    func testBackgroundDeepLinkErrorAppearsAfterForegroundActivation() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let identity = instanceIdentity()
        findAndTap("presentUIKit")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        let background = NSPredicate(format: "state == %d OR state == %d",
            XCUIApplication.State.runningBackground.rawValue,
            XCUIApplication.State.runningBackgroundSuspended.rawValue)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: background, object: app)], timeout: 5), .completed)
        deliverToExistingApplication("credentialdemo://redeem?code=NETWORK-FAIL")
        acknowledgeAlert("Unable to Redeem", action: "Retry")
        XCTAssertTrue(app.buttons["dismissUIKitModal"].waitForExistence(timeout: 5))
        findAndTap("dismissUIKitModal")
        XCTAssertEqual(instanceIdentity(), identity)
        XCTAssertTrue(app.staticTexts["Recovered Library"].waitForExistence(timeout: 5))
    }
    func testColdURLCreatesAccountAndPushesProtectedPhone() {
        app.terminate()
        app.launchArguments = []
        app.open(URL(string: "credentialdemo://redeem?code=NEW-USER")!)
        assertPhoneProtected()
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome Library"].exists)
    }
    func testColdURLWaitsForAuthenticatedSetupBeforeRedemption() {
        app.terminate()
        app.launchArguments = ["--authenticated"]
        app.open(URL(string: "credentialdemo://redeem?code=ADD-CRED")!)
        XCTAssertTrue(app.staticTexts["Premium Library"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["credentialCount"].label, "Credentials: 2")
        assertLoginRequests(0)
        XCTAssertFalse(app.buttons["skipPhone"].exists)
    }
    func testRepeatedAndQueuedOSLinksKeepTheOriginalPhoneFlow() {
        launch(["--link", "NEW-USER"])
        assertPhoneProtected()
        let identity = instanceIdentity()
        deliverToExistingApplication("credentialdemo://redeem?code=NEW-USER")
        deliverToExistingApplication("credentialdemo://redeem?code=ADD-CRED")
        XCTAssertEqual(instanceIdentity(), identity)
        assertPhoneProtected()
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.staticTexts["Premium Library"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["credentialCount"].label, "Credentials: 2")
        assertLoginRequests(1)
    }
    func testIncomingLinkQueuesAboveAnAlertAndAllowsPresentingAgain() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let identity = instanceIdentity()
        findAndTap("showSwiftUIAlert")
        XCTAssertTrue(app.alerts["SwiftUI Alert"].waitForExistence(timeout: 5))
        deliverToExistingApplication("credentialdemo://unsupported")
        acknowledgeAlert("SwiftUI Alert")
        acknowledgeAlert("Unsupported Link")
        XCTAssertEqual(instanceIdentity(), identity)
        findAndTap("showUIKitAlert")
        acknowledgeAlert("UIKit Alert")
        XCTAssertTrue(app.navigationBars["Home"].exists)
    }
    func testAlertCancelDeliversNextErrorAndPreservesNavigation() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let identity = instanceIdentity()
        findAndTap("openSecondary")
        XCTAssertTrue(app.navigationBars["Secondary"].waitForExistence(timeout: 5))
        deliverToExistingApplication("credentialdemo://redeem?code=INVALID")
        let alert = app.alerts["Unable to Redeem"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "invalid")).firstMatch.exists)
        deliverToExistingApplication("credentialdemo://redeem?code=EXPIRED")
        alert.buttons["Cancel"].tap()
        // A same-title alert can replace the first one immediately; distinguish
        // the next business error by content instead of waiting for title absence.
        let expired = app.alerts["Unable to Redeem"].staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "expired")).firstMatch
        XCTAssertTrue(expired.waitForExistence(timeout: 5))
        acknowledgeAlert("Unable to Redeem", action: "Cancel")
        XCTAssertEqual(instanceIdentity(), identity)
        XCTAssertTrue(app.navigationBars["Secondary"].exists)
        app.navigationBars.buttons["Home"].tap()
        findAndTap("openUIKit")
        XCTAssertTrue(app.navigationBars["UIKit Lab"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
    func testA_NewUserSkip() {
        launch(["--link", "NEW-USER"])
        assertPhoneProtected()
        XCTAssertTrue(app.staticTexts["Account created. Phone association is optional."].exists)
        app.buttons["skipPhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome Library"].exists)
    }
    func testB_ExistingAccountAssociate() {
        launch(["--link", "EXISTING-USER"])
        assertPhoneProtected()
        XCTAssertTrue(app.staticTexts["Logged in. Phone association is optional."].exists)
        app.buttons["associatePhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Member Library"].exists)
    }
    func testC_AuthenticatedPreservesSecondary() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("openSecondary")
        XCTAssertTrue(app.navigationBars["Secondary"].waitForExistence(timeout: 5))
        findAndTap("addCredential")
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Premium Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Secondary"].exists)
        XCTAssertFalse(app.buttons["skipPhone"].exists)
        XCTAssertEqual(app.staticTexts["credentialCount"].label, "Credentials: 2")
        for _ in 0..<4 { if app.staticTexts["loginCount"].isHittable { break }; app.swipeUp() }
        XCTAssertEqual(app.staticTexts["loginCount"].label, "Login requests: 0")
        XCTAssertTrue(app.staticTexts["stackDiagnostics"].label.contains("home → secondary"))
    }
    func testD_InvalidCodeRecoverable() {
        launch(["--link", "INVALID"])
        XCTAssertTrue(app.staticTexts["redeemError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["skipPhone"].exists)
        app.buttons["Return"].tap()
        XCTAssertTrue(app.navigationBars["Navigation Demo"].waitForExistence(timeout: 5))
    }
    func testE_MixedNavigationAndNormalBack() {
        launch(["--authenticated"])
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("openUIKit")
        XCTAssertTrue(app.buttons["labOpenSwiftUI"].waitForExistence(timeout: 5))
        app.buttons["labOpenSwiftUI"].tap()
        XCTAssertTrue(app.navigationBars["Credential Details"].waitForExistence(timeout: 5))
        findAndTap("openUIKitDetail")
        XCTAssertTrue(app.navigationBars["UIKit Detail"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Credential Details"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["UIKit Lab"].waitForExistence(timeout: 5))
        app.buttons["labOpenUIKit"].tap()
        XCTAssertTrue(app.navigationBars["UIKit Detail"].waitForExistence(timeout: 5))
    }
    func testF_ProtectedFailureRetryAndBackRestoration() {
        launch(["--link", "NEW-USER"])
        assertPhoneProtected()
        app.switches["phoneFailure"].tap()
        app.buttons["associatePhone"].tap()
        let error = app.staticTexts["phoneError"]
        let failure = expectation(for: NSPredicate(format: "label CONTAINS %@", "simulated request failed"), evaluatedWith: error)
        wait(for: [failure], timeout: 5)
        XCTAssertTrue(app.buttons["skipPhone"].isEnabled)
        app.switches["phoneFailure"].tap()
        app.buttons["associatePhone"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        findAndTap("openSecondary")
        XCTAssertTrue(app.navigationBars["Secondary"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
}
