# Global alerts and URL delivery

Swift 5 / iOS 17, the coordinator hierarchy, one navigation controller and actual XIB integration remain unchanged. This revision addresses AUD-14/AUD-17 and the alert request invariant from F19. It does not execute the architecture simplification plan.

## Request ownership

`AppAlertRequest` carries a safe semantic key, renderer, text and supported actions. `AppAlertQueue` rejects empty/repeated actions before they can own the queue. Active/pending duplicates coalesce by key; distinct accepted requests wait FIFO within the alert queue. A matched user completion clears ownership before its callback. Cancelling/rejecting a presentation clears only that active request, without a business callback, so the next request can proceed. Reset/stop discard all active/pending requests and callbacks. The delivery contract is at-most-once, not guaranteed callback delivery for coalesced/cancelled requests.

SceneDelegate forwards activation to the router. Starting a new request requires an active scene, an attached window and a stable visible presenter. Existing native alerts remain owned when the scene resigns; the next request waits. Navigation commands take priority over waiting alerts. Normal root replacement still cancels all alerts; the audit's global-versus-flow lifetime policy decision remains deferred. Queues remain in memory and unbounded; capacity policy is a separate task.

## Native rendering and dismissal

`AlertPresentation` owns one exact controller and a small lifecycle: idle, presenting, visible, dismissing, finished.

- UIKit: present an exact `UIAlertController`.
- SwiftUI: present a transparent `UIHostingController` with `.overFullScreen`, then activate its native `.alert`. This transient host lives above the current feature/modal; it is not inserted into another hosting view, managed navigation stack or second window. It has no Close action or independent navigation state.
- UIKit presentation completion followed by a main-queue turn signals readiness. A native SwiftUI `.onChange` updates local `@State`, which owns the `.alert` binding. Native dismissal changes only that local state, not an observed `@Published` property. There is no `onAppear` publication. Scene eligibility and cancellation are checked again before signaling readiness.
- Selection is accepted once, including an action arriving before animated presentation completion. Cancellation can override a selected action awaiting cleanup.
- Cancellation during presentation waits for the real presentation completion. Dismissal waits for an in-flight native transition's completion, then dismisses only the exact owned subtree. Underlying feature modals remain intact. Cleanup uses UIKit's dismissal completion, not a guessed topmost controller or a window/polling timer.
- If UIKit rejects presentation before attaching the owned controller, the request is cancelled without an action and queue ownership is released.

The owned host is an intentional UIKit/SwiftUI integration boundary. It adds a transient presentation for SwiftUI alerts, while preserving native `.alert`, XIB support and the single push stack. The user's latest complete iPhone 17 / iOS 27.0 run passed all 97 unit/UI declarations and recorded no runtime warnings. The earlier containment/publication warnings are absent from its console. Native test-window focus-engine/handler diagnostics remain separately documented; this is not a claim of a silent console or memory profiling. See [NavigationContract.md](NavigationContract.md) for current navigation/alert ordering and lifecycle constraints.

Apple references: [dismissal ownership and completion](https://developer.apple.com/documentation/uikit/uiviewcontroller/dismiss(animated:completion:)), [system URL dispatch](https://developer.apple.com/documentation/xcuiautomation/xcuisystem/open(_:)).

## Business errors

Authenticated failures retain the original session and active redeem intent until Retry/Cancel. Retry reuses that original context; Cancel preserves navigation/session and advances the next business intent. No login/create/phone flow is introduced for an authenticated grant. Unauthenticated failures retain the existing redeem Retry/Return screen. Unsupported URLs use generic text without showing/logging URLs or access codes.

## Cold, warm and background URL delivery

- Cold: install the initial Welcome/root and window immediately. Complete optional authenticated Debug setup before delivering connection URLs. A retained scene startup task is cancelled on disconnect; generation/cancellation guards prevent obsolete startup delivery. Additional URL/activity callbacks received during setup wait in a scene-startup buffer, then enter the same coordinator parser/processor.
- Warm/background: system-dispatched URLs enter the existing scene handlers and coordinator pipeline. The tests use `XCUIDevice.shared.system.open`, not `XCUIApplication.open`, for instance preservation. Background tests wait for a background/suspended state before dispatch.
- Explicit cold UI tests still use `XCUIApplication.open`, after terminating the app. One covers new-user onboarding; another covers ADD-CRED after authenticated seeding.
- Debug diagnostics expose an opaque instance ID. Tests compare it before/after delivery so recreating an equivalent screen cannot silently satisfy preservation assertions. It carries no account/code/token and never drives navigation.
- No background execution entitlement is added. iOS may suspend work. An error received while inactive waits for activation; foreground re-entry is distinct from proving execution while suspended.

## Regression coverage added or corrected

- Queue: invalid action arrays; matching cancellation releases only the current request and never calls its action.
- Startup: actual composition/use case/backend with zero mock delay, authenticated cold URL ordering, and a genuinely pushed protected phone for unauthenticated cold delivery.
- Attached-window native tests: wait for an actual native alert, then test hosting child containment, cancellation/queue release, exact modal preservation, phone protection/Skip, inactive business failure/reset, and immediate cancellation during presentation. Alert/router suites share a serialized window lease, wait for actual viewDidAppear before presenting, and await native cleanup before restoring/releasing windows. Wait failures preserve their caller source location.
- UI: corrected warm/background/phone URL dispatch with instance continuity; separate cold cases; duplicate/distinct OS links during protected phone; a new incoming link queued while a SwiftUI alert is visible, followed by another presentation.

Current source contains **71 native unit declarations + 26 UI methods = 97 declarations**, including 22 router lifecycle declarations added during navigation hardening. The portable subset remains **23 declarations in four suites**. The full native result includes 111 expanded runs. The portable command was not separately rerun; its shared declarations executed in the native unit target.

## Verification handoff

**The user's latest native run passed: 71 unit + 26 UI = 97 declarations, 111 expanded runs, zero failures/skips and zero recorded runtime warnings.** Bundle: `Test-CoordinatorNavigationDemo-2026.11.07_20-52-23-+0200.xcresult` in DerivedData, iPhone 17 / iOS 27.0. Earlier SwiftUI publication/containment warnings are absent from its console. UIKit focus-engine/handler diagnostics remain in the native unit console, without assertion failures; their cause is unproven. See [Verification.md](Verification.md) for the exact evidence and remaining limits. The agent did not run builds or tests; it only inspected the user's completed results.

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
