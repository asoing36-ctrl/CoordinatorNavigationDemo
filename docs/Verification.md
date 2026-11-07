# Verification record

## Current queue / alert policy — user Simulator runs passed (2026-11-07, 22:29 / 22:30)

The user built and ran the AUD-06/AUD-16 revision after baseline `a9b7788`. The full run passed **91 native unit + 27 UI = 118 declarations**, including **8 QueuePolicyTests**, with **136 expanded runs**, zero failures/skips and zero recorded runtime warnings. The portable subset is now **30 declarations**; its shared tests executed natively, but the separate macOS package command was not rerun.

Defaults: 32 ordinary waiting navigation slots plus 2 bounded protected-flow slots; 8 pending business intents plus one active; 8 typed startup/reset staged intents per buffer; 9 waiting alerts with one reserved recovery slot plus one active. Typed rejections report capacity without payloads. Global informational notices survive normal root replacement; flow recovery alerts cancel. Reset/stop cancel all. Pending alerts get a turn after at most 4 non-root commands when presentation is eligible; root/cleanup retain precedence. See [NavigationContract.md](NavigationContract.md) and [the policy plan](plans/queue-and-alert-policy.md).

Independent source review identified a P1 path where ordinary queue saturation could reject Redeem/Phone pushes while business state entered onboarding. The fix reserves two slots for blocked pushes of this demo's single protected flow. **Both saturation parameter cases passed**: before Redeem and after its admission; each reaches the actual protected Phone controller and completes Skip. Accepted ordinary work remains FIFO; explicit flow replacement can still invalidate obsolete work.

Other new tests cover typed admission, deduplication before capacity, reserved recovery alerts, scoped cancellation, batch handoff under reentrancy, alert fairness, visible/inactive root scope handling, reset staging and rejected-recovery termination. The existing long-noop stress case explicitly opts into a larger bounded capacity. Shared startup/reset staging uses validated intents, not raw URL arrays; storage admission is distinct from final processor admission.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.07_22-29-14-+0200.xcresult` | AppAlertQueueTests: **13/13 passed** |
| `Test-CoordinatorNavigationDemo-2026.11.07_22-29-57-+0200.xcresult` | IntentProcessorTests: **6/6 passed** |
| `Test-CoordinatorNavigationDemo-2026.11.07_22-30-14-+0200.xcresult` | QueuePolicyTests: **8/8 declarations**, **10 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.07_22-30-57-+0200.xcresult` | Full suite: **91/91 unit + 27/27 UI passed**, **136 expanded runs passed** |
| Failures / skipped / recorded runtime warnings | **0 / 0 / 0** in all four bundles |

All bundles are under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The full test tree also confirms fairness, both visible scope variants, inactive global delivery after root change, reserved recovery, rejected-recovery termination and bounded reset staging passed.

Console inspection found **0** matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation-transition diagnostics. The UI console has **0** locked-focus/handler diagnostics. Unit console retains **8** locked-focus and **330** `cannot add handler to 0 from 0 - dropping` entries; their cause remains unestablished and they are not recorded runtime warnings. No leak, harmlessness or production-defect conclusion is inferred.

The agent only inspected completed results and updated documentation; it ran no compiler, build, tests, Simulator or app. No production/test source changed after inspection. The user requested committing this verified policy revision with its evidence. Other consuming-flow reservations/capacity tuning, actual OS scene teardown/native sheet gestures, minimum-iOS/physical-device, Release and long-session profiling gates remain separate.

## Earlier lifecycle follow-up — user Simulator runs passed (2026-11-07, 21:32 / 21:34 / 21:35)

The navigation hardening and prior review/docs were committed as `9cddb39`. The subsequent follow-up adds **5 native declarations** (including three disconnect parameter cases) and **1 UI method**. The user's full rerun passed **76 unit + 27 UI = 103 declarations**, with **119 expanded runs**, zero failures/skips and zero recorded runtime warnings. The 97-declaration/111-expanded result below is the earlier committed baseline.

`NavigationReliabilityTests` covers a real UIKit interactive dismissal with test-only adaptive callback forwarding, separate SceneDelegate disconnect callbacks during push/modal/alert transitions, weak ownership release, and observer/rejection reentrancy. `testAlertCancelDeliversNextErrorAndPreservesNavigation` adds native UI action → next error → usable original navigation. The scene test invokes the public callback on a separate delegate/window; it does not destroy the host OS scene. The custom presentation test does not synthesize the native sheet pan recognizer. Those OS/device checks remain release gates.

The only production change extracts shared `SceneDelegate.connect(window:initialURLs:authenticated:)`; the actual OS callback still supplies decoded URLs and initial configuration. Router and business behavior are unchanged. Test helpers belong only to the native target. The user built and ran the cases in Xcode; the agent inspected completed artifacts without initiating compilers, builds, Simulator or tests. See [the follow-up plan](plans/navigation-validation-follow-up.md).

| User-run bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.07_21-32-38-+0200.xcresult` | NavigationReliabilityTests: **5/5 declarations**, **7 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.07_21-34-18-+0200.xcresult` | Focused UI: **1/1 method passed** |
| `Test-CoordinatorNavigationDemo-2026.11.07_21-35-14-+0200.xcresult` | Full suite: **76/76 unit + 27/27 UI passed**, **119 expanded runs passed** |
| Failures / skipped / recorded runtime warnings | **0 / 0 / 0** in all three bundles |

The full test tree confirms the controlled cancellation case, both observer cases, rejection recovery, all three disconnect variants (push/modal/alert), and the new alert-action UI case passed. All bundles are in `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. Destination: iPhone 17 / iOS 27.0 Simulator, arm64.

Independent source review identified two test-support issues, addressed in one source fix pass before the user's runs: restore the rejection callback to break its router capture, and reset per-dismissal interaction state so ordinary dismissal does not receive an extra adaptive completion. The passing cancellation case asserts zero forwarded adaptive didDismiss callbacks after cancel plus ordinary dismissal. The disconnect cases' weak-release assertions also passed on this destination.

Latest console inspection found **0** matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation-transition diagnostics. The UI console also has **0** locked-focus/handler diagnostics. The native unit console retains **8** locked-focus and **270** `cannot add handler to 0 from 0 - dropping` entries, without recorded runtime warnings. Their cause is unestablished; no leak, harmlessness or production-defect conclusion is inferred.

Only documentation changed after result inspection. The verified follow-up and this evidence are committed together at the user's request. Actual OS-driven scene teardown, native sheet-pan delivery, iOS 17/current supported physical devices, Release and long-session profiling remain separate validation; the passed controlled tests do not replace them.

## Earlier committed navigation baseline — user Simulator runs passed (2026-11-07, 20:50 / 20:52)

The user prioritized the reusable navigation layer for a large production project. This revision adds guarded controller ownership/reuse and replacement validation, typed rejection reporting, an iterative non-reentrant queue, duplicate-push coalescing, independent stack/modal completion gates, scene eligibility, hidden-stack updates and completed-transition Back reconciliation. Coordinator changes are limited to clearing pending navigation at reset/stop; backend/account behavior is unchanged.

The user's complete rerun passed **71 native unit declarations + 26 UI methods = 97 declarations**, including **22 RouterLifecycleTests** and the real SwiftUI/XIB edge-swipe UI case. Expanded parameter runs: **111 passed**, with no failures or skips. The older 74-pass result below belongs to commit 5bb132a.

The user built and ran the tests in Xcode. The agent inspected completed result bundles without initiating builds or tests. Independent source review corrected a test-probe lifecycle issue and clarified inactive replacement when modal cleanup is required. See [NavigationContract.md](NavigationContract.md) and [the scoped plan](plans/navigation-reliability.md) for behavior and release gates.

| User-run bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.07_20-50-55-+0200.xcresult` | Targeted router suite: **22/22 declarations passed**, **24 expanded runs passed**, no failures/skips |
| `Test-CoordinatorNavigationDemo-2026.11.07_20-52-23-+0200.xcresult` | Full suite: **71/71 unit + 26/26 UI passed**, **111 expanded runs passed**, no failures/skips |
| Recorded runtime warnings | **0** in both bundles |
| Previously failing root-replacement and protected-Back tests | Both passed in the full rerun |
| Immediate push after new/reused visible roots | Both parameter cases passed |
| SwiftUI/XIB swipe Back after protected flow completion | Passed |

Both bundles are under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. No production source changed after these results were inspected; only documentation was updated.

Console inspection found zero matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation-transition diagnostics. The UI console also has zero locked-focus/handler diagnostics. The native unit console still contains **8** `Locked environment ... was deallocated` entries and **232** `cannot add handler to 0 from 0 - dropping` entries. They are not recorded runtime warnings; their cause remains unestablished. No leak, harmlessness or production-defect conclusion is inferred from these messages.

This validates the patched navigation behavior on the stated Simulator destination. Cross-OS/device testing, real gesture repetition, long-session profiling and application-specific backlog/route policies remain required before production sign-off. No separate iOS 17 runtime/device run, Release build or supplemental macOS package rerun is claimed for this revision.

An independent [strict navigation review](audits/navigation-strict-review-2026-11-07.md) subsequently found no confirmed correctness blocker in the supported integration contract. It identified an unproved sheet-cancellation interaction and additional coverage limits. This read-only source review did not execute anything or add test coverage; the original audit's remaining tasks are tracked in [implementation-status.md](audits/implementation-status.md).

### Earlier failing router run and sequencing follow-up (2026-11-07, 19:29)

Inspected `Test-CoordinatorNavigationDemo-2026.11.07_19-29-58-+0200.xcresult` in the same DerivedData directory: **19/21 declarations passed, 2 failed**; expanded argument cases: **20 passed, 2 failed**. Destination: iPhone 17 / iOS 27.0 Simulator. No recorded runtime warnings. This run selected only RouterLifecycleTests; the remaining unit/UI suites were not executed in this bundle.

- `inactiveRootReplacementDropsObsoleteWaitingRoutes()` timed out at original line 60, after an immediate push following root replacement.
- `protectedBackIsBlockedAndReplacementRestoresOrdinaryBack()` timed out at original line 261, after root replacement and the following push. Initial protected Back assertions completed successfully.

The generic timeout did not record the actual routes or native transition state. The exported console has repeated UIKit `cannot add handler to 0 from 0 - dropping` diagnostics, without a causal explanation or an unbalanced-navigation message. No console-diagnostic cause is inferred.

Source investigation identified a sequencing gap: visible nonanimated replacement did not acquire the navigation transition gate, and deferring the scheduled didShow drain did not prevent a caller from immediately starting a new push. The follow-up tracks visible nonanimated display completion and blocks every queue entry point until the callback/replacement turn returns. Reusing the same top does not depend on receiving another didShow. Added a parameterized native regression (new root / reused root) and safe timeout diagnostics containing routes, transition presence, Back policy and rejection reasons. Existing timeout budgets and assertions were not relaxed.

**Follow-up resolution:** the user's targeted and full reruns above passed both original failing tests and both new regression parameter cases. The agent did not run builds/tests or relax the existing timeout budgets/assertions.

## Earlier alert baseline — user Simulator run passed (2026-11-07, 16:59)

The user built and ran the complete suite for baseline commit 5bb132a in Xcode. The agent inspected the completed bundle without running builds/tests:

`Test-CoordinatorNavigationDemo-2026.11.07_16-59-02-+0200.xcresult`

Location: `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. Destination: iPhone 17 / iOS 27.0 Simulator, arm64.

| Check | Actual result |
|---|---|
| Native Swift Testing | **49/49 declarations passed** |
| XCUITest | **25/25 methods passed** |
| Complete suite | **74 passed, 0 failed, 0 skipped**; **86 expanded parameter runs passed** |
| xcresult recorded runtime warnings | **0** |
| Console: unsupported hosting-view insertion | **0 matching lines** |
| Console: publication during view updates | **0 matching lines** |
| Previously failing native lifecycle cases | Passed, including both queued-navigation styles and SwiftUI containment |
| Previously failing warm/background URL cases | Passed, alongside cold startup and queued/repeated delivery |

The source changes validated by this user run include local State for SwiftUI's dismissal binding and native-window appearance/cleanup synchronization. No production source changed after this result was inspected; only verification documentation was refreshed. The agent did not initiate any build or test run.

**Remaining console diagnostic:** eight distinct UIKit `Locked environment ... was deallocated after being locked` entries remain across four native window-fixture methods. They are absent from the UI-test console and are not recorded in xcresult's runtimeWarnings. Their cause is not established; do not equate an all-green result with a completely silent console or a memory-profile pass. Keep this as a focused native test-window/focus lifecycle investigation; no production retain cycle or observed app navigation failure is inferred.

Swift 5 language mode / iOS 17 deployment settings remain unchanged. This result validates iOS 27.0 Simulator behavior, not a separate iOS 17 device/runtime run. The supplemental macOS Swift-package command was not independently rerun; its shared test declarations executed in the native target.

All entries below are historical and predate this current result.


## Earlier reliability run and follow-up (2026-11-07, 16:34)

The user ran the revised app and complete suites in Xcode. Result bundle: `Test-CoordinatorNavigationDemo-2026.11.07_16-34-51-+0200.xcresult`, in the project's DerivedData `Logs/Test` directory, on iPhone 17 / iOS 27.0.

- **72 passed / 2 failed** of 74 declarations; expanded parameter runs: **83 passed / 3 failed**.
- **All 25 UI methods passed**, including warm/background error recovery, authenticated cold setup, queued URLs and repeated alert presentation. The earlier two deep-link UI failures passed.
- Two native unit declarations failed (three parameter cases): `swiftUIAlertDoesNotAddChildrenToTheUnderlyingHostingController` and `cancellationReleasesQueuedNavigationWithoutInvokingTheAction` for both styles. Every failure pointed to the same generic wait helper, obscuring which wait failed.
- The unsupported hosting-view containment warning is absent from this result. Three publication-during-update warnings remain, each immediately after tapping OK on a SwiftUI alert, in the modal, mixed-framework and queued-alert UI cases.

Follow-up changes after reading this result:

- SwiftUI's dismissal binding is now local `@State`. The observable model signals readiness only; native dismissal no longer writes directly to `@Published` during SwiftUI's update.
- The native test harness now installs content before showing its window (matching SceneDelegate) and awaits an actual viewDidAppear signal. Previously, the three failing cases presented immediately after creating a window, unlike successful cases with intervening feature navigation. This is a source-supported setup concern; confirmation awaits rerun.
- Async teardown awaits renderer/transition cleanup and modal dismissal before releasing the test window. Assertions can observe a derived router `hasAlertPresentation` value rather than infer completion from view disappearance.
- Wait helpers preserve their caller's SourceLocation so a future failure identifies the actual setup/appearance/dismissal/navigation wait.

**No builds or tests were run by the agent. These follow-up changes have not been built or executed.** Source inventory remains 49 native unit declarations and 25 UI methods; portable subset 23 declarations. See [GlobalAlerts.md](GlobalAlerts.md) for commands and result-path guidance. The original 58/2 audit baseline and the user's newer 72/2 run both predate the latest follow-up and are not current green results.

The following entries are historical execution records.


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
