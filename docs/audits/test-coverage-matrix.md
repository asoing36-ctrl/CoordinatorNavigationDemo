# Test coverage and execution matrix — including alerts

Audit date: 2026-11-07. Baseline is the current working tree, including the pre-audit local sheet-identifier fix. No test or production file was changed during this audit.

## Inventory and execution status — current alert-aware baseline

| Suite/check | Current source | Re-audit evidence |
|---|---|---|
| Native Swift Testing | **39 declarations**: 11 DomainTests + 3 IntentProcessorTests + 18 ArchitectureTests + 7 AppAlertQueueTests | **39/39 declarations passed** in finalized current user run; audit-process replay separately blocked |
| Native XCUITest | **21 methods**, including 5 alert UI scenarios | **19 passed / 2 failed** in finalized current user run; four runtime warnings in two passing methods |
| Supplemental package | **21 declarations** in 4 suites | **Fresh pass**, actual domain/intent/alert-queue sources |
| Native build-for-testing | App and both test targets | **Fresh pass**, Simulator compilation |
| Additional request-contract probe | Actual AppAlertRequest/AppAlertQueue in Swift 5 mode | Empty/duplicate actions admitted; empty active cannot complete using OK; not a UIKit crash test |

Current total: **60 declarations**. Two parameterized declarations contribute ten cases instead of two, adding eight to an expanded execution count (68 in the finalized full current suite). Counts of compile-only tests are not test passes.

### Completed native results, chronologically

| User-owned bundle | Result | What it establishes |
|---|---|---|
| `Test-CoordinatorNavigationDemo-2026.11.07_10-01-53-+0200.xcresult` | 39 pass / 5 fail, 44 declarations (52 expanded cases) | Earlier five sheet identifier failures; not an alert regression |
| `Test-CoordinatorNavigationDemo-2026.11.07_11-09-28-+0200.xcresult` | **45 pass / 0 fail**, 53 expanded cases; iPhone 17 / iOS 27.0 | Later pre-alert suite, including identifier regression, passed |
| `Test-CoordinatorNavigationDemo-2026.11.07_11-39-39-+0200.xcresult` finalized during re-audit | **58 pass / 2 fail**, 60 declarations; **66 pass / 2 fail** expanded | Current alert-aware run: unit 39/39, UI 19/21; iPhone 17 / iOS 27.0 |

The 45-declaration pass is valuable evidence that the old sheet tests and their accessibility regression ran successfully. It does **not** contain the ten new unit and five new UI alert declarations. The finalized 11:39 run now executes those declarations. Basic alert interactions have runtime evidence, but two URL scenarios fail and native warnings/lifecycle gaps remain; do not describe the current suite as green.

Earlier failed methods were `testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation`, `testSheetSwipeDismissalAllowsPresentingAgain`, `testSwiftUISheetDismissalPreservesSecondaryAndBack`, `testUIKitLabPresentsSwiftUISheetWithoutPushing`, and `testUIKitModalCanSwitchToSwiftUISheet`. All stopped while looking for `dismissSwiftUIModal`. The exported hierarchy proved that an outer identifier overwrote the leaf identifiers; the later 45-test pass supersedes that failure snapshot for pre-alert regression status. The original audit record is preserved in [history/pre-alerts-2026-11-07/test-coverage-matrix.md](history/pre-alerts-2026-11-07/test-coverage-matrix.md).

## Current native failures and warnings — separate from architecture proposals

Completed bundle: `/Users/glad/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-cakzsvptpysegvdklzvrxgmnhvhy/Logs/Test/Test-CoordinatorNavigationDemo-2026.11.07_11-39-39-+0200.xcresult`.

| Kind | Exact result | Interpretation / next check |
|---|---|---|
| UI failure | `testAuthenticatedDeepLinkErrorIsGlobalAndCancelPreservesStack()` | `Unable to Redeem` absent at `CoordinatorNavigationDemoUITests/NavigationUITests.swift:202`; Cancel/preservation assertions never run |
| UI failure | `testBackgroundDeepLinkErrorAppearsAfterForegroundActivation()` | Same missing-alert assertion at line 202; Retry/modal assertions never run |
| Activity/hierarchy evidence | Both URL calls have a nested second Launch; final hierarchy is Home | app.open is launch-by-URL, not proof of delivery into the original instance; Debug --authenticated reset follows early connection URLs. F25 distinguishes confirmed test-assumption error from unproven ordinary warm-delivery failure |
| Runtime warning, twice | Unsupported addition of `_UIHostingView<SwiftUIAlertAnchor>` to UIHostingController.view | F23 confirmed unsupported composition at `Core/Alerts/AlertPresentation.swift:35–51`; correct containment |
| Runtime warning, twice | Publishing changes during view updates | F24 confirmed warning, exact mutation/backtrace not recorded; trace after containment correction |

Both warnings occur in **passing** `testBothNativeAlertStylesFromSwiftUIAndXIB` and `testAlertsAboveSheetAndFullScreenPreserveThem`. A passing assertion does not establish supported UIKit/SwiftUI composition. No leak/crash is inferred. All five previously reported sheet methods passed in this current run.

For warm/background coverage, use a system URL-open operation and establish process/scene continuity. [Apple documents XCUIApplication.open as launching by URL](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/open(_:)); the installed SDK's `XCUIApplication.h:46–63` describes it alongside launch. Use separate cold-entry tests and control seed-before-URL ordering. Do not loosen the missing-alert assertion or merely extend its timeout.

## Reading the matrix

Aliases below expand to exact current paths (line references refreshed after the alert extension):

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
| Real cold-start custom URL | A:14 `coldStartLoginSessionTransitionAndSkip`; UI:267 test A | Spy direct `receive` and Debug launch helper exercise business pipeline | Direct/helper entry bypasses scene options. The alert app.open activity launches again; cold URL plus Debug seed ordering is not asserted; F25/AUD-17, then AUD-10 |
| Warm-start custom URL | UI:235 `testGlobalAlertOverProtectedPhonePreservesItsBackPolicy`; UI:244 `testAuthenticatedDeepLinkErrorIsGlobalAndCancelPreservesStack` | Source attempts delivery after navigation, but activity records another Launch | Authenticated error method failed; preservation is not proved by launch-by-URL. Correct harness, F25/AUD-17 |
| Background-to-foreground URL | UI:255 `testBackgroundDeepLinkErrorAppearsAfterForegroundActivation` | Home button then app.open records another Launch; method fails waiting for the error | Does not prove preserved background instance or inactive completion; F25/AUD-17 and F17/AUD-14 |
| One transaction at a time | I:6 `duplicateSuppressionAndFIFO`; A:41 `duplicatesAndQueueStayProtectedUntilCompletion` | Pure active ownership; spy queued ADD-CRED stays behind phone | No gated backend entry counts or UI queue burst; AUD-02/AUD-06 |
| Concurrent duplicate link suppression | I:6 and A:41 | Active/pending identical intents are suppressed | Verify actual use-case invocation count while suspended, not only final count; AUD-02 |
| Distinct queued intent | I:6, A:41 | FIFO and next ADD-CRED after Skip; final credential count 2 | More than one distinct queued intent, failure/reset/overflow cases; AUD-06 |
| Completed link redelivery | I:30 `finishedIntentMayBeSubmittedAgainForIdempotentRefresh`; D:19 | Processor allows again; backend does not duplicate grants | App/visible data idempotency scenario; AUD-10 |
| Queue during phone retry | A:41 queue through phone, A:56 failure/retry separately | Two useful narrow behaviors | Combine a waiting intent with failed/retried association; AUD-02 |
| Queue/reset cleanup | I:22 `resetDropsPendingAndActive` | Pure queue bookkeeping | URL receipt during held app reset and invalid deferred URLs; AUD-02/AUD-06 |
| New account creation and login | D:19 `newAccountAndIdempotency`; UI:267 test A | Business outcome, eligibility, one login; actual screen/credential UI | Stage-boundary cancellation after create/login; AUD-02 |
| Existing account login while logged out | D:31 `existingAccountLogin`; UI:275 test B | Business loggedIn/eligible/no creation; actual Associate route | App-level error/retry from this path; AUD-10 |
| Session transition after login | A:14, D:19/31 | Authenticated store and phone flow; returned result | Atomic publisher/state observation only if required; AUD-09/AUD-10 |
| Original auth snapshot across retry | D:19 contrasts nil/existing session; D:53 networkRetry | Correct use-case outcomes in separate requests | No coordinator Retry after a staged partial account effect; AUD-02/AUD-08 |
| Already-authenticated grant | D:38 `authenticatedRedeemNeverLogsIn`; A:28; UI:283 test C | Same session result, no login, premium permission, no phone | No actual create/lookup invocation spy; route identity assertion weak; AUD-10 |
| No phone just because credential added | D:38; A:28; UI:283 | Eligibility false, coordinator nil, no phone control | Strong coverage across layers; preserve |
| Credential + permission refresh | D:38; A:28; UI:283 | Backend grants, SessionStore data, visible Premium Library/count | Publisher emission and active-sheet live update missing; AUD-09/AUD-10 |
| Authenticated controller/history preservation | A:28 `authenticatedStackIsPreservedAndUpdatesObserved`; UI:283 | Equal route values and visible Secondary/diagnostics | Could pass after recreation; compare controller identities and navigation requests; AUD-10 |
| INVALID / EXPIRED / ADD-CRED unsupported context | D:47–51 `errorsDoNotAuthenticate` (3 cases) | Business throws DemoError, zero login | Exact error identity/account/credential unchanged assertions stronger; authenticated variants missing; AUD-04/AUD-10 |
| Unauthenticated recoverable invalid UI | A:69 `invalidCodeHasRecoverableError`; UI:299 test D | Spy error/Return; real Return to Welcome | Expired/network Retry UI not covered; AUD-04/AUD-10 |
| Recoverable network retry | D:53 `networkRetry` | Actual use case/actor first throws then succeeds | No visible coordinator Retry button or preserved original context assertion; AUD-02/AUD-10 |
| Authenticated error on any screen/modal | A:258 `backgroundRedeemFailureWaitsForActivationAndPreservesDetails`; A:276 `alertRetryUsesExistingSessionAndPreservesModal`; UI:244,255 global-error methods | Current source requests native global Retry/Cancel; spy verifies details/modal identity and original session behavior | Spy tests passed; both corresponding URL UI cases failed at alert wait after a new launch. F25/AUD-17 first; error-family/destination and cleanup matrix remain open, AUD-04/AUD-14 |
| Idempotent concurrent backend effects | D:59 `concurrentRedemptionEffectsAreIdempotent` | 10 actual actor grants, final count 2 | Does not prove app only dispatched once; keep separate from intent suppression |
| Cancel redeem before work | D:68 `cancelledRedeemDoesNotAuthenticate` | Cancelled Task and no create/login | Can cancel at check before use case starts; staged gates required, F02 |
| Reset invalidates old app flow | A:105 `resetCancelsObsoleteFlow` | Spy Welcome/no session/children after immediate reset | Backend may never start; force entry then release, AUD-02 |
| Reset caller cancellation | A:79 `callerCancellationDoesNotStrandReset` | Administrative reset finishes, busy clears, subsequent reset works | Useful distinct lifecycle policy; retain |
| Stop during reset cannot revive | A:92 `stoppedCoordinatorCannotBeRevivedByReset` | Busy observer calls stop; reset does not install new child/session | Does not force router animation or queued command, F03/AUD-05 |
| Phone genuinely pushed with lower flow | A:14; UI:267/275; UI:73 diagnostics | Spy exact `[welcome,redeem,phone]`; real diagnostics route | Attached real-router controller types/identities can strengthen, AUD-03 |
| Skip → Home root | A:14; UI:267; UI:43 default-launch path | Spy root/Back reset, actual Home and credential | Useful overlap with startup test: retain one default entry and one focused onboarding UI path |
| Associate → Home root | D:80 `phoneFailureRetryAndSuccess`; A:56; UI:275 | Actual actor counter, spy root, actual XIB Associate workflow | Once-only callbacks and repeated actions while loading not asserted, AUD-02 |
| Phone failure → stay / retry / Skip | D:80; A:56; UI:322 test F | Business error/success; spy phone then Home; visible retry UI | Failure followed by Skip and held-request duplicate submission cases; AUD-02/AUD-10 |
| Bar Back unavailable on phone | UI:35 helper; A:118 `pushDuplicatePopAndProtection` | Bar item absent, UIKit hidesBackButton, router blocked | Add direct popTo/popToRoot checks and engaged gestures, AUD-03 |
| Programmatic Back blocked | A:118 | Real detached router pop/popTo and direct single UIKit pop blocked | Positive popTo and direct UIKit popTo/popToRoot untested, AUD-03 |
| Interactive phone edge pop blocked | UI:35 helper used by A/B/F | Real edge-drag attempt leaves phone control | Could pass if gesture never engages; independent delegate/gesture evidence needed, AUD-03/AUD-10 |
| Normal Back restored afterward | A:118; UI:306/322 | Real detached pop and actual bar Back | No successful ordinary edge swipe after onboarding, AUD-03/AUD-10 |
| Duplicate route push blocked | A:118 | Real nonanimated duplicate route ignored | Duplicate pending animated push not tested, AUD-03 |
| Explicit stack replacement bypasses policy | A:118; A:14 | Real detached root replacement plus spy onboarding | Replacement during ongoing push/modal needs attached tests, AUD-03 |
| Mixed SwiftUI → SwiftUI | UI:43/306 | Actual pushes and Back | Preserve representative path |
| SwiftUI → XIB | UI:306 test E and diagnostics test UI:73 | Actual lab appears and accepts action | Broader layout variants untested |
| XIB → SwiftUI / XIB → XIB | UI:306 | Actual detail/lab-detail and Back | Strong representative integration; retain |
| Real XIB resource/outlet loading | A:139 `xibOutletsAndActionsLoad` | Actual phone Associate/Skip and lab SwiftUI outlets nonnil | Name implies actions more broadly; only full-screen dismiss action sent explicitly in A:218 |
| Once-only XIB dismissal action | A:218 `fullScreenUsesXIBAndHasDismissAction` | Actual nib/button sends action into router spy | Actual animation queue still UI/integration responsibility |
| Root containment / startup idempotence | A:177 `diagnosticsCannotBecomeANavigationChild`; UI:43/57/73 | Actual composition containment; real visible default launch and controls | Keep regression that protects original white-screen defect |
| SwiftUI sheet style/stack identity | A:201 `swiftUISheetPreservesSecondaryAndDismissesThroughRouter`; UI:114 | Spy pageSheet and exact controller identities; UI presentation/Done/Back | Old identifier failures superseded; current method passed. Deterministic transition/cancellation coverage still weak |
| Full-screen XIB modal and dismiss→push | A:218; UI:160 | Actual XIB action to spy; launched full-screen→details→Back | Preserve, add attached dismissal ordering when simplifying router |
| Duplicate modal and modal reset | A:234 `resetRemovesPresentationAndDuplicateDoesNotReplaceIt` | RouterSpy ignores second modal and clears on reset | Mostly spy policy; actual UIKit reset-during-presentation missing, AUD-03 |
| Detached presentation does not stall queue | A:247 `presentingWithoutAWindowDoesNotStrandRouter` | Actual detached router rejects modal and allows next push | Meaningful narrow production guard test; keep |
| Completed sheet swipe → next modal | UI:128 | Real gesture attempt then absence/new full-screen | Passed in pre-alert and current runs; deterministic engagement still needs stronger evidence |
| Cancelled sheet swipe → Done/next modal | UI:143 | Short slow drag then Done still usable | Passed current run, but does not prove engagement/cancellation, F11 |
| UIKit modal → SwiftUI sheet | UI:176 | Actual action, displayed original stack, Done to Home | Passed in pre-alert and current runs |
| Pushed lab → SwiftUI sheet | UI:188 | Actual action and original stack label | Passed in pre-alert and current runs |
| Sheet identifiers distinct / Done hittable | UI:98 `testSwiftUISheetControlsKeepDistinctAccessibilityIdentifiers` | Added real UI regression, title/Done/stack IDs, dismissal | Included in the completed 45-declaration pre-alert pass; retain in current suite |
| Navigation after terminal stop | No real queue test | F03 source-traced API edge | Queue phone behind held animated push, stop and release, AUD-05 |
| Weak lifetime / absence of retain cycles | No deallocation assertions | Weak captures visible by review | Add weak coordinator/controller assertions on all exits, AUD-02/AUD-07 |
| Release/demo control boundary | No configuration smoke test | DEBUG gates only diagnostics/launch args | F12 deliberate demo behavior; conditional AUD-11 |
| Phone landscape/loading/error readability | No layout-specific test | Supported orientations + constrained XIB reviewed | Source-supported short-height risk F13; AUD-12 |

## Alert-specific requirement matrix

Paths: **Q** = `CoordinatorNavigationDemoTests/AppAlertQueueTests.swift`; **A** and **UI** use the aliases above. Queue tests are part of the freshly passed portable subset. Native flow tests use RouterSpy and all three passed. Of five alert UI methods, three passed and two failed in the finalized current run.

| Alert contract | Exact test / line | What it establishes | Remaining gap |
|---|---|---|---|
| Inactive buffering / activate once | Q:7 `inactiveSceneBuffersRequestsUntilActivated` | Pure queue denies begin until active, selects once | Actual scene/UIKit renderer gate needs runtime tests |
| FIFO across UIKit/SwiftUI styles | Q:26 `requestsRemainFIFOAcrossRendererStyles` | Logical order across styles and error request | Actual alert→alert native dismissal ordering, F17 |
| Semantic duplicate suppression | Q:48 `duplicateKeysAreSuppressedWhilePendingAndActive` | Different request IDs/messages/styles sharing a key coalesce; duplicate callback gets zero | Document acceptance/coalescing, F22; no guarantee every submitter receives an outcome |
| Matching action / at most once | Q:69 `completionRunsOnceForTheMatchingRequestAndAllowedAction` | Wrong UUID/action ignored, accepted action fires once | No validation of empty or repeated request actions, F19/AUD-15 |
| Inactivation with an active alert | Q:88 `sceneDeactivationPausesOnlyTheNextPresentation` | Current ownership persists, next request waits | Native alert during scene resign/return; SwiftUI anchor before onAppear, F17 |
| Reset / stale callbacks | Q:107 `resetDropsRequestsAndIgnoresStaleCallbacks` | Pure ownership/callback invalidation | Real visible/dismissing native alert cancellation, F17/F18 |
| Reentrant callback queue use | Q:136 `completionCanReentrantlyEnqueueAndBeginTheSameSemanticKey` | Clear active before callback; new request can start | Router interaction with callback-triggered push/present not exercised |
| Business failure buffered while inactive | A:258 `backgroundRedeemFailureWaitsForActivationAndPreservesDetails` | Actual coordinator/backend + inactive spy queue; Cancel preserves controller identities | No UIWindow/scene or renderer; not actual background execution |
| Retry keeps original session and modal | A:276 `alertRetryUsesExistingSessionAndPreservesModal` | NETWORK-FAIL then Retry; zero login; same spy modal, SwiftUI style | Native renderer completion, all errors/destinations, create count/no-phone/permissions snapshots |
| Reset removes pending business alert | A:295 `resetDiscardsQueuedAlertAndItsCallback` | Pending spy error removed; unauthenticated root | Doesn't reset an active rendered alert, or deliver an already-captured action after reset |
| Both native renderers on SwiftUI/XIB | UI:206 `testBothNativeAlertStylesFromSwiftUIAndXIB` | **Passed** both styles on Home and pushed XIB; recorded F23/F24 warnings | Supported containment, warning-free state mutation, child-count/deallocation assertions |
| Alerts above existing feature modals | UI:219 `testAlertsAboveSheetAndFullScreenPreserveThem` | **Passed** both styles on sheet/full-screen; recorded F23/F24 warnings | Supported containment and warning-free mutation; exact modal identities, repeated cleanup/reset |
| Protected phone survives global alert | UI:235 `testGlobalAlertOverProtectedPhonePreservesItsBackPolicy` | **Passed** unsupported-link acknowledgment and phone checks | app.open can relaunch/recreate phone via --link: original phone preservation unproved; F25 plus actual gesture engagement |
| Authenticated global error Cancel | UI:244 `testAuthenticatedDeepLinkErrorIsGlobalAndCancelPreservesStack` | **Failed** at helper line 202 waiting for alert; final hierarchy Home after second Launch | Cancel/preservation assertions never reached; correct OS delivery harness, F25/AUD-17 |
| Background-to-foreground error Retry | UI:255 `testBackgroundDeepLinkErrorAppearsAfterForegroundActivation` | **Failed** at helper line 202; final hierarchy Home after second Launch | Retry/modal assertions never reached; correct harness, then control inactive response, F25/AUD-17 |
| Alert action configuration | No repository test | Temporary re-audit probe shows invalid actions admitted and empty queue ownership not completable by OK | Add constructor/queue validation tests, AUD-15 |
| Alert identity / monitor termination | No attached-window alert test | Source has heuristic native discovery and window polling | Before attachment, wrong target, native presentation rejection, detach/cancel; AUD-14 |
| Root replacement cancels unrelated alerts | No targeted test | Router unconditionally cancelAll on every replacement | Test global-vs-flow retention during association success, AUD-16 |
| Supported SwiftUI containment / valid publication timing | No targeted warning assertion | Current passing native UI methods record F23/F24 warnings | Reproduce with warning diagnostics, supported container and mutation backtrace; AUD-14 |
| Warm delivery preserves the original process | No continuity assertion | Current app.open calls produce another Launch | System-open harness and distinct cold tests; AUD-17 |
| Observable alert diagnostics | No test / no diagnostic fields | Underlying feature metadata remains available | Optional read-only safe phase/style/count signal, AUD-09/F21 |

The queue tests deliberately call begin/complete themselves. They do not render UIKit or SwiftUI and cannot establish that native dismissal truly completed before callback. Keep that boundary explicit when describing coverage.

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

Fresh re-audit commands, run from the project directory (build and portable suite passed):

```sh
xcodebuild -version
xcodebuild -list -project CoordinatorNavigationDemo.xcodeproj
xcodebuild -showdestinations \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo
plutil -lint CoordinatorNavigationDemo.xcodeproj/project.pbxproj App/Info.plist
xcodebuild build-for-testing \
  -project CoordinatorNavigationDemo.xcodeproj -scheme CoordinatorNavigationDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/coordinator-alert-build CODE_SIGNING_ALLOWED=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
swift test --disable-sandbox -Xswiftc -disable-sandbox
```

The extra compiler flag avoids the managed environment's rejected nested macro `sandbox-exec` (`sandbox_apply: Operation not permitted`). It was supplied on the command, not added to build settings. Normal local Xcode should not need it; the outer tool restrictions remain active.

The current native unit/UI attempt used `test-without-building`, the fresh derived-data directory, `-destination-timeout 10`, and the iPhone 17 / iOS 27.0 UDID from the completed pre-alert result. It failed before execution with **“Unable to find a device matching the provided destination specifier.”** CoreSimulator reported **NSPOSIXErrorDomain Code 61, Connection refused** and no accessible runtime devices. Generic destinations remained available for compilation. Provisioning-profile warnings did not prevent unsigned Simulator builds. These are environment failures, not test assertion failures.

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

The completed current user-owned run is separate from the audit process's blocked replay. It is a genuine **failing test result**, not a destination error. Result artifacts contain local identifiers and potentially fixture data; they were not copied into the public source tree. The audit reports record findings and results, not a claim that blocked execution succeeded.

## Current evidence artifacts

- Fresh build: `/private/tmp/coordinator-alert-reaudit-build.log`.
- Fresh portable 21-test pass: `/private/tmp/coordinator-alert-reaudit-portable.log`.
- Current native attempt: `/private/tmp/coordinator-alert-reaudit-native.log` (destination discovery blocked).
- Actual request-contract probe: `/private/tmp/coordinator-alert-reaudit-request-probe.log`.
- Completed 11:09 pre-alert result summary: `/private/tmp/coordinator-alert-reaudit-user-summary.json`.
- Finalized current result summary/tree: `/private/tmp/coordinator-alert-reaudit-completed-summary.json`, `coordinator-alert-reaudit-completed-tests.json`.
- Current failure detail/activity/hierarchy exports: `/private/tmp/coordinator-alert-reaudit-failure-details.json`, `failure-activities.json`, `failure-hierarchy.txt` and corresponding `background-*` exports (same filename prefix).
- Runtime warning records: `/private/tmp/coordinator-alert-reaudit-completed-object.json`.

Use the native commands above with an available device to reproduce the current **58-pass/2-fail** baseline and retain separate post-change results. The 11:39 bundle was incomplete on first inspection and later finalized; this report uses its completed result. Neither the older 45-test pass nor the audit process's blocked replay substitutes for that result.
