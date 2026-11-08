# Navigation contract and production validation

The new [timed notices](TimedNotices.md) feature preserves one authoritative
navigation controller. Modal timers use owned cleanup; a snackbar is a scene-bound
non-key overlay window with no routes/stack. Navigation continues under banners,
and recovery modals pause them. All 131 unit declarations passed, then all 37 UI methods passed after the test-only
recovery tap correction, on iPhone 17 / iOS 27.0 Simulator. Those are separate
user runs covering 168 declarations / 268 cases. Passing AUD-04 evidence below
belongs to baseline `e07e6f5`; no single post-correction full run is claimed.

The [AUD-04 error recovery matrix](plans/error-recovery-matrix.md) passed focused
and full user runs: **148 declarations / 237 expanded runs**, zero failures/skips/
recorded runtime warnings on iPhone 17 / iOS 27.0 Simulator. All 58 new component
cases and six native UI workflows passed, including the corrected selection and
held-metrics readiness assertions. It checks original stack/modal/controller
identity and ordinary navigation after cleanup. The NavigationRouting protocol,
scheduling, Back policy and alert behavior are unchanged; internal read access to
the existing owned alert presentation supports component testing. Native-button/
reset overlap and broader device/OS lifecycle validation remain separate gates.

This document describes the reusable navigation layer, independently of the demo account/credential flow. Swift 5, iOS 17, one UINavigationController and main-actor isolation remain the constraints.

The ownership/state simplification passed the user's focused/full runs: **110 unit + 27 UI = 137 declarations / 173 expanded runs**, zero failures/skips/recorded runtime warnings. AppCoordinator uses typed child owners and a transaction/recovery context independently of optional status UI; diagnostic snapshots/metrics cannot drive or hold routing. The router implementation and its policies are unchanged. See [the simplification plan](plans/navigation-simplification.md) and [Verification.md](Verification.md) for artifacts and limits. The verified revision and evidence are committed together at the user's request.

The bounded-queue/alert-lifetime revision passed the user's focused and full Simulator runs: **118 declarations / 136 expanded runs**, no failures/skips/recorded runtime warnings. The implementation and verification record are committed together after baseline `a9b7788`; see the [policy plan](plans/queue-and-alert-policy.md) and [verification evidence](Verification.md) for scope and remaining release gates.

The prior [lifecycle timing follow-up](plans/lifecycle-timing.md) passed all eight declarations / 16 expanded runs and its full baseline passed **99 unit + 27 UI = 126 declarations / 152 expanded runs**. Those lifecycle, queue lifetime-boundary and native-grabber sheet cases passed again in the simplification run. See [Verification.md](Verification.md). No router command, capacity or Back policy changes are part of these follow-ups.

## Authority and ownership

UIKit's viewControllers is the authoritative push stack. Route and Back-policy metadata describes those exact controller identities; it is retained until transitions finish because a cancelled pop can restore a temporarily removed controller. Feature-modal metadata is a separate presentation dimension, not another push stack.

The composition root owns the router and navigation controller. Coordinators submit commands through NavigationRouting. Do not replace the navigation delegate/gesture delegate or mutate viewControllers from feature code. UIKit's own Back actions are reconciled by the router; direct programmatic Back remains protected by PolicyNavigationController. SwiftUI content must not introduce a competing NavigationStack.

The fixed feature hierarchy uses typed properties as its only child owners; no UUID registry also retains them. A redeem transaction captures its original session and recovery eligibility independently of whether a screen is shown. Authenticated requests retain Home and the current controllers/modal. Recovery callbacks validate the transaction before retrying or completing it. Main-actor navigation decisions recheck validity after session/status publication, where synchronous observers may stop the flow.

NavigationDiagnostics is an immutable value projection from the real owners; UI consumers cannot mutate it or use it as stack authority. It publishes as one value, and session-only changes are read after the completed assignment. DemoModel owns separate coalesced metrics work; at most one read runs, with one pending refresh flag. Cancellation suppresses stale results without forcing navigation/reset to join a read-only diagnostic operation.

Controllers submitted for push/presentation must be detached from other containers/presenters/windows. Stack screens cannot be navigation/tab-bar/alert controllers. Replacement can reuse this stack's existing controllers or the router-owned modal after its queued dismissal. Ownership is revalidated at execution. Caller code must not reparent controllers while a queued request owns them.

## Operation semantics

| Command | Contract |
|---|---|
| push | Append a detached supported controller if its logical route is not already in the stack. Equal-route pushes are benign no-ops; they do not pop to an earlier screen. A controller cannot be reused under another route while already owned |
| pop / popTo | Respect the current Back policy at submission and execution; root/current-target requests are no-ops. Missing popTo destinations report rejection |
| replaceStack / setRoot | Explicit flow authority bypassing ordinary Back restrictions and capacity rejection. Validate first, clear obsolete waiting navigation, cancel flow alerts, finish the current transition and clean up the feature modal before nonanimated replacement. Global notices survive; an already visible global notice finishes first |
| present / dismiss | Serialize the feature-modal lifecycle independently of push/pop. A second presentation while a feature modal exists is rejected; dismiss then present is the explicit replacement sequence |
| cancelPendingNavigation | Release waiting commands/controllers. Do not cancel or pretend to finish UIKit's current transition. Later authorized requests remain usable |
| showAlert | Return typed AlertAdmission. Scope plus semantic key defines duplicates; invalid configurations and capacity rejection own no callback. Accepted user actions complete at most once |
| cancelAlerts | Administrative cancellation of every scope, including the exact owned native presentation. Used at reset/stop/disconnect |
| setSceneActive | Forward this scene's actual activity. Windowed push/pop/present/dismiss requests wait while inactive. Root setup/replacement without a modal remains available before activation. If modal cleanup is required, its dismissal and the replacement both wait for activation. Detached stack setup uses nonanimated operations |

Route equality is a product decision: equal values mean the same logical destination. The demo's small Route enum is an example. A consuming project must include stable entity/context identifiers where multiple detail destinations are valid and must choose push versus popTo explicitly. Do not use a single placeholder route for every entity.

Apple documents preconditions for [pushViewController](https://developer.apple.com/documentation/uikit/uinavigationcontroller/pushviewcontroller(_:animated:)). The router validates common invalid ownership/controller combinations before calling UIKit rather than relying on UIKit to throw, ignore, or complete an unsupported operation.

## Transition execution

The runner is iterative and non-reentrant. An observer may enqueue work, but it cannot start a new transition from inside a UIKit didShow notification. Adjacent equal-route pushes coalesce using first-wins semantics; intervening pop/dismiss/root operations prevent coalescing across a meaningful state change. Long synchronous no-op/rejection runs yield to the main queue in bounded batches without dropping accepted operations.

Visible nonanimated root replacements also own the navigation lifecycle. If the top changes, the router waits for [didShow](https://developer.apple.com/documentation/uikit/uinavigationcontrollerdelegate/navigationcontroller(_:didshow:animated:)); it additionally holds queued commands until the main queue returns from the display callback/replacement call. A replacement that reuses the same top reserves that turn without requiring a callback UIKit may omit. Detached stack construction remains synchronous. The application must not add delays between setRoot and push to compensate for router sequencing.

Navigation and presentation each own a completion flag. One dimension's callback cannot release the other's active transition. Stack changes beneath an existing modal are nonanimated; the router does not wait for an invisible navigation animation. User-driven completed/cancelled pops and adaptive modal dismissal use their UIKit lifecycle callbacks.

An accepted root replacement invalidates obsolete waiting navigation and flow alerts. Global notices remain owned or queued. It does not interrupt an active UIKit animation. With an inactive scene and a visible feature modal, dismissal/replacement waits for activation. With an active global modal notice, replacement additionally waits for its acknowledgment, configured expiry or explicit administrative cancellation. A global snackbar does not hold replacement. Stop/reset invalidates waiting navigation before cancelling every alert scope.

## Capacity, fairness and alert scope

| Owner | Default bound / policy |
|---|---|
| Router | 32 ordinary waiting slots, plus 2 slots usable only by blocked pushes in the single active protected flow; at most 34 waiting commands. Running transition is separate. Ordinary capacity is configurable, minimum 2 |
| Flow completion | Root replacement installs its complete at-most-two-command cleanup/replacement prefix before alert cleanup can resume the runner. It cannot be rejected because ordinary waiting work filled the queue |
| Business processor | 8 waiting plus 1 active intent. Duplicates precede capacity checks; reject newest distinct overflow. Original active authentication context is unchanged |
| Startup / reset staging | Each holds at most 8 distinct already-parsed intents, never raw URL arrays. Staging is storage, not reservation of business admission. Initial connection URLs precede live startup arrivals; handoff uses normal admission and generic overflow feedback. Whole batches enter the processor before callbacks can append newer work |
| Alert queue | 9 waiting plus 1 active; global notices may occupy at most 8 waiting slots, reserving one for flow recovery. Configurable total waiting bound, minimum 2 |

Default reservations fit this demo's single protected redeem/onboarding flow. A consuming application must size/adapt them for its own maximum outstanding protected commands. Capacity bounds retained entries, not arbitrary memory in controller payloads. Accepted queued work remains FIFO; explicit flow replacement/cancellation may invalidate obsolete work. Overflow rejects the newest request and releases its controller/callback references.

After at most 4 non-root navigation commands, the runner yields to an eligible waiting alert. Root replacement and its cleanup retain precedence. An active native transition, missing presenter or inactive scene still controls eligibility. A registered native transition completion reserves the yield; more navigation cannot overtake that callback. This is per-queue FIFO with explicit arbitration, not one global FIFO.

AppAlertScope.flow is the default lifetime, including authenticated Retry/Cancel recovery. Normal root replacement cancels those requests. Global notices are informational OK-only requests; demo, malformed-link and overflow notices survive normal flow completion. Global callbacks must not capture an obsolete business operation; use flow scope and generation guards for business recovery. Reset/stop/disconnect cancel both scopes. A rejected recovery request cannot be awaited: AppCoordinator preserves session/stack, reports generic capacity feedback and releases that intent.

## Rejection observability

The concrete router exposes an optional main-actor onRejectedNavigation callback with typed NavigationRejection values: invalidStack, unsupportedStackController, controllerInUse, presenterUnavailable, alreadyPresenting, routeNotFound and queueFull. AlertAdmission and IntentAdmission separately report accepted/duplicate/capacity outcomes; alert validation also reports invalidActions. No controller descriptions, URLs, codes or application payloads are emitted.

The production composition should record these safe reasons, distinguish integration mistakes from expected duplicates/policy no-ops, and define recovery at its own flow boundary. The callback is synchronous and is not a navigation-completion promise; keep handlers lightweight, capture owners weakly and do not blindly retry invalid input. Commands are asynchronous with respect to UIKit; immediate submission is not proof a destination became visible.

## Validation added in this phase

The native RouterLifecycleTests use the real stack in an attached window and public UIKit animators/interactive transitions. Assertions check actual transition engagement, exact restored controller identities and continued queue progress. Coverage includes cancelled interactive Back, restored protected Back, modal dismissal → push/present, root replacement during modal presentation, immediate pushes after new/reused visible roots, flow cancellation, observer reentrancy, invalid controller ownership, malformed replacement batches, repeated push bursts, long no-op queues, inactive-scene delivery and hidden-stack updates.

The UI suite adds a real edge-swipe check after leaving the protected flow, on both SwiftUI and XIB screens. Existing mixed-framework and deep-link tests remain intact. Shared native-window fixtures serialize access across suites and await actual appearance/cleanup.

LifecycleTimingTests holds credential/phone/startup operations at explicit suspension gates. It checks that reset joins cancelled business work before clearing the environment, stop cannot install obsolete destinations, old alert actions cannot affect a new transaction, global notices retain their lifetime across phone completion, and old scene startup cannot drain a new buffer. Scene connection accepts an owned composition and returns the startup Task; the system callback still decodes its original connection options. All eight declarations passed in the user's focused/full runs. The action-selection component test calls the same typed boundary as both renderer adapters before queued dismissal; it does not synthesize native auto-dismissal or prove OS gesture delivery.

## Production release gates

The user's latest full run passed **110 unit + 27 UI = 137 declarations / 173 expanded runs**, including the new ownership/metrics cases, existing lifecycle/queue cases and both completed/cancelled sheet UI cases. Focused simplification and diagnostics runs also passed. No failures/skips or recorded runtime warnings. The agent inspected completed results without building or running tests. See [Verification.md](Verification.md) for paths, earlier failures and native-fixture console diagnostics. These results do not establish flawless navigation for a large production population.

Before integration/release, require:

- Keep targeted native transition and full unit/UI execution as a regression gate with animations enabled and zero assertion failures. The current simplification revision passed on iPhone 17 / iOS 27.0 Simulator. Continue investigating the documented native-fixture console diagnostics.
- The minimum supported iOS 17 runtime and current supported iOS versions; representative physical iPhones/iPads, both size classes, rotation and accessibility settings. The existing verified baseline covered iPhone 17 / iOS 27.0 Simulator only.
- Repeated real completed/cancelled edge-back and sheet gestures, rapid alternating requests, foreground/background changes and scene disconnect during transitions. The controlled native tests complement real gestures; they do not replace device verification.
- Validate the tested queue, reservation, overflow feedback, alert lifetime and arbitration defaults against the consuming application's protected flows and workloads. Route identity/restoration, capacity tuning and measured memory/latency still require application-specific decisions.
- Long-session memory/latency profiling and appropriate CI regression gates. The baseline's UIKit locked-focus-environment diagnostics in native test fixtures remain documented; no leak or harmlessness conclusion was established.
- Production rejection metrics and a rollout/rollback strategy owned by the consuming project. No third-party telemetry service, persistence or generic routing framework is introduced by this demo.

The release criterion is evidence against these contracts and the real application's flows. There is no claim that a user-count target or a single green run proves the absence of defects.

The [baseline strict review](audits/navigation-strict-review-2026-11-07.md) found no confirmed correctness blocker in its earlier scope. The later policy review identified the queue-saturation/protected-push issue described in [the policy ledger](plans/queue-and-alert-policy.md); the reserved-capacity fix and both regression cases passed in user runs. Broader native gesture/OS teardown and audit acceptance remain incomplete; see [task-level status](audits/implementation-status.md).

The [validation follow-up](plans/navigation-validation-follow-up.md) passed its controlled callback/lifecycle tests in focused and full user runs. The cancellation fixture uses a real UIKit interactive transition with test-only adaptive callback forwarding, not a synthesized native sheet gesture. The scene fixture invokes a separate delegate's real disconnect callback and releases its own window, not the host's OS scene. These results do not establish native sheet-pan delivery, OS-driven teardown or production readiness. `9cddb39` is the committed earlier baseline; the follow-up is recorded with its latest passing verification evidence.
