# Verification record

## Current timed-notice revision — unit and corrected UI suites passed in separate user runs (2026-11-08)

The latest completed user bundle confirms **all 37 UI tests passed**, including
all six recovery workflows and the four new timed/manual-notice workflows. The
preceding full run passed **all 131 unit declarations / 231 expanded cases**.
After that run, only the recovery UI helper and documentation changed; production
and unit-test source is unchanged. Coverage across these separate runs is **168
declarations / 268 expanded cases**. **No single post-correction full-scheme run
is claimed.**

| User-owned bundle | Actual evidence |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_21-12-06-+0200.xcresult` | NoticeTimerTests: **8/8 declarations / 10 expanded cases passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_21-13-14-+0200.xcresult` | TransientNoticeTests: **8/8 declarations / 17 expanded cases passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_21-14-20-+0200.xcresult` | Full scheme before the UI-helper correction: **131/131 unit passed**; UI **33 passed / 4 failed of 37** |
| `Test-CoordinatorNavigationDemo-2026.11.08_21-46-44-+0200.xcresult` | Corrected UI suite: **37/37 methods passed**, zero failures/skips/recorded runtime warnings |

All bundles are under
`~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`.
Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The full result tree confirms
all four earlier failed recovery methods passed after the test-only visible-row /
coordinate-center correction. The user built and executed the native tests; the
agent inspected completed result bundles and static source/configuration checks.
Console diagnostics were not analyzed in this follow-up.

Validated behavior includes both modal renderers, automatic and explicit dismissal,
foreground remaining-time pause/resume, obsolete-timer/action suppression, bounded
snackbar FIFO/deduplication, non-key/touch-through window ownership, navigation and
feature-modal preservation, protected Phone completion, and reset/stop cleanup.
The recovery correction does not change production navigation or weaken assertions.

Documentation, source and test corrections are included together at the user's
request to commit and merge locally into main. The intended merge is a fast-forward
of the same source tree; no additional runtime execution or remote push is claimed.
Actual OS suspension, native-button auto-dismissal/reset overlap, minimum/current
OS, physical-device, VoiceOver, keyboard/rotation and long-session/gesture profiling
remain separate release gates. Earlier failure and environment records below are
historical and retained for traceability.

## Earlier timed-notice runs — four recovery tap failures before the passing UI rerun (2026-11-08, 21:12 / 21:13 / 21:14)

Inspected completed user-owned bundles on iPhone 17 / iOS 27.0 Simulator, arm64:

| Bundle | Actual result before the tap-helper correction |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_21-12-06-+0200.xcresult` | NoticeTimerTests: **8 declarations / 10 expanded cases passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_21-13-14-+0200.xcresult` | TransientNoticeTests: **8 declarations / 17 expanded cases passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_21-14-20-+0200.xcresult` | Full scheme: **164 passed / 4 failed of 168 declarations**, **264 passed / 4 failed of 268 expanded runs** |
| Native unit tests in full run | **131/131 declarations / 231 expanded cases passed** |
| UI in full run | **33 passed / 4 failed of 37 methods**; all four new timed/snackbar UI methods passed |
| Skipped / recorded runtime warnings | **0 / 0** in all three bundles; console diagnostics not analyzed in this follow-up |

Bundles are under
`~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`.
These results establish native compilation and execution in the user's environment,
including both renderers, manual/expiry races, remaining foreground time,
non-key/touch-through snackbar windows, queue bounds and protected Phone flow.
The full revision is not yet all green.

The four failures are existing recovery methods (original failure line 471):
`testRecoveryFromHomeWithUIKitInvalidAlert`,
`testRecoveryFromDetailsWithUIKitNetworkRetry`,
`testRecoveryAboveSwiftUISheetWithUIKitExpiredAlert`, and
`testRecoveryAboveUIKitFullScreenWithSwiftUINetworkRetry`.
All reached the final attempt to present a new sheet, after their recovery,
credentials/permissions, session/login, app identity and stack assertions passed.
The other two recovery workflows passed.

Exported synthesized final touch-down coordinates:

| Workflow | Actual tap (x, y) |
|---|---|
| Home / INVALID | (17.0, 55.67) |
| Details / NETWORK-FAIL | (17.0, 56.33) |
| Sheet / EXPIRED | (53.0, 58.47) |
| Full screen / NETWORK-FAIL | (17.0, 57.0) |

All are in status-bar chrome, despite the helper accepting `isHittable`. The Home
failure's final hierarchy shows `presentSwiftUI` at `{16, 688, 370, 52}`, Home
still present and no sheet. The intended button tap was not delivered. Exported
artifacts are in `/private/tmp/coordinator-notices-home-2114` and the corresponding
`coordinator-notices-{details,sheet,fullScreen}-events-2114` directories.

A narrow **test-only** correction replaces that final scroll/tap with
`tapFullyVisibleHomeButton`: require the entire row inside content bounds below
navigation chrome and above bottom diagnostics, scroll in the needed direction,
then send one real coordinate tap at its measured center. A safe geometry attachment
is retained on failure. Existing sheet-appearance/dismissal assertions, five-second
timeout, six-iteration scroll bound and business assertions are unchanged. There
is no retry tap, fallback dismissal or production navigation change.

The corrected UI source passed standalone Swift 5 / iOS 17 SDK typechecking with
complete concurrency and the Xcode XCTest Swift overlay import path (exit 0, no
diagnostics). This is not UI execution or a full app build. The first exploratory
command omitted that overlay path and could not resolve XCTest assertions; adding
Xcode's Developer/usr/lib include path corrected the command, not production code.
The helper change **has not run** in Simulator. The user retains test execution.

Rerun all six `NavigationUITests.testRecovery…` methods, then the complete scheme.
Commands below can be used with the corresponding test filters. No full passing
claim or commit is made for this correction; OS/device/accessibility gates remain.

## Initial timed/manual notice implementation — before user native execution

Branch `feat/timed-alerts-snackbars`, baseline `e07e6f5`. The user confirmed timed
and user-dismissed notices and will run remaining tests. No new native build,
Simulator or UI execution is claimed. Last full native evidence remains **148
declarations / 237 expanded runs** below, before this feature.

| Check | Actual result / limitation |
|---|---|
| Initial portable RED | Failed at missing NoticeClock, before timer/request implementation; `/private/tmp/coordinator-timed-notices-red.log` |
| Initial portable GREEN | **38 declarations across 5 suites passed**, exit 0; includes all 8 NoticeTimerTests declarations (10 expanded cases); `/private/tmp/coordinator-timed-notices-green.log` |
| Partial UIKit source typecheck | AppAlert.swift, ForegroundNoticeTimer.swift and SnackbarPresenter.swift passed arm64 iOS 17 Simulator SDK typechecking, Swift 5 / complete concurrency, no diagnostics; `/private/tmp/coordinator-notices-uikit-typecheck.log` |
| Native app, attached-window and UI execution | Not run for this feature; user will execute |

The source typecheck is **not an application build** and excludes the SwiftUI
renderer, router integration and test targets. It caught and corrected the Swift
name of UIWindow.canBecomeKey and UIKit cleanup isolation before this handoff.
The portable GREEN predates the later native/UI integration. No full green claim
is made for the working tree. Source inventory: **131 unit + 37 UI = 168
declarations**, expected **268 expanded runs**; these are inventory counts.

New coverage: NoticeTimerTests (8 declarations / 10 cases), TransientNoticeTests
(8 declarations / 17 cases), four UI workflows. The native cases use the real
router, renderers, XIB controllers, scene window and injected monotonic clock.
They cover timer start after appearance, foreground remaining time, manual/expiry
races, no synthesized business action, feature modal/stack preservation, non-key
touch passthrough, bounded FIFO/deduplication, reset/stop and protected Phone.

Run NoticeTimerTests and TransientNoticeTests first, followed by the four new UI
methods and the full scheme. For a terminal run, replace DEVICE-UDID and choose
result paths that do not exist:

```sh
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -only-testing:CoordinatorNavigationDemoTests/NoticeTimerTests \
  -only-testing:CoordinatorNavigationDemoTests/TransientNoticeTests \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testTimedAlertsFromSwiftUIAndXIBReleaseNavigation \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testPersistentSnackbarAllowsBackAndUIKitModal \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testTimedSnackbarExpiresAboveSwiftUISheetWithoutDismissingIt \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testTimedAlertAboveUIKitModalPreservesModalAndNextPush \
  -resultBundlePath /private/tmp/CoordinatorTimedNotices.xcresult \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/CoordinatorTimedNoticesFull.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

See [TimedNotices.md](TimedNotices.md) for request examples, four-second demo
controls, lifetime, scope/admission rules and user-action versus expiry semantics.
Static project/plist/XIB/source-membership and Markdown/whitespace checks passed;
41 Swift/XIB references resolve and both XIBs' outlets/actions match controller
symbols. One fresh-context source reviewer found no Critical/Important issue.
The optional appearance-flag change was deferred pending real hide/show evidence;
see [the plan/review ledger](plans/timed-notices.md).

Minimum/current OS, physical-device, VoiceOver, keyboard/rotation and real OS
suspension tests remain separate validation gates. No changes were committed.

## Verified AUD-04 baseline — focused and full user runs passed (2026-11-08, 20:00 / 20:02 / 20:18)

Inspected three completed user-owned Xcode result bundles. The corrected picker
selection assertion and held-metrics native readiness predicate passed focused
runs and the complete scheme. **115 unit + 33 UI = 148 declarations passed**,
with **237 expanded runs**, zero failures/skips/recorded runtime warnings.
Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The user built and executed
these runs; the agent read the results and updated documentation.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_20-00-28-+0200.xcresult` | DiagnosticsIsolationTests: **6/6 declarations / 8 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_20-02-21-+0200.xcresult` | NavigationUITests: **33/33 UI methods passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_20-18-38-+0200.xcresult` | Full scheme: **115/115 unit + 33/33 UI passed; 237 expanded runs passed** |
| Failures / skipped / recorded runtime warnings | **0 / 0 / 0** in all three bundles |

All bundles are under
`~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`.
The full test tree confirms both metrics parameters, all six `testRecovery…` UI
methods and all 58 new recovery unit/component cases passed. All seven failures
from the earlier 19:38 run are resolved on this destination. The source has not
changed since the passing run; this follow-up changes documentation only.

AUD-04's implemented matrix is verified for this Simulator: exact controller,
feature modal, Home owner, original session and data preservation; all three
error families and both styles at the coordinator/queue boundary; repeated Retry
failures and eventual success/Cancel; distinct queued work; real renderer cleanup
above each destination; inactive response delivery; typed selection→stop/reset;
and six representative OS URL/native-button workflows with later navigation.
No production behavior change was needed for the two test-assumption corrections.

This is bounded acceptance evidence. The exhaustive 36-case cross-product uses
RouterSpy and the real business/alert queue; attached-window cases use real
renderers; UI workflows are representative. Actual OS suspension, native-button
auto-dismissal/reset overlap, iOS 17/current supported OS and physical-device
coverage remain separate AUD-14/release gates. No long-session, repeated-gesture
or console-cleanliness claim is made. The agent's earlier environment-blocked
attempts remain historical evidence below. Its separate portable run passed 30
tests across four suites; that target excludes native navigation tests.

Implementation, test corrections and verification documentation are included
together on `test/error-recovery-matrix` at the user's request. Merge and push
are outside this change.

## Earlier AUD-04 full run — seven failures before the passing correction runs (2026-11-08, 19:38)

Inspected the completed user-owned bundle
`Test-CoordinatorNavigationDemo-2026.11.08_19-38-01-+0200.xcresult` in
`~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`.
The entire scheme ran on iPhone 17 / iOS 27.0 Simulator, arm64. Result:
**141 passed / 7 failed of 148 declarations**, **230 passed / 7 failed of 237
expanded runs**, zero skips and zero recorded runtime warnings. Console diagnostics
were not analyzed in this follow-up; recorded runtime warnings do not establish
console cleanliness.

| Scope | Actual result before corrections |
|---|---|
| Native unit tests | 114 passed / 1 failed of 115 declarations; 203 passed / 1 failed of 204 expanded runs |
| ErrorRecoveryFlowTests | Both declarations / all 40 expanded cases passed |
| ErrorRecoveryPresentationTests | All 3 declarations / 18 expanded cases passed |
| UI tests | 27 passed / 6 failed of 33 methods |

All **58 new unit/component cases passed**. This includes exact original
stack/modal/session/data identity, repeated failures and queued work, both real
renderers, inactive response delivery and typed selection→stop/reset. It does not
establish the six new UI workflows: every one failed before OS URL delivery.

Two test assumptions explain the seven reported failures:

1. All six `NavigationUITests.testRecovery…` methods fail in the shared helper at
   the picker assertion: accessibility `value` is `""`, not `"1"`. It is not the
   selection-state API. Changed the helper to wait for the selected segment's
   public `isSelected` state using a bounded predicate expectation. No arbitrary
   delay, timeout increase or dropped selection assertion.
2. `DiagnosticsIsolationTests.heldMetricsCannotDelayProtectedCompletionOrAuthenticatedNavigation`
   fails only for `authenticated: false`: the actual top is Redeem's hosting
   controller at the Phone assertion. Business `.phoneAssociation` is set before
   Phone's push; a nil transition coordinator can occur between serial pushes
   while the router reserves its next main-queue drain. The old readiness predicate
   accepted that intermediate state. It now requires the intended complete routes,
   actual Phone controller, blocked Back and attached native view, as well as the
   existing flow/transition check. The metrics gate remains closed throughout.

Only test code was changed for these failures. Post-correction native execution
was attempted, but **exit 70 before testing** again: CoreSimulatorService was
unavailable to this session. Log: `/private/tmp/coordinator-aud04-corrections.log`;
invocation result: `/private/tmp/CoordinatorAUD04-Corrections-20261108.xcresult`.
**The corrections are not yet runtime verified.** The user's earlier run does
prove the new source compiled in their Xcode environment; it does not prove these
subsequent test edits compile or pass. Static whitespace/source/document checks
are separate from runtime evidence.

Rerun DiagnosticsIsolationTests and the six recovery UI methods first, then the
full scheme. The focused command below now includes DiagnosticsIsolationTests.
The native-button auto-dismissal/reset overlap, actual OS suspension and wider
OS/device gates remain separate AUD-14 work.

## Earlier agent attempt — portable passed; native execution blocked (2026-11-08, 19:35–19:36)

Branch `test/error-recovery-matrix`, based on `455999c`. Five new Swift Testing
methods describe **58 expanded cases**: 36 error/destination/style combinations,
4 repeated-failure outcomes, 12 attached-window destination/style combinations,
2 inactive response cases and 4 selected-action stop/reset cases. Six new UI
methods tap actual native Retry/Cancel buttons after OS URL delivery. Source now
contains **115 unit + 33 UI = 148 declarations** (expected **237 expanded runs**).
These are inventory counts, **not executed results**. Last passing evidence remains
110 unit + 27 UI / 173 expanded runs below.

The user explicitly authorized agent-run tests after the earlier execution restriction.
The agent attempted focused native tests, ran the portable suite, and attempted a
separate native build-for-testing with Xcode 27.1 / 27A9275. Actual results:

| Command / scope | Result | Evidence |
|---|---|---|
| `swift test --disable-sandbox --scratch-path /private/tmp/coordinator-aud04-portable` | **Passed: 30 tests across four suites**, exit 0 | `/private/tmp/coordinator-aud04-portable.log` |
| Focused ErrorRecoveryFlowTests, ErrorRecoveryPresentationTests and six recovery UI methods | **Could not start**, exit 70; no Simulator destination available | `/private/tmp/coordinator-aud04-focused.log` |
| `xcodebuild build-for-testing` for generic iOS Simulator | **Build failed**, exit 65; SwiftUI macro process blocked by sandbox | `/private/tmp/coordinator-aud04-build.log` |
| Complete native scheme | Not attempted after the focused run could not resolve a Simulator | Same environment restriction; no test failure is inferred |

CoreSimulator discovery reported connection invalid/refused (NSPOSIXErrorDomain
61), disabled Simulator device support and listed only generic Simulator/device
placeholders. The requested installed iPhone 17 / iOS 27.0 device ID was
`1FDDD658-2A9C-4264-AE10-1E8A2DC00DCF`; no matching live destination was available
in this session. The focused attempt used
`/private/tmp/CoordinatorAUD04-20261108-1936.xcresult`; this is an invocation failure,
not a passing test result bundle.

The generic build reported `sandbox-exec: sandbox_apply: Operation not permitted`
and a malformed SwiftUI macro plugin response for `@State` in
AlertPresentation.swift and DemoViews.swift. These diagnostics do not establish a
source defect. Native compilation and the new 64 expanded unit/component/UI cases
remain unverified. No production code was changed to bypass these restrictions.
The portable target excludes UIKit/navigation test files and does **not** validate
the new AUD-04 matrix.

Static project, XML and source checks are recorded in the
[AUD-04 ledger](plans/error-recovery-matrix.md).
Production behavior and NavigationRouting remain unchanged. The sole production
change exposes internal read access to the router's existing AlertPresentation;
its setter and ownership remain private.

Component tests call the real renderer's typed select boundary. They prove, when
executed, cleanup and coordinator cancellation at that boundary, not a native
auto-dismissal race. UI tests tap actual buttons separately. The inactive case
holds a repository call across explicit router activity changes; actual OS
suspension, device/OS coverage and native-button/reset overlap remain wider
AUD-14 validation gates.

Run these suites in Xcode first: ErrorRecoveryFlowTests,
ErrorRecoveryPresentationTests and the six NavigationUITests methods prefixed
`testRecovery`. Then run the complete shared scheme. Equivalent terminal commands
for the user (replace DEVICE-UDID; choose fresh result paths):

```sh
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -only-testing:CoordinatorNavigationDemoTests/DiagnosticsIsolationTests \
  -only-testing:CoordinatorNavigationDemoTests/ErrorRecoveryFlowTests \
  -only-testing:CoordinatorNavigationDemoTests/ErrorRecoveryPresentationTests \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryFromHomeWithUIKitInvalidAlert \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryFromSecondaryWithSwiftUIExpiredAlert \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryFromDetailsWithUIKitNetworkRetry \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryFromPushedXIBWithSwiftUIInvalidAlert \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryAboveSwiftUISheetWithUIKitExpiredAlert \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testRecoveryAboveUIKitFullScreenWithSwiftUINetworkRetry \
  -resultBundlePath /private/tmp/CoordinatorErrorRecovery.xcresult \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/CoordinatorErrorRecoveryFull.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Current ownership/state simplification — user focused/full runs passed (2026-11-08, 15:00 / 15:02 / 15:05)

The user built and ran AUD-07–09 on `refactor/navigation-simplification`, based on merged/pushed `de12aab`. **110 native unit + 27 UI = 137 declarations passed**, with **173 expanded runs**, zero failures/skips and zero recorded runtime warnings. Focused SimplificationTests passed 5 declarations / 13 expanded runs; DiagnosticsIsolationTests passed 6 declarations / 8 expanded runs. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The agent only inspected completed artifacts and ran no compiler, build, tests, Simulator or app.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_15-00-21-+0200.xcresult` | SimplificationTests: **5/5 declarations / 13 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_15-02-25-+0200.xcresult` | DiagnosticsIsolationTests: **6/6 declarations / 8 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_15-05-33-+0200.xcresult` | Full suite: **110/110 unit + 27/27 UI passed**, **173 expanded runs passed** |
| Failures / skipped / recorded runtime warnings | **0 / 0 / 0** in all three bundles |

All bundles are under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. The full tree confirms every new parameter case, existing lifecycle suite and all UI workflows passed. This includes original Home/controller/modal identity, weak child release, held metrics across navigation/reset, cancelled/coalesced refreshes, coherent session-only snapshots, stop during publication, stale callbacks versus the next intent, and a held duplicate Retry with real backend login counts.

Source changes remove the child registry/registry-only UUIDs, make typed properties the sole child owners, and separate a concrete redeem transaction/recovery phase from its optional screen coordinator. Authenticated redemption keeps Home and the native stack/modal, without constructing an invisible RedeemCoordinator. Recovery actions validate their transaction. The router implementation is unchanged.

Navigation diagnostics is one typed read-only snapshot derived from actual owners, with session-only changes observed after Combine assignment. Login metrics is independent DemoModel work, bounded to one read plus one coalesced refresh request. Reset/stop cancel and invalidate it; navigation never awaits it. Existing debug/sheet consumers and cleanup helpers are updated. The current-feature label describes the stack/feature modal, not transient alerts.

New SimplificationTests and DiagnosticsIsolationTests cover weak ownership exits, authenticated success/error identity preservation, obsolete recovery actions versus the next intent, partial-login retry, native navigation/queue/reset while metrics is held, stop during session publication, snapshot coherence, stale metrics and bounded refreshes. These cases were written before their corresponding implementation; the user-owned focused/full executions now provide passing evidence. No agent-owned RED/GREEN cycle is claimed. The portable subset remains 30 declarations and executed through the native target; no separate package rerun is claimed.

Static project/plist/XML/outlet/source-membership checks passed with 36 Swift/XIB references and unchanged Swift 5.0/iOS 17.0 settings. Final review/findings are recorded in [the simplification plan](plans/navigation-simplification.md). Static checks and source review are not compilation/runtime evidence. The read-only review found an authenticated-admission snapshot gap, source-corrected with a settled-observer held test and transaction guard. Retry coverage now holds a logged-in retry before replaying its action, so cancellation timing cannot hide an extra login. Both review follow-ups passed in focused and full user runs.

Keep SimplificationTests, DiagnosticsIsolationTests, LifecycleTimingTests and the complete scheme as regression gates. For a terminal run, replace DEVICE-UDID and use a result path that does not already exist:

```sh
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -only-testing:CoordinatorNavigationDemoTests/SimplificationTests \
  -only-testing:CoordinatorNavigationDemoTests/DiagnosticsIsolationTests \
  -only-testing:CoordinatorNavigationDemoTests/LifecycleTimingTests \
  -resultBundlePath /private/tmp/CoordinatorSimplification.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Remove the three `-only-testing` options and choose a fresh result path for a future full unit/UI run. Full-run console inspection found **16** locked-focus and **478** handler-drop entries in native unit output; UI output has **0** of either. There are **0** matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation diagnostics. Their cause remains unestablished; no harmlessness or leak conclusion is inferred. Exported inspection data: `/private/tmp/coordinator-simplification-1505-diagnostics`. Only documentation changed after inspecting the results. The verified simplification, tests and evidence are committed together at the user's request. Prior OS/device/profiling and broader acceptance gates remain open.

## Last verified lifecycle baseline — user UI/full Simulator runs passed (2026-11-08, 10:32 / 10:42)

The user built and ran the final lifecycle revision and test follow-ups. **99 native unit + 27 UI = 126 declarations passed**, with **152 expanded runs**, zero failures/skips and zero recorded runtime warnings. The separate UI run also passed **27/27 methods**. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The portable subset remains 30 declarations and ran through the native target; no separate package run is claimed.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_10-32-53-+0200.xcresult` | UI suite: **27/27 passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_10-42-30-+0200.xcresult` | Full suite: **99/99 unit + 27/27 UI passed**, **152 expanded runs passed** |
| Failures / skipped / recorded runtime warnings | **0 / 0 / 0** in both bundles |

Both bundles are under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. The full test tree confirms all eight lifecycle declarations, queue retention/release positive control, duplicate burst, completed sheet swipe and cancelled-sheet smoke case passed. The sheet activity trace confirms one native `Sheet Grabber` drag with zero horizontal offset, 419.3-point vertical travel and 750-points/second velocity, followed by interactive Home and a new UIKit modal presentation/dismissal. No retry or Done fallback was introduced.

This validates the selected lifecycle timings: noncooperative late create/login/redeem responses, phone cancellation/reset joining and weak child release, obsolete alert actions, positive selection/selection-then-cancel in both renderers, visible/inactive global notices across phone completion and obsolete seeding versus reconnected startup. The scene fixture invokes a separate delegate; it does not destroy the host's OS scene. The renderer action-boundary case does not synthesize a native button tap; controlled cancellation is not proof that the short sheet smoke drag engaged an interactive transition.

Full-run console inspection: native unit **16** locked-focus / **465** handler-drop entries; UI **0** of either. There are zero matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation diagnostics in those test consoles. The remaining native-fixture diagnostics have no established cause; the green run does not prove harmlessness or absence of leaks. Exported inspection data: `/private/tmp/coordinator-lifecycle-1042-diagnostics`.

The agent read/exported completed results only and ran no compiler, build, tests, Simulator or app. Only documentation changed after result inspection. The verified implementation, tests and evidence are committed together at the user's request. Swift 5 / iOS 17 settings remain unchanged. Actual OS-driven scene destruction, repeated native gesture engagement/cancellation, minimum-iOS/physical-device, Release, consuming-app capacity policy and long-session profiling remain separate gates. See [the lifecycle ledger](plans/lifecycle-timing.md) and [audit status](audits/implementation-status.md).

## Earlier queue follow-up passed; native sheet swipe UI failure (2026-11-08, 10:11 / 10:12)

The user reran the ownership revision. The focused QueuePolicyTests run passed **8/8 declarations / 10 expanded runs**. The full run passed **all 99 unit declarations**, including the queue retention/release positive control, duplicate-burst check and all eight lifecycle declarations. UI result: **26 passed / 1 failed of 27**. Total: **125 passed / 1 failed of 126 declarations**, **151 passed / 1 failed of 152 expanded runs**, zero skips/recorded runtime warnings. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The preceding queue weak-release failure is resolved on this destination.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_10-11-07-+0200.xcresult` | QueuePolicyTests: **8/8 declarations / 10 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_10-12-03-+0200.xcresult` | Full suite: **99/99 unit passed, 26/27 UI passed**; one sheet swipe UI failure |

Both bundles are in the DerivedData test directory listed below. The sole failure is `NavigationUITests.testSheetSwipeDismissalAllowsPresentingAgain()`, original `NavigationUITests.swift:153`: Done remained present after the drag, so the test never attempted its next presentation. The separate cancelled-sheet smoke test and all native router/presentation cases passed.

Failure artifacts: exported activity tree, synthesized event and final accessibility hierarchy in `/private/tmp/coordinator-sheet-1012-attachments`. The 402×874 screen shows the sheet still at its medium detent, native `Sheet Grabber` at approximately `{153, 411, 96, 23}`, and Done still visible. The recorded drag starts on the left-aligned title at `(104.66, 443.03)` and ends at `(201, 856.52)`, default 500 points/second. This is a diagonal content-origin gesture. These artifacts prove it did not dismiss; they do not distinguish a non-engaged pan from a cancelled pan or establish a production router defect. The recording was exported, but offline frame extraction was unavailable; no visual-motion conclusion is claimed.

**Unexecuted UI-test-only follow-up:** wait for the native grabber to exist and be hittable, make one vertical fast drag from its center to above the window's bottom edge, keep the five-second sheet disappearance assertion, require interactive Home, then present/dismiss the UIKit modal. Failure retains a screenshot and safe geometry attachment. No retry gesture, Done fallback, timeout increase or production navigation change. Native-grabber accessibility was verified in this runtime's artifact; minimum-iOS/device behavior remains a separate gate. Static source/config checks do not prove this gesture works.

Rerun the completed and cancelled swipe UI cases, then the full scheme. For a terminal run, replace DEVICE-UDID and choose a fresh result path:

```sh
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testSheetSwipeDismissalAllowsPresentingAgain \
  -only-testing:CoordinatorNavigationDemoUITests/NavigationUITests/testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation \
  -resultBundlePath /private/tmp/CoordinatorSheetGesture.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Full-run console: unit **16** locked-focus / **465** handler-drop entries; UI **0** of either; zero matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation diagnostics. Cause remains unestablished. The agent only inspected/exported existing results and edited this test/documentation; it ran no compiler, build, tests, Simulator or app. Current gesture changes are uncommitted and unexecuted.

## Earlier lifecycle timing run — passed; full suite had one queue lifetime failure (2026-11-08, 09:49 / 09:51)

The user built and ran the working-tree lifecycle revision after baseline `981a91b`. **All 8 LifecycleTimingTests declarations / 16 expanded runs passed**, in both the focused and full runs. The full suite has **125 passed / 1 failed of 126 declarations** (**151 passed / 1 failed of 152 expanded runs**): 98/99 unit declarations and all 27 UI methods passed. No skips or recorded runtime warnings. Destination: iPhone 17 / iOS 27.0 Simulator, arm64. The portable subset remains 30 declarations; shared tests ran natively, with no separate package run. The agent inspected completed artifacts only; it ran no compiler, build, tests, Simulator or app.

| User-owned bundle | Actual result |
|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.08_09-49-47-+0200.xcresult` | LifecycleTimingTests: **8/8 declarations, 16/16 expanded runs passed** |
| `Test-CoordinatorNavigationDemo-2026.11.08_09-51-05-+0200.xcresult` | Full suite: **125 passed / 1 failed**, 126 declarations; **151 passed / 1 failed**, 152 expanded runs |

Both bundles are under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/`. The full test tree confirms every lifecycle parameter case passed, including both renderer/activity variants, positive selection/cancellation, all held business stages and reconnect during held startup.

The single failure is `QueuePolicyTests.fullNavigationQueueRejectsNewestAndStillAdmitsFlowReplacement()`, `QueuePolicyTests.swift:73`: the weak duplicate controller was still non-nil immediately after a lexical do scope. Overflow rejection and the subsequent `[home, secondary]` flow replacement assertions passed; the test completed rather than timing out. The duplicate enqueue path returns before storing or passing that controller to UIKit. This supports a test lifetime-boundary problem; the artifact does not identify the exact runtime retainer or prove a production retain cycle.

**Unexecuted test-only follow-up:** construct queued/duplicate/overflow candidates inside an explicit autoreleasepool, then retain the immediate weak-release assertions. Add a positive control that accepted work survives that boundary and is released by flow replacement. The matching duplicate-burst lifetime test now uses the same explicit construction boundary. No navigation production code, timeout, capacity, rejection or stack assertion was relaxed. These edits came after the failed full run and **have not been built or rerun**. First rerun the two methods below, then the complete scheme:

- `QueuePolicyTests.fullNavigationQueueRejectsNewestAndStillAdmitsFlowReplacement()`
- `RouterLifecycleTests.duplicatePushBurstReleasesRedundantWaitingControllers()`

Exported full-run unit console: **16** locked-focus diagnostics and **462** handler-drop entries; UI console: **0** of either. There were **0** matching unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation diagnostics in those test consoles. Their diagnostic cause remains unestablished; neither harmlessness nor a production leak is inferred. Direct `get log --type console` was unavailable; inspection used `xcresulttool export diagnostics` into `/private/tmp/coordinator-lifecycle-0951-diagnostics`.

The new cases hold real mock operations at explicit stages, including noncooperative responses after cancellation. They cover reset after create/login/grant, stopped late grant, reset joining phone work before environment clearing, stopped phone completion and weak child release, an obsolete captured coordinator alert callback against a new held transaction, selection then cancellation in both renderers, visible/inactive global notices across phone completion, and an obsolete held seed completing before a reconnected scene drains its new startup buffer.

Necessary source changes add constructor injection for credential operations and mock administration, retain/join cancelled onboarding work at reset, expose the renderers' existing typed selection boundary internally, and allow scene connection to consume a constructed composition and return its startup handle. Default composition, system scene callbacks, Swift 5 and iOS 17 remain unchanged. Static plist/project lint, XML parsing and resource/source membership checks passed; these checks do not prove compilation or runtime behavior. See [the plan and review ledger](plans/lifecycle-timing.md).

The final read-only review identified two test-reliability issues before these user runs. The fix waits for queued work and settled native transitions before asserting exact global-notice ownership, and joins retained operations on throwing cleanup paths before releasing the native window lease. Reconnected scene fixtures retain both startup handles. Both renderers exercise a successful selection-only control alongside selection-then-cancel. All eight lifecycle declarations then passed in the user's focused/full runs; the later autoreleasepool follow-up above remains unexecuted.

In Xcode, rerun the two queue lifetime methods above, then Product → Test for the complete scheme. For a local terminal run, replace DEVICE-UDID and choose a result path that does not already exist:

```sh
xcodebuild test -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -only-testing:CoordinatorNavigationDemoTests/QueuePolicyTests/fullNavigationQueueRejectsNewestAndStillAdmitsFlowReplacement \
  -only-testing:CoordinatorNavigationDemoTests/RouterLifecycleTests/duplicatePushBurstReleasesRedundantWaitingControllers \
  -resultBundlePath /private/tmp/CoordinatorQueueLifetime.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Remove both `-only-testing` options and use a fresh result path for the full unit/UI run. These are handoff commands, not executed evidence. Native component selection is not a synthesized button tap, direct scene callback reconnection is not OS scene destruction, and administrative alert cancellation is not a user acknowledgment. Existing UI tests supply native action/gesture coverage. Minimum-iOS, physical-device, real OS teardown, long-session profiling and native-fixture console investigation remain open.

## Last verified queue / alert policy — user Simulator runs passed (2026-11-07, 22:29 / 22:30)

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
