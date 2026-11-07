# Verification record

Executed on 2026-11-07 with Xcode 27.1 (27A9275), Swift 5 language mode, complete concurrency checking, iOS 17 deployment target.

| Check | Actual result |
|---|---|
| `xcodebuild -list` | Passed: app, Swift Testing unit and XCUITest targets; Debug/Release; shared CoordinatorNavigationDemo scheme |
| Native project and Info.plist lint | Passed |
| All Swift/XIB project references | Passed: 23 Swift/XIB files registered |
| XIB XML / connection destination validation | Passed for both XIBs |
| XIB resource compilation | Passed; both `.nib` resources are in Debug Simulator app bundle |
| Debug Simulator `build-for-testing` | **Passed**, app plus both test targets, arm64 and x86_64 |
| Release Simulator `build` | **Passed**, arm64 and x86_64 |
| Portable Swift Testing execution | **Passed: 14 test declarations in 3 suites**, including parameterized cases |
| iOS unit test execution | **Not executed**: destination discovery failed before tests started |
| iOS UI tests A–F execution | **Not executed**: destination discovery failed before tests started |
| App launch / visual review / runtime XIB outlet loading | **Not executed**: no accessible Simulator service |

There are 25 Swift Testing declarations across the complete iOS unit target, plus 9 UI tests after the startup regression changes. The portable package runs 14 of those unit declarations against the same domain/backend/parser/processor sources and test files. It excludes UIKit coordinator/router/XIB tests; those are compiled, not claimed to have run.

## Commands that passed

```sh
cd /path/to/CoordinatorNavigationDemo
plutil -lint CoordinatorNavigationDemo.xcodeproj/project.pbxproj App/Info.plist
xcodebuild -list -project CoordinatorNavigationDemo.xcodeproj
xcodebuild build-for-testing \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/coordinator-demo-build CODE_SIGNING_ALLOWED=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
xcodebuild build -configuration Release \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/coordinator-demo-build CODE_SIGNING_ALLOWED=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
swift test --disable-sandbox -Xswiftc -disable-sandbox
```

The extra compiler flag was supplied only on verification commands because this managed environment rejects the Swift macro compiler's nested `sandbox-exec` invocation (`sandbox_apply: Operation not permitted`). The first build attempt failed on that environment error; retrying with the flag compiled successfully. The project does not persist this workaround, and ordinary local Xcode builds should not need it. The outer workspace restrictions remain in force.

No Swift isolation/compiler warnings remain in the final Debug build. Xcode emits environment CoreSimulator warnings and the routine App Intents metadata warning (the app does not use App Intents). The final Release build also succeeds.

## Simulator execution limitation

`xcrun simctl list devices available` fails with:

```
CoreSimulatorService connection became invalid.
Error Domain=NSPOSIXErrorDomain Code=61 "Connection refused"
Unable to locate device set
```

The runtime volume and device files exist, but this process cannot connect to CoreSimulatorService / simdiskimaged. Separate unit and UI `xcodebuild test-without-building` attempts used device id `SIMULATOR-UDID` and `-destination-timeout 10`; both failed before execution with “Unable to find a device matching the provided destination specifier.” No test assertion failures were observed because the iOS suites never started. No Simulator launch success is claimed.

From a normal local terminal with working Simulator services, use:

```sh
cd /path/to/CoordinatorNavigationDemo
open CoordinatorNavigationDemo.xcodeproj
xcrun simctl list devices available
# Replace DEVICE-UDID with an available device from the preceding command.
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -only-testing:CoordinatorNavigationDemoTests CODE_SIGNING_ALLOWED=NO
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -only-testing:CoordinatorNavigationDemoUITests CODE_SIGNING_ALLOWED=NO
```

## Source review

A separate reviewer checked coordinator lifecycle, XIB hookups, protected Back handling, intent queueing and object ownership. A suspended reset could originally revive a stopped flow; generation checks now prevent that. Reset otherwise commits atomically even when its caller is cancelled, avoiding a stranded busy state. Regression tests are included in the compiled iOS unit suite. Router queue draining uses completed delegate transitions and dispatches the next command after the delegate callback returns. Animated/interactive runtime behavior remains pending Simulator verification.

Full execution logs for this workspace session are in `/private/tmp/coordinator-build.log`, `/private/tmp/coordinator-release-build.log`, `/private/tmp/coordinator-host-tests.log`, `/private/tmp/coordinator-unit-tests.log`, `/private/tmp/coordinator-ui-tests.log` and `/private/tmp/coordinator-project-inspection.log`.

## White-screen regression follow-up (2026-11-07)

The user reported a white screen after launching from Xcode. Inspection found that the debug hosting controller was manually added as a child of `UINavigationController`. That mixes diagnostics containment with UIKit's managed navigation children; it is a startup defect, though the reported white screen could not be reproduced in this sandbox.

The window now installs a regular root container. It embeds the one navigation controller full-window and diagnostics as a separately sized sibling. The navigation controller's children remain exclusively managed by its own stack APIs. Startup is idempotent.

Three new UI tests exercise default launch without launch shortcuts, redeeming through visible controls, authentication/reset actions, and diagnostics while navigating through phone/Home/UIKit. They supplement the six existing workflow tests. A composition test checks containment and repeat startup. Launch assertions require visible, tappable content, rather than merely checking that the process runs.

`xcodebuild build-for-testing` passed after these changes, including the application and both test targets. The new iOS tests have **not executed**. Before/after attempts both failed at Simulator destination discovery because CoreSimulator XPC returns Connection refused. An attempt to use the preapproved Simulator command outside the sandbox was rejected because the execution policy disables sandbox escalation. No permissions or Simulator settings were changed.

Follow-up logs: `/private/tmp/coordinator-navigation-build.log`, `/private/tmp/coordinator-ui-regression-before.log`, `/private/tmp/coordinator-ui-regression-after.log`. The original build/test results above refer to the initial implementation unless explicitly stated otherwise. The runtime containment regression and UI navigation remain to be run in a normal Xcode/Simulator session using Product → Test (Command-U).

## Presented screens extension (2026-11-07)

Implemented a SwiftUI credential sheet (`pageSheet`, medium/large detents) and full-screen UIKit modal using the real lab XIB. Both are exposed on Home and Secondary. The lab can present the sheet, and full-screen actions dismiss before subsequent push/presentation. The XIB content now scrolls so the added controls do not compress labels on short screens.

Modal metadata is separate from the push stack. The router serializes presentation/dismissal, handles interactive dismissal/cancellation, suppresses duplicate presentation and dismisses active modals before stack replacement. Current modal state is observable in diagnostics and in the sheet.

- Final Debug Simulator build-for-testing: **passed**, including both test targets and updated XIB compilation.
- Added four unit tests and six UI presentation tests. Current total: 29 Swift Testing declarations and 15 UI tests.
- Runtime iOS tests: **not executed**. The UI test attempt failed before launch because CoreSimulator could not expose the requested device (Connection refused / no matching destination). The new modal gestures and animations are compiled and source-reviewed, not claimed runtime-verified.
- Source review found no blocking defect; scrollable XIB content and a cancelled-swipe regression test address the noted layout/coverage concerns.
- Logs: `/private/tmp/coordinator-presentation-build.log` and `/private/tmp/coordinator-presentation-ui-tests.log`.

Try it locally: choose Start authenticated, then Present SwiftUI sheet or Present UIKit full screen under Present screens on Home. Use Done, a sheet swipe, or Dismiss full screen to return. Product → Test runs all tests in a normal Simulator session.

## SwiftUI sheet accessibility regression (2026-11-07)

The user's Xcode UI test run on iPhone 17 / iOS 26.5 recorded 39 passing and 5 failing test declarations. All five failures occurred before gesture/dismissal checks, while looking up `dismissSwiftUIModal`:

- `testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation`
- `testSheetSwipeDismissalAllowsPresentingAgain`
- `testSwiftUISheetDismissalPreservesSecondaryAndBack`
- `testUIKitLabPresentsSwiftUISheetWithoutPushing`
- `testUIKitModalCanSwitchToSwiftUISheet`

The failed run's exported accessibility hierarchy proves that the sheet was onscreen: its title, Done button and stack label were present, but all three had identifier `presentedSwiftUIScreen`. The outer VStack's identifier replaced the direct descendants' explicit identifiers. This was an accessibility identification defect, not evidence of failed presentation.

Removed that container identifier while retaining `presentedSwiftUITitle`, `dismissSwiftUIModal` and `modalStack` on their respective controls. Added `testSwiftUISheetControlsKeepDistinctAccessibilityIdentifiers` to check separate identifiers, a hittable Done button and successful dismissal. There are now 16 UI tests. The original five assertions remain in place; waits were not loosened and failures were not suppressed.

Runtime confirmation of the fix remains pending a new Simulator run. Source review confirmed the diagnosis and minimal change. Build and rerun evidence is recorded in `/private/tmp/coordinator-sheet-identifier-build.log` and `/private/tmp/coordinator-sheet-identifier-ui-tests.log` for this local session. The test-result bundle itself and exported UI hierarchy are not published.

Follow-up result: Debug Simulator `build-for-testing` passed after the identifier fix, including the application and both test targets. A rerun against the same iPhone 17 device used by the user's result bundle failed at destination discovery before any test executed: CoreSimulatorService remained inaccessible from this process. No post-fix test pass is claimed. Rerun Product → Test in the working Xcode Simulator session to verify the five original tests plus the new identifier regression.

## Global UIKit / native SwiftUI alerts (2026-11-07)

Implemented a shared main-actor alert queue and two native renderers. Requests wait for scene activation, present over the actual visible content/modal, and hold subsequent navigation until native dismissal finishes. Authenticated deep-link errors use Retry/Cancel from any screen while retaining original session/intent ownership. Reset/disconnect discard stale requests/callbacks. Demo controls and the XIB lab can request either renderer; the error-style picker selects the renderer for deep-link errors. See `docs/GlobalAlerts.md` and the updated README.

Verification for this feature:

- Debug Simulator `build-for-testing`: passed, app and both test targets; Swift 5 language mode / iOS 17 unchanged.
- Portable Swift Testing: **21 tests in 4 suites passed**, including seven new alert-queue tests.
- Native suite now contains 39 unit declarations and 21 UI methods; three new native flow tests cover inactive buffering, Retry preserving session/modal, and reset cancellation. Five new UI methods cover cross-framework presentation, existing feature modals, protected phone, OS deep links and foreground re-entry.
- UI execution attempt: **blocked before any test ran**, CoreSimulator Connection refused / no matching available device. Native SwiftUI alert anchoring and animations are compiled and source-reviewed, not claimed runtime-tested.
- Independent source review found no blocking defect. The background UI test immediately reactivates via OS URL open; it tests background-to-foreground delivery, while pure/unit tests establish inactive queue buffering.
- Logs: `/private/tmp/coordinator-alert-build.log`, `/private/tmp/coordinator-alert-portable-tests.log`, `/private/tmp/coordinator-alert-ui-tests.log`.

No audit-plan refactor, Swift upgrade, deployment-target change or GitHub publication is included in this feature work. The audit reports describe their earlier source snapshot; their line references are historical after this extension.
