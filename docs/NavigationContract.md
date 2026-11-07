# Navigation contract and production validation

This document describes the reusable navigation layer, independently of the demo account/credential flow. Swift 5, iOS 17, one UINavigationController and main-actor isolation remain the constraints.

## Authority and ownership

UIKit's viewControllers is the authoritative push stack. Route and Back-policy metadata describes those exact controller identities; it is retained until transitions finish because a cancelled pop can restore a temporarily removed controller. Feature-modal metadata is a separate presentation dimension, not another push stack.

The composition root owns the router and navigation controller. Coordinators submit commands through NavigationRouting. Do not replace the navigation delegate/gesture delegate or mutate viewControllers from feature code. UIKit's own Back actions are reconciled by the router; direct programmatic Back remains protected by PolicyNavigationController. SwiftUI content must not introduce a competing NavigationStack.

Controllers submitted for push/presentation must be detached from other containers/presenters/windows. Stack screens cannot be navigation/tab-bar/alert controllers. Replacement can reuse this stack's existing controllers or the router-owned modal after its queued dismissal. Ownership is revalidated at execution. Caller code must not reparent controllers while a queued request owns them.

## Operation semantics

| Command | Contract |
|---|---|
| push | Append a detached supported controller if its logical route is not already in the stack. Equal-route pushes are benign no-ops; they do not pop to an earlier screen. A controller cannot be reused under another route while already owned |
| pop / popTo | Respect the current Back policy at submission and execution; root/current-target requests are no-ops. Missing popTo destinations report rejection |
| replaceStack / setRoot | Explicit flow authority that bypasses ordinary Back restrictions. Validate nonempty unique route/controller identities before discarding waiting work; finish the current transition, dismiss the router's modal and install the new stack without animation |
| present / dismiss | Serialize the feature-modal lifecycle independently of push/pop. A second presentation while a feature modal exists is rejected; dismiss then present is the explicit replacement sequence |
| cancelPendingNavigation | Release waiting commands/controllers. Do not cancel or pretend to finish UIKit's current transition. Later authorized requests remain usable |
| setSceneActive | Forward this scene's actual activity. Windowed push/pop/present/dismiss requests wait while inactive. Root setup/replacement without a modal remains available before activation. If modal cleanup is required, its dismissal and the replacement both wait for activation. Detached stack setup uses nonanimated operations |

Route equality is a product decision: equal values mean the same logical destination. The demo's small Route enum is an example. A consuming project must include stable entity/context identifiers where multiple detail destinations are valid and must choose push versus popTo explicitly. Do not use a single placeholder route for every entity.

Apple documents preconditions for [pushViewController](https://developer.apple.com/documentation/uikit/uinavigationcontroller/pushviewcontroller(_:animated:)). The router validates common invalid ownership/controller combinations before calling UIKit rather than relying on UIKit to throw, ignore, or complete an unsupported operation.

## Transition execution

The runner is iterative and non-reentrant. An observer may enqueue work, but it cannot start a new transition from inside a UIKit didShow notification. Adjacent equal-route pushes coalesce using first-wins semantics; intervening pop/dismiss/root operations prevent coalescing across a meaningful state change. Long synchronous no-op/rejection runs yield to the main queue in bounded batches without dropping accepted operations.

Visible nonanimated root replacements also own the navigation lifecycle. If the top changes, the router waits for [didShow](https://developer.apple.com/documentation/uikit/uinavigationcontrollerdelegate/navigationcontroller(_:didshow:animated:)); it additionally holds queued commands until the main queue returns from the display callback/replacement call. A replacement that reuses the same top reserves that turn without requiring a callback UIKit may omit. Detached stack construction remains synchronous. The application must not add delays between setRoot and push to compensate for router sequencing.

Navigation and presentation each own a completion flag. One dimension's callback cannot release the other's active transition. Stack changes beneath an existing modal are nonanimated; the router does not wait for an invisible navigation animation. User-driven completed/cancelled pops and adaptive modal dismissal use their UIKit lifecycle callbacks.

An accepted root replacement invalidates obsolete waiting navigation and alert requests. It does not interrupt an active UIKit animation. With an inactive scene and a visible modal, the entire dismissal/replacement sequence waits for activation; the router does not dismiss the modal in the background merely to replace the root. Stop/reset invokes waiting-command invalidation before cancelling alerts, so alert teardown cannot drain old routes.

## Rejection observability

The concrete router exposes an optional main-actor onRejectedNavigation callback with typed NavigationRejection values: invalidStack, unsupportedStackController, controllerInUse, presenterUnavailable, alreadyPresenting and routeNotFound. No controller descriptions, URLs, codes or application payloads are emitted.

The production composition should record these safe reasons, distinguish integration mistakes from expected duplicates/policy no-ops, and define recovery at its own flow boundary. The callback is synchronous and is not a navigation-completion promise; keep handlers lightweight, capture owners weakly and do not blindly retry invalid input. Commands are asynchronous with respect to UIKit; immediate submission is not proof a destination became visible.

## Validation added in this phase

The native RouterLifecycleTests use the real stack in an attached window and public UIKit animators/interactive transitions. Assertions check actual transition engagement, exact restored controller identities and continued queue progress. Coverage includes cancelled interactive Back, restored protected Back, modal dismissal → push/present, root replacement during modal presentation, immediate pushes after new/reused visible roots, flow cancellation, observer reentrancy, invalid controller ownership, malformed replacement batches, repeated push bursts, long no-op queues, inactive-scene delivery and hidden-stack updates.

The UI suite adds a real edge-swipe check after leaving the protected flow, on both SwiftUI and XIB screens. Existing mixed-framework and deep-link tests remain intact. Shared native-window fixtures serialize access across suites and await actual appearance/cleanup.

## Production release gates

The user's targeted rerun passed **22/22 router declarations** (24 expanded runs). The subsequent full rerun passed **71 unit + 26 UI declarations = 97**, with **111 expanded runs**, no failures/skips and zero recorded runtime warnings. Both prior root-replacement failures and both immediate-push regression variants passed. The agent inspected existing results without building or running tests. See [Verification.md](Verification.md) for bundle paths and remaining native-fixture console diagnostics. A Simulator pass alone does not establish flawless navigation for a large production population.

Before integration/release, require:

- Keep targeted native transition and full unit/UI execution as a regression gate with animations enabled and zero assertion failures. The current iPhone 17 / iOS 27.0 Simulator gate passed; continue investigating the documented native-fixture console diagnostics.
- The minimum supported iOS 17 runtime and current supported iOS versions; representative physical iPhones/iPads, both size classes, rotation and accessibility settings. The existing verified baseline covered iPhone 17 / iOS 27.0 Simulator only.
- Repeated real completed/cancelled edge-back and sheet gestures, rapid alternating requests, foreground/background changes and scene disconnect during transitions. The controlled native tests complement real gestures; they do not replace device verification.
- Explicit route-identity, existing-destination, modal, restoration and overflow policies for the consuming application. Distinct requests remain an unbounded in-memory FIFO; bounded backlog/overflow handling and profiling are still requirements to settle before shipping, not claimed fixes here.
- Long-session memory/latency profiling and appropriate CI regression gates. The baseline's UIKit locked-focus-environment diagnostics in native test fixtures remain documented; no leak or harmlessness conclusion was established.
- Production rejection metrics and a rollout/rollback strategy owned by the consuming project. No third-party telemetry service, persistence or generic routing framework is introduced by this demo.

The release criterion is evidence against these contracts and the real application's flows. There is no claim that a user-count target or a single green run proves the absence of defects.

An [independent strict review](audits/navigation-strict-review-2026-11-07.md) found no confirmed correctness blocker within this integration contract. Its P2 validation gap is proving actual interactive sheet-cancellation engagement; disconnect/release and broader callback reentrancy coverage also remain incomplete. The broader audit plan is not fully implemented; see [task-level status](audits/implementation-status.md).
