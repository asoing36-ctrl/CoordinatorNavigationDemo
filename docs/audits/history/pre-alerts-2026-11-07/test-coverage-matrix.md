# Test coverage and execution matrix

Audit date: 2026-11-07. Baseline is the current working tree, including the pre-audit local sheet-identifier fix. No test or production file was changed during this audit.

## Inventory and execution status

| Suite / check | Current source | Fresh audit execution |
|---|---|---|
| Swift Testing native unit target | 29 declarations: DomainTests 11, IntentProcessorTests 3, ArchitectureTests 15 | Compiled successfully; native execution blocked before launch |
| XCUITest target | 16 test methods | Compiled successfully; execution blocked before launch |
| Supplemental portable package | Same 14 declarations in DomainTests/IntentProcessorTests | **Passed: 14 tests in 3 suites** |
| Parameterized cases | Parser fixture has 7 cases; business error fixture has 3 | Portable result includes these; do not add their case count to declaration totals without labeling it |
| Fresh generic Simulator build-for-testing | App and both test targets | **Passed**, arm64 and x86_64 |
| Project/plist and XIB structural checks | Native PBX/scheme, Info.plist; 2 connected XIBs | Passed lint/structural inspection and compiled resources |
| Additional actual-parser probe | Trailing LF, CRLF, CR, Unicode line separator; lengths 64/65; valid baseline | Expected rejection/acceptance observed in Swift 5 mode; probe is temporary, not a persistent repository test |

There are **45 current test declarations** (29 unit + 16 UI). Parameter expansion adds eight executions if counting every case instead of each parameterized declaration. The portable subset is not validation of UIKit, SessionStore observation, native startup or XIB runtime loading.

### Historical user run, kept separate from the audit

The inspected result bundle `Test-CoordinatorNavigationDemo-2026.11.07_10-01-53-+0200.xcresult` records **39 passed / 5 failed / 44 total declarations** on iPhone 17, iOS 26.5. Its device count reports 47 passing expanded cases plus 5 failures; these two count presentations are consistent once parameter expansion is distinguished. Duration is approximately 235 seconds; no single helper is blamed for that total without per-test measurement.

All five failures occurred at `app.buttons["dismissSwiftUIModal"].waitForExistence(timeout: 5)`:

| Historical test | Reported line in that source version | Meaning of failure |
|---|---:|---|
| `testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation` | 131 | Did not reach cancelled-swipe assertions |
| `testSheetSwipeDismissalAllowsPresentingAgain` | 116 | Did not reach actual dismissal assertions |
| `testSwiftUISheetDismissalPreservesSecondaryAndBack` | 104 | Did not reach stack/Done/Back assertions |
| `testUIKitLabPresentsSwiftUISheetWithoutPushing` | 178 | Did not reach post-presentation assertions |
| `testUIKitModalCanSwitchToSwiftUISheet` | 166 | Did not reach Done/underlying Home assertions |

The exported UI hierarchy shows the sheet, its title, Done and underlying-stack label visibly present, but all had the outer container's identifier `presentedSwiftUIScreen`. The **pre-audit local fix** removes that outer identifier and keeps leaf IDs. The new sixteenth UI method verifies distinct leaf IDs and tappable dismissal. The old result does not contain that new test. No fresh post-fix UI pass is asserted by this audit; the original five are neither ignored nor described as fixed by a build result.

## Reading the matrix

Aliases below expand to exact paths:

- **D:** `CoordinatorNavigationDemoTests/DomainTests.swift`
- **I:** `CoordinatorNavigationDemoTests/IntentProcessorTests.swift`
- **A:** `CoordinatorNavigationDemoTests/ArchitectureTests.swift`
- **UI:** `CoordinatorNavigationDemoUITests/NavigationUITests.swift`

Layers: **pure** = parser/processor; **business** = actual use case + actor backend; **spy** = coordinator requests with RouterSpy; **UIKit** = actual detached router/XIB/composition; **UI** = real launched app when executed. A listed test is coverage by source, not a claim of a fresh runtime pass. Current line numbers reflect the added identifier test; historical failure line numbers above intentionally differ.

## Requirement-to-test coverage

| Required scenario | Existing exact test / lines | Layer and actual assertion | Missing or weaker evidence / plan task |
|---|---|---|---|
| Valid custom URL | D:6 `validCustomAndUniversalLinks` | Pure: typed intent from custom scheme | Full boundary cases in AUD-10 |
| HTTPS placeholder parsing | D:6 same test | Pure: known HTTPS host/path intent | Actual Universal Links remain out of scope without domain/entitlement |
| Invalid/unsupported URL rejection | D:11–13 `rejectsMalformedLinks` (7 cases) | Pure: unsupported scheme/host/path, empty/space/duplicate code rejected | Userinfo/port/fragment/control/separator/length persistent cases missing; AUD-10 |
| Required access code missing | D:15 `missingCode` | Pure: exact missing-code error | Distinguish missing value, empty, malformed and duplicate codes; AUD-10 |
| Real cold-start custom URL | A:14 `coldStartLoginSessionTransitionAndSkip`; UI:200 test A | Spy direct `receive` and Debug launch helper exercise business pipeline | Neither injects OS connection options or openurl into terminated app; AUD-10 |
| Warm-start custom URL | Demo-control UI paths UI:43,57 | Real on-screen pipeline exercised when run | Actual SceneDelegate.openURLContexts delivery not covered; AUD-10 |
| Background-to-foreground URL | No direct test | Source path exists at `App/AppDelegate.swift:43–49` | Add background openurl smoke test; AUD-10 |
| One transaction at a time | I:6 `duplicateSuppressionAndFIFO`; A:41 `duplicatesAndQueueStayProtectedUntilCompletion` | Pure active ownership; spy queued ADD-CRED stays behind phone | No gated backend entry counts or UI queue burst; AUD-02/AUD-06 |
| Concurrent duplicate link suppression | I:6 and A:41 | Active/pending identical intents are suppressed | Verify actual use-case invocation count while suspended, not only final count; AUD-02 |
| Distinct queued intent | I:6, A:41 | FIFO and next ADD-CRED after Skip; final credential count 2 | More than one distinct queued intent, failure/reset/overflow cases; AUD-06 |
| Completed link redelivery | I:30 `finishedIntentMayBeSubmittedAgainForIdempotentRefresh`; D:19 | Processor allows again; backend does not duplicate grants | App/visible data idempotency scenario; AUD-10 |
| Queue during phone retry | A:41 queue through phone, A:56 failure/retry separately | Two useful narrow behaviors | Combine a waiting intent with failed/retried association; AUD-02 |
| Queue/reset cleanup | I:22 `resetDropsPendingAndActive` | Pure queue bookkeeping | URL receipt during held app reset and invalid deferred URLs; AUD-02/AUD-06 |
| New account creation and login | D:19 `newAccountAndIdempotency`; UI:200 test A | Business outcome, eligibility, one login; actual screen/credential UI | Stage-boundary cancellation after create/login; AUD-02 |
| Existing account login while logged out | D:31 `existingAccountLogin`; UI:208 test B | Business loggedIn/eligible/no creation; actual Associate route | App-level error/retry from this path; AUD-10 |
| Session transition after login | A:14, D:19/31 | Authenticated store and phone flow; returned result | Atomic publisher/state observation only if required; AUD-09/AUD-10 |
| Original auth snapshot across retry | D:19 contrasts nil/existing session; D:53 networkRetry | Correct use-case outcomes in separate requests | No coordinator Retry after a staged partial account effect; AUD-02/AUD-08 |
| Already-authenticated grant | D:38 `authenticatedRedeemNeverLogsIn`; A:28; UI:216 test C | Same session result, no login, premium permission, no phone | No actual create/lookup invocation spy; route identity assertion weak; AUD-10 |
| No phone just because credential added | D:38; A:28; UI:216 | Eligibility false, coordinator nil, no phone control | Strong coverage across layers; preserve |
| Credential + permission refresh | D:38; A:28; UI:216 | Backend grants, SessionStore data, visible Premium Library/count | Publisher emission and active-sheet live update missing; AUD-09/AUD-10 |
| Authenticated controller/history preservation | A:28 `authenticatedStackIsPreservedAndUpdatesObserved`; UI:216 | Equal route values and visible Secondary/diagnostics | Could pass after recreation; compare controller identities and navigation requests; AUD-10 |
| INVALID / EXPIRED / ADD-CRED unsupported context | D:47–51 `errorsDoNotAuthenticate` (3 cases) | Business throws DemoError, zero login | Exact error identity/account/credential unchanged assertions stronger; authenticated variants missing; AUD-04/AUD-10 |
| Unauthenticated recoverable invalid UI | A:69 `invalidCodeHasRecoverableError`; UI:232 test D | Spy error/Return; real Return to Welcome | Expired/network Retry UI not covered; AUD-04/AUD-10 |
| Recoverable network retry | D:53 `networkRetry` | Actual use case/actor first throws then succeeds | No visible coordinator Retry button or preserved original context assertion; AUD-02/AUD-10 |
| Authenticated error on any screen/modal | No targeted test | Current error surface only in DemoControls | Confirmed gap F16 on details/lab/modal; AUD-04 |
| Idempotent concurrent backend effects | D:59 `concurrentRedemptionEffectsAreIdempotent` | 10 actual actor grants, final count 2 | Does not prove app only dispatched once; keep separate from intent suppression |
| Cancel redeem before work | D:68 `cancelledRedeemDoesNotAuthenticate` | Cancelled Task and no create/login | Can cancel at check before use case starts; staged gates required, F02 |
| Reset invalidates old app flow | A:105 `resetCancelsObsoleteFlow` | Spy Welcome/no session/children after immediate reset | Backend may never start; force entry then release, AUD-02 |
| Reset caller cancellation | A:79 `callerCancellationDoesNotStrandReset` | Administrative reset finishes, busy clears, subsequent reset works | Useful distinct lifecycle policy; retain |
| Stop during reset cannot revive | A:92 `stoppedCoordinatorCannotBeRevivedByReset` | Busy observer calls stop; reset does not install new child/session | Does not force router animation or queued command, F03/AUD-05 |
| Phone genuinely pushed with lower flow | A:14; UI:200/208; UI:73 diagnostics | Spy exact `[welcome,redeem,phone]`; real diagnostics route | Attached real-router controller types/identities can strengthen, AUD-03 |
| Skip → Home root | A:14; UI:200; UI:43 default-launch path | Spy root/Back reset, actual Home and credential | Useful overlap with startup test: retain one default entry and one focused onboarding UI path |
| Associate → Home root | D:80 `phoneFailureRetryAndSuccess`; A:56; UI:208 | Actual actor counter, spy root, actual XIB Associate workflow | Once-only callbacks and repeated actions while loading not asserted, AUD-02 |
| Phone failure → stay / retry / Skip | D:80; A:56; UI:255 test F | Business error/success; spy phone then Home; visible retry UI | Failure followed by Skip and held-request duplicate submission cases; AUD-02/AUD-10 |
| Bar Back unavailable on phone | UI:35 helper; A:118 `pushDuplicatePopAndProtection` | Bar item absent, UIKit hidesBackButton, router blocked | Add direct popTo/popToRoot checks and engaged gestures, AUD-03 |
| Programmatic Back blocked | A:118 | Real detached router pop/popTo and direct single UIKit pop blocked | Positive popTo and direct UIKit popTo/popToRoot untested, AUD-03 |
| Interactive phone edge pop blocked | UI:35 helper used by A/B/F | Real edge-drag attempt leaves phone control | Could pass if gesture never engages; independent delegate/gesture evidence needed, AUD-03/AUD-10 |
| Normal Back restored afterward | A:118; UI:239/255 | Real detached pop and actual bar Back | No successful ordinary edge swipe after onboarding, AUD-03/AUD-10 |
| Duplicate route push blocked | A:118 | Real nonanimated duplicate route ignored | Duplicate pending animated push not tested, AUD-03 |
| Explicit stack replacement bypasses policy | A:118; A:14 | Real detached root replacement plus spy onboarding | Replacement during ongoing push/modal needs attached tests, AUD-03 |
| Mixed SwiftUI → SwiftUI | UI:43/239 | Actual pushes and Back | Preserve representative path |
| SwiftUI → XIB | UI:239 test E and diagnostics test UI:73 | Actual lab appears and accepts action | Broader layout variants untested |
| XIB → SwiftUI / XIB → XIB | UI:239 | Actual detail/lab-detail and Back | Strong representative integration; retain |
| Real XIB resource/outlet loading | A:139 `xibOutletsAndActionsLoad` | Actual phone Associate/Skip and lab SwiftUI outlets nonnil | Name implies actions more broadly; only full-screen dismiss action sent explicitly in A:214 |
| Once-only XIB dismissal action | A:214 `fullScreenUsesXIBAndHasDismissAction` | Actual nib/button sends action into router spy | Actual animation queue still UI/integration responsibility |
| Root containment / startup idempotence | A:173 `diagnosticsCannotBecomeANavigationChild`; UI:43/57/73 | Actual composition containment; real visible default launch and controls | Keep regression that protects original white-screen defect |
| SwiftUI sheet style/stack identity | A:197 `swiftUISheetPreservesSecondaryAndDismissesThroughRouter`; UI:114 | Spy pageSheet and exact controller identities; UI presentation/Done/Back | Actual detent/interactive queue coverage weak; five old failures prevented later assertions |
| Full-screen XIB modal and dismiss→push | A:214; UI:160 | Actual XIB action to spy; launched full-screen→details→Back | Preserve, add attached dismissal ordering when simplifying router |
| Duplicate modal and modal reset | A:230 `resetRemovesPresentationAndDuplicateDoesNotReplaceIt` | RouterSpy ignores second modal and clears on reset | Mostly spy policy; actual UIKit reset-during-presentation missing, AUD-03 |
| Detached presentation does not stall queue | A:243 `presentingWithoutAWindowDoesNotStrandRouter` | Actual detached router rejects modal and allows next push | Meaningful narrow production guard test; keep |
| Completed sheet swipe → next modal | UI:128 | Real gesture attempt then absence/new full-screen | Earlier run failed before gesture; post-fix execution pending |
| Cancelled sheet swipe → Done/next modal | UI:143 | Short slow drag then Done still usable | Does not prove engagement/cancellation, F11; post-fix execution pending |
| UIKit modal → SwiftUI sheet | UI:176 | Actual action, displayed original stack, Done to Home | Earlier failure before post-sheet assertions; runtime recheck |
| Pushed lab → SwiftUI sheet | UI:188 | Actual action and original stack label | Same runtime caveat |
| Sheet identifiers distinct / Done hittable | UI:98 `testSwiftUISheetControlsKeepDistinctAccessibilityIdentifiers` | Added real UI regression, title/Done/stack IDs, dismissal | New test, never executed in inspected old bundle; run first in post-fix validation |
| Navigation after terminal stop | No real queue test | F03 source-traced API edge | Queue phone behind held animated push, stop and release, AUD-05 |
| Weak lifetime / absence of retain cycles | No deallocation assertions | Weak captures visible by review | Add weak coordinator/controller assertions on all exits, AUD-02/AUD-07 |
| Release/demo control boundary | No configuration smoke test | DEBUG gates only diagnostics/launch args | F12 deliberate demo behavior; conditional AUD-11 |
| Phone landscape/loading/error readability | No layout-specific test | Supported orientations + constrained XIB reviewed | Source-supported short-height risk F13; AUD-12 |

## Test quality and consolidation recommendations

1. **Keep layered tests with different claims.** Processor duplicate suppression, backend idempotency and visible authenticated refresh are complementary, not redundant. A fake invocation assertion cannot replace actual actor data behavior, and an actor test cannot prove OS URL delivery.
2. **Keep one no-shortcut launch regression.** The default launch/control test catches a class of errors that `--authenticated`/`--link` tests alone would miss. A/B/F intentionally overlap phone presence but exercise Skip, success and failure/retry; consolidate setup helpers, not the behaviors.
3. **Preserve RouterSpy but stop treating it as a real transition implementation.** Synchronous spy replacement/dismissal cannot validate UIKit completion ordering. Verify coordinator requests with it; use attached router tests for execution.
4. **Improve assertion meaning before adding test volume.** Compare controller identities for preservation, observe intended values rather than incidental publisher count, and verify transition engagement/cancellation rather than merely that a control remains.
5. **Make UI navigation helpers screen-aware.** `findAndTap` uses up to six whole-screen swipes; fixed-coordinate gestures, repeated swipes and first-bar-button selection depend on layout. Use known containers, readiness checks and specific Back targets. Do not add unnecessary sleeps or inflate timeouts.
6. **Control asynchronous stages.** Immediate cancellation and a fixed actor delay are not substitutes for a repository entered-stage signal. Controlled continuations belong in test utilities, not test-only branches scattered through production classes.
7. **Treat XIB names and actions accurately.** Existing `xibOutletsAndActionsLoad` tests three outlets, not every action. Add precise action assertions where lifecycle matters, or rename it to its actual coverage.
8. **Do not claim performance or memory proof.** No leak graph, frame-time trace or before/after test-time comparison was captured. Proposed notification consolidation has maintainability value without a performance claim.

## Commands and exact environment limitation

Fresh audit commands, run from the project directory:

```sh
xcodebuild -version
xcodebuild -list -project CoordinatorNavigationDemo.xcodeproj
xcodebuild -showdestinations \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo
plutil -lint CoordinatorNavigationDemo.xcodeproj/project.pbxproj App/Info.plist
xcodebuild build-for-testing \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/coordinator-audit-build CODE_SIGNING_ALLOWED=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
swift test --disable-sandbox -Xswiftc -disable-sandbox
```

The extra compiler flag avoids the managed environment's rejected nested macro `sandbox-exec` (`sandbox_apply: Operation not permitted`). It was supplied on the command, not added to build settings. Normal local Xcode should not need it; the outer tool restrictions remain active.

Separate native unit and UI attempts used `test-without-building`, the fresh derived-data directory, `-destination-timeout 10`, and the actual iPhone 17 UDID from the old result. Both failed before execution with **“Unable to find a device matching the provided destination specifier.”** CoreSimulator reported **NSPOSIXErrorDomain Code 61, Connection refused** and no accessible runtime devices. Generic destinations remained available for compilation. Provisioning-profile warnings did not prevent unsigned Simulator builds. These are environment failures, not test assertion failures.

To verify locally in the working Xcode session, select an available iPhone Simulator and press **Command-U**, or use:

```sh
cd /path/to/CoordinatorNavigationDemo
xcrun simctl list devices available
# Replace DEVICE-UDID with an available device; do not use a generic destination to run tests.
xcodebuild test \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -only-testing:CoordinatorNavigationDemoTests CODE_SIGNING_ALLOWED=NO
xcodebuild test \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -only-testing:CoordinatorNavigationDemoUITests CODE_SIGNING_ALLOWED=NO
```

To focus the identifier regression, replace the last `-only-testing` value with `CoordinatorNavigationDemoUITests/NavigationUITests/testSwiftUISheetControlsKeepDistinctAccessibilityIdentifiers`. Run the full suite afterward: a focused pass would not establish all gesture/navigation behavior.

Local audit evidence (not repository artifacts):

- `/private/tmp/coordinator-audit-project.log`
- `/private/tmp/coordinator-audit-destinations.log`
- `/private/tmp/coordinator-audit-build.log`
- `/private/tmp/coordinator-audit-portable-tests.log`
- `/private/tmp/coordinator-audit-ios-unit.log`
- `/private/tmp/coordinator-audit-ui.log`
- `/private/tmp/coordinator-audit-parser-probe.log`
- Existing user summary and extracted hierarchy in `/private/tmp/coordinator-reported-test-summary.json` and `/private/tmp/coordinator-sheet-failure-hierarchy.txt`.

Result artifacts contain local identifiers and potentially fixture data; they were not copied into the public source tree. The audit reports record findings and results, not a claim that execution succeeded where it was blocked.
