# Global alerts and URL delivery

Swift 5 / iOS 17, the coordinator hierarchy, one navigation controller and actual XIB integration remain unchanged. This revision addresses AUD-14/AUD-17 and the alert request invariant from F19. It does not execute the architecture simplification plan.

AUD-06/AUD-16 additions below passed focused and full user runs, including **118 unit/UI declarations / 136 expanded runs**, with no failures/skips/recorded runtime warnings on iPhone 17/iOS 27.0 Simulator. The verified implementation and evidence are committed together after baseline `a9b7788`; see [Verification.md](Verification.md) for artifacts and limits.

The subsequent [lifecycle timing follow-up](plans/lifecycle-timing.md) passed all eight declarations / 16 expanded runs. It covers obsolete selected actions, cancellation before queued dismissal, visible or inactive-buffered global notices across asynchronous phone completion, and held startup replaced by a new scene composition. The newest full run passed **99 unit + 27 UI = 126 declarations / 152 expanded runs**, zero failures/skips/recorded runtime warnings. Queue ownership and native-grabber gesture follow-ups passed. The earlier 118/136 counts describe baseline `981a91b`.

## Request ownership

`AppAlertRequest` carries a safe semantic key, renderer, text, actions and lifetime scope. `AppAlertQueue` rejects empty/repeated actions and non-OK global notices before activation. Active/pending duplicates coalesce by scope plus key. Typed AlertAdmission reports accepted, duplicate, invalidActions or capacityExceeded. Distinct accepted requests wait FIFO. Default capacity is 9 pending plus 1 active, with the final pending slot reserved for flow recovery; global notices can fill at most 8. Rejection/coalescing/cancellation owns no callback. User completion clears ownership before its at-most-once action callback.

SceneDelegate forwards activation. New presentation requires an active scene, attached window and stable visible presenter. Existing alerts remain owned when the scene resigns. The router yields after at most 4 ordinary navigation commands to an eligible waiting alert; authorized root replacement/cleanup has precedence. It never interrupts a running native transition.

Flow scope is the default, including authenticated Retry/Cancel recovery. Normal root replacement cancels flow requests. Global informational OK notices survive, including malformed-link, demo and capacity notices. A visible global notice completes before replacement proceeds; a queued global notice is reanchored after replacement. Reset/stop/disconnect explicitly cancel all scopes. A reserve slot protects the demo's one active redeem recovery; defensive rejection handling releases an intent whose recovery callback was not admitted, retaining session/navigation and reporting generic retry-later status. [NavigationContract.md](NavigationContract.md) defines the other queue limits and integration assumptions.

## Native rendering and dismissal

`AlertPresentation` owns one exact controller and a small lifecycle: idle, presenting, visible, dismissing, finished.

- UIKit: present an exact `UIAlertController`.
- SwiftUI: present a transparent `UIHostingController` with `.overFullScreen`, then activate its native `.alert`. This transient host lives above the current feature/modal; it is not inserted into another hosting view, managed navigation stack or second window. It has no Close action or independent navigation state.
- UIKit presentation completion followed by a main-queue turn signals readiness. A native SwiftUI `.onChange` updates local `@State`, which owns the `.alert` binding. Native dismissal changes only that local state, not an observed `@Published` property. There is no `onAppear` publication. Scene eligibility and cancellation are checked again before signaling readiness.
- Selection is accepted once, including an action arriving before animated presentation completion. Cancellation can override a selected action awaiting cleanup.
- Cancellation during presentation waits for the real presentation completion. Dismissal waits for an in-flight native transition's completion, then dismisses only the exact owned subtree. Underlying feature modals remain intact. Cleanup uses UIKit's dismissal completion, not a guessed topmost controller or a window/polling timer.
- If UIKit rejects presentation before attaching the owned controller, the request is cancelled without an action and queue ownership is released.

The owned host is an intentional UIKit/SwiftUI integration boundary. It adds a transient presentation for SwiftUI alerts, while preserving native `.alert`, XIB support and the single push stack. The latest complete iPhone 17 / iOS 27.0 run passed all 126 unit/UI declarations with zero recorded runtime warnings. Earlier containment/publication warnings remain absent from its test consoles. Native test-window focus-engine/handler diagnostics remain separately documented; this is not a claim of a silent console or memory profiling. See [NavigationContract.md](NavigationContract.md) for current navigation/alert ordering and lifecycle constraints.

Apple references: [dismissal ownership and completion](https://developer.apple.com/documentation/uikit/uiviewcontroller/dismiss(animated:completion:)), [system URL dispatch](https://developer.apple.com/documentation/xcuiautomation/xcuisystem/open(_:)).

## Business errors

Authenticated failures retain the original session and active redeem intent until Retry/Cancel. Retry reuses that original context; Cancel preserves navigation/session and advances the next business intent. No login/create/phone flow is introduced for an authenticated grant. Unauthenticated failures retain the existing redeem Retry/Return screen. Unsupported URLs use generic text without showing/logging URLs or access codes.

## Cold, warm and background URL delivery

- Cold: install the initial Welcome/root and window immediately. Complete optional authenticated Debug setup before delivering connection URLs. A retained scene startup task is cancelled on disconnect; generation/cancellation guards prevent obsolete startup delivery. Additional URL/activity callbacks are parsed immediately, deduplicated and staged as at most 8 typed intents. Invalid/overflow notices coalesce as flags until setup finishes. They then join the same processor admission boundary; no raw URL array grows while startup/reset awaits.
- Warm/background: system-dispatched URLs enter the existing scene handlers and coordinator pipeline. The tests use `XCUIDevice.shared.system.open`, not `XCUIApplication.open`, for instance preservation. Background tests wait for a background/suspended state before dispatch.
- Explicit cold UI tests still use `XCUIApplication.open`, after terminating the app. One covers new-user onboarding; another covers ADD-CRED after authenticated seeding.
- Debug diagnostics expose an opaque instance ID. Tests compare it before/after delivery so recreating an equivalent screen cannot silently satisfy preservation assertions. It carries no account/code/token and never drives navigation.
- No background execution entitlement is added. iOS may suspend work. An error received while inactive waits for activation; foreground re-entry is distinct from proving execution while suspended.

## Regression coverage added or corrected

- Queue: invalid action arrays; matching cancellation releases only the current request and never calls its action.
- Startup: actual composition/use case/backend with zero mock delay, authenticated cold URL ordering, and a genuinely pushed protected phone for unauthenticated cold delivery.
- Attached-window native tests: wait for an actual native alert, then test hosting child containment, cancellation/queue release, exact modal preservation, phone protection/Skip, inactive business failure/reset, and immediate cancellation during presentation. Alert/router suites share a serialized window lease, wait for actual viewDidAppear before presenting, and await native cleanup before restoring/releasing windows. Wait failures preserve their caller source location.
- UI: corrected warm/background/phone URL dispatch with instance continuity; separate cold cases; duplicate/distinct OS links during protected phone; a new incoming link queued while a SwiftUI alert is visible, followed by another presentation.

The current green lifecycle revision contains **99 unit + 27 UI = 126 declarations**, with **152 expanded runs**. The prior policy baseline had 118 declarations / 136 expanded runs. The portable subset is **30 declarations** and executed in the native unit target; no separate package run is claimed. See [the policy plan](plans/queue-and-alert-policy.md).

## Verification handoff

The lifecycle, queue lifetime and completed/cancelled sheet cases passed in the newest full run; a separate UI run passed all 27 methods. Keep them as regression gates. The renderer cancellation case uses the shared internal `AlertPresentation.select` boundary with a real attached native alert; it does not invoke private action handlers or simulate a UIKit/SwiftUI button tap. The phone-notice case cancels the alert administratively to finish fixture cleanup; native acknowledgment is covered separately by existing UI tests.

**The latest full run passed 126/126 declarations / 152 expanded runs: all 99 unit and 27 UI.** Bundle: `Test-CoordinatorNavigationDemo-2026.11.08_10-42-30-+0200.xcresult` in DerivedData, iPhone 17 / iOS 27.0. Both previous failures passed. Zero failures/skips/recorded runtime warnings. Earlier SwiftUI publication/containment warnings remain absent; native unit focus-engine/handler diagnostics remain unexplained. See [Verification.md](Verification.md) for exact evidence and limits. The agent inspected completed results without running builds/tests; the verified implementation and evidence are committed together at the user's request.

In Xcode, open the native project, select an iPhone Simulator and use Product → Test. For command-line execution, replace DEVICE-UDID with an available device:

```sh
xcodebuild test \
  -project CoordinatorNavigationDemo.xcodeproj \
  -scheme CoordinatorNavigationDemo \
  -destination 'platform=iOS Simulator,id=DEVICE-UDID' \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/CoordinatorAlertReliability.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

**Result path:** `/private/tmp/CoordinatorAlertReliability.xcresult` exists only if the command above runs with that `-resultBundlePath`. Product → Test in Xcode saves results under `~/Library/Developer/Xcode/DerivedData/CoordinatorNavigationDemo-*/Logs/Test/` instead. `xcresulttool` reads a result; it neither runs tests nor creates the bundle. Use the path from Xcode's Report navigator for that run.

Use a fresh result-bundle path on subsequent runs. Collect the build/test trace and the summary:

```sh
xcrun xcresulttool get test-results summary \
  --path /private/tmp/CoordinatorAlertReliability.xcresult
```

Inspect runtime warnings as well as assertions: unsupported hosting-view containment and publishing during view updates must disappear. Confirm both renderer styles above SwiftUI, pushed XIB, sheet/full-screen and protected phone; Cancel/Retry/Skip must preserve or replace exactly the intended stack. Include cold URL setup, background re-entry, repeated/queued URLs and cancellation during presentation. Attach the new xcresult or its trace/summary before declaring these runtime issues resolved.
