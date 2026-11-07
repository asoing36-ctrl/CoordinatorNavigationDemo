# Global alert implementation

This feature adds native UIKit and native SwiftUI alerts to the existing single-stack app. It does not execute the audit's unrelated refactoring plan. Swift 5 / iOS 17 and actual XIB integration remain unchanged.

## Ownership and delivery

- `Core/Alerts/AppAlert.swift`: Sendable request/action/style values and a Foundation-only, main-actor FIFO queue. Keys are semantic constants and never include access codes/URLs. Active/pending duplicates are suppressed; completion validates request identity and allowed action. Cancellation discards callbacks. A completed request may be submitted again.
- `NavigationRouter`: owns alert presentation together with navigation transitions. Scene activity gates alert start, ordinary navigation waits while an alert is owned, and topmost presenter discovery starts from the router's own window/root rather than global UIApplication state. Root replacement cancels alerts before replacing feature screens.
- `Core/Alerts/AlertPresentation.swift`: one renderer lifetime. UIKit uses UIAlertController. SwiftUI uses `.alert` anchored in a hosting child of the visible content controller, never a child added to UINavigationController's managed stack. No extra window or navigation controller is created. Anchor cleanup happens only after native alert dismissal.
- `SceneDelegate`: forwards active/inactive state; disconnect stops the coordinator and releases scene owners. Native background suspension is respected; no background execution entitlement is added.
- `AppCoordinator`: owns business error outcomes. Authenticated failures retain the active intent/original session through Retry/Cancel. Reset/stop invalidate pending alert callbacks. No business code is executed inside the views or alert renderer.

The native SwiftUI API dismisses after the action runs. This implementation therefore checks the actual native presented controller leaving its window rather than immediately starting another UIKit transition in the button handler. The short dismissal monitor uses weak owner capture and cancellable Task.sleep; it is not a fixed delay that assumes dismissal succeeded. Presentation failures outside normal lifecycle/visibility remain an area for attached-window integration verification.

## Behavior

| Situation | Result |
|---|---|
| Request while scene inactive/backgrounded | Queued; no native alert starts until active |
| App becomes active | First distinct pending request presents over current stable destination |
| Request from SwiftUI or a XIB callback | Either renderer can be selected; screen technology does not choose presenter |
| Request while feature sheet/full-screen modal visible | Alert above it; user modal and underlying push stack survive acknowledgment |
| New request while alert visible | Distinct requests wait FIFO; same semantic key suppressed |
| Authenticated redeem failure | Global Retry/Cancel, same original session; no additional login or phone screen |
| Unauthenticated redeem failure | Existing visible redeem Retry/Return UI preserved |
| Invalid URL | Generic global unsupported-link alert; no sensitive URL/code included |
| Reset/disconnect | Queue/callbacks cancelled; obsolete request cannot resume an old flow |

The FIFO is in memory and unbounded for this small demo, like the existing intent queue. A production capacity/overflow policy remains a product decision; this feature does not silently drop critical errors. Error alert lifetime is separate from pushed route and feature-modal metadata. An alert does not become a navigation route.

## Demo and tests

Use Show UIKit alert / Show SwiftUI alert on the demo screens. The XIB lab has real connected buttons for both. The error-style picker controls global deep-link errors without changing the underlying destination.

Added tests:

- Seven portable `AppAlertQueueTests`: inactive buffer/activation, FIFO across styles, active/pending deduplication, valid/once-only completion, deactivation, cancel/stale callbacks and reentrant enqueue.
- Three `GlobalAlertFlowTests`: background-buffered authenticated error preserving details; SwiftUI-style Retry preserving session/modal with zero login; reset discarding a deferred alert.
- Five XCUITests: both styles over SwiftUI and XIB; both over sheets/full-screen modals; authenticated OS deep-link error over details; background URL activation with error Retry above full-screen XIB; and a global alert above protected phone without allowing Back.

Current verification results are recorded in `docs/Verification.md`. Native SwiftUI/UIViewController bridging, presentation animation and real OS activation must be executed on a working Simulator; build success or portable queue tests alone do not establish those behaviors.

Reference: Apple's native SwiftUI alert action/lifetime contract is documented at https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:actions:message:)-3rabc .

The background UI test uses Home then OS URL open, which reactivates the app. It tests real URL entry/foreground re-entry, not guaranteed backend completion during suspension. The inactive queue and flow unit tests establish buffering logically; only a controllable runtime scenario could demonstrate an actual response arriving while the scene remains inactive.
