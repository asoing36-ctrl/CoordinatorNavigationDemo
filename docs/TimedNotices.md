# Timed alerts and snackbars

Swift 5 / iOS 17. Timed and user-dismissed notices share typed requests and bounded
admission. A screen's UI technology does not constrain which notice it can request.
NavigationRouting.showAlert remains the entry point; no view accesses navigation
controllers or UIApplication to show a notice.

```swift
// Existing native UIKit/SwiftUI alerts remain user-dismissed.
router.showAlert(.demo(style: .swiftUI))

// Native UIKit or SwiftUI alert, automatically dismissed after visible foreground time.
router.showAlert(AppAlertRequest(key: "saved", style: .uikit,
    title: "Saved", message: "Your changes were saved.", scope: .global,
    dismissAfter: .seconds(4)))

// A nonblocking snackbar; nil keeps it visible until the user taps Dismiss.
router.showAlert(AppAlertRequest(key: "sync-complete", style: .uikit,
    title: "Sync complete", message: "Your data is up to date.", scope: .global,
    presentation: .snackbar, dismissAfter: nil))
```

Custom requests can set any positive duration up to 86,400 seconds; nil is manual.
The demo provides four-second timed alerts/snackbars and persistent snackbars.
Keys must be nonsensitive semantic identifiers, never access codes or full URLs.
Callers should inspect AlertAdmission: duplicate, capacityExceeded, invalidActions
or invalidConfiguration requests own no new callback.

## Semantics

- Timed notices and snackbars must be global and OK-only. Retry/Cancel recovery
  requests remain manual. Invalid combinations are rejected before queue ownership.
- Selecting OK, or a snackbar's Dismiss button, delivers `.ok` after removal.
  Expiry, reset and stop remove the notice without invoking a business action.
  Timeout never means consent, retry, authentication or flow completion.
- Timers use injected monotonic time, start only after actual native appearance,
  pause while the scene is inactive and resume remaining time on activation.
  Obsolete/cancelled sleeps cannot expire a later presentation.
- UIKit modal alerts begin their timer after completed native presentation.
  SwiftUI's owned host finishes before its nested UIAlertController appears, so
  timed SwiftUI alerts observe real native visibility before starting. This one
  cancellable observer checks every 20ms, with a five-second rendering deadline
  per activation attempt. A render failure removes only the informational notice.
- A modal alert pauses/hides an active snackbar. After owned alert cleanup, the
  same snackbar resumes with remaining time. Independent channels do not promise
  cross-channel FIFO; recovery modals retain priority.

## Navigation and ownership

Modal notices reuse AlertPresentation and the router's serialized native cleanup.
They keep the existing stack/feature modal and hold subsequent router commands
until dismissal finishes. Auto-expiry uses the same path as explicit cancellation.

Snackbars use SnackbarPresenter, one UIKit renderer for SwiftUI and UIKit origins.
Its scene-bound UIWindow stays above feature content, including sheets/full-screen
modals, and never becomes key. Hit testing accepts only the banner rectangle;
touches outside it go to the application window. There is no additional navigation
controller or independent stack. Navigation and feature modal presentation proceed
while a snackbar is visible. Its controller, window, timer and callbacks belong
only to SnackbarPresenter and are released when that notice ends.

Each channel uses AppAlertQueue with identity-checked completion and semantic
deduplication. Snackbars allow one active and four waiting requests, rejecting
newest overflow without evicting accepted notices. This does not consume the modal
queue's reserved recovery capacity. Global notices survive authorized flow/root
replacement; explicit application reset/stop cancel both channels. Existing Phone
Back policy remains owned by the router.

## Demo and verification

Home, Secondary, details, presented SwiftUI sheet and the XIB lab/full-screen
controller provide Timed UIKit alert, Timed SwiftUI alert, Timed snackbar and
Persistent snackbar controls. Existing manual alert buttons are unchanged. The
four UIKit controls are actual connected XIB buttons in the existing scroll view.

- NoticeTimerTests: deterministic foreground timing, stale cancellation, owner
  release and invalid recovery/duration admission. The initial portable suite
  passed 38 declarations; the user's focused native run passed all 8 declarations /
  10 cases, and those cases passed again in the full run.
- TransientNoticeTests: real renderers with a manual clock, feature modal/stack
  identity, manual-vs-expiry race, pause/resume, touch passthrough/non-key ownership,
  bounded FIFO/deduplication, reset/stop and protected Phone completion.
- Four new NavigationUITests methods cover timed UIKit/SwiftUI alerts from both
  UI technologies, manual snackbars during navigation/modal presentation, and
  automatic expiry above a feature sheet/full-screen controller.

All 8 TransientNoticeTests declarations / 17 cases and all four new UI workflows
below passed in the user's 21:14 full run, together with all other unit tests. Four
older recovery UI workflows failed at a final synthesized tap into the status bar.
The test-only visible-row / measured-center correction then passed all 37 UI
methods in the user's 21:46 rerun, including all six recovery cases. Unit source
and production source were unchanged after the 21:14 passing unit execution;
combined evidence covers 168 declarations / 268 cases across separate runs. There
is no claimed single post-correction full run. These feature UI methods passed:

```text
testTimedAlertsFromSwiftUIAndXIBReleaseNavigation
testPersistentSnackbarAllowsBackAndUIKitModal
testTimedSnackbarExpiresAboveSwiftUISheetWithoutDismissingIt
testTimedAlertAboveUIKitModalPreservesModalAndNextPush
```

Native build and feature execution succeeded on iPhone 17 / iOS 27.0 Simulator;
all 131 unit tests passed and the corrected UI suite passed all 37 methods in
separate user runs. A single post-correction full-scheme rerun is not claimed. Minimum-OS,
physical-device, VoiceOver, rotation, keyboard and OS-driven background/foreground
validation remain open. The initial portable run and partial typechecks are
separate from the later user-owned native evidence. See [Verification.md](Verification.md) for the exact record.
