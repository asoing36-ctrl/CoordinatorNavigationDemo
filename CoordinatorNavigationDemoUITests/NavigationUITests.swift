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
        // Drag from the header, outside the sheet's scrolling credential list.
        let start = app.staticTexts["presentedSwiftUITitle"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
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
        // A short, slow drag released below the dismissal threshold cancels the gesture.
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
