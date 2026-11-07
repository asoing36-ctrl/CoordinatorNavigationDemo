# Navigation, deep-link, alert and lifecycle audit

Analysis-only, 2026-11-07; current working-tree baseline from [architecture-audit.md](architecture-audit.md). F-prefixed references point to that report's detailed findings. Source tracing establishes the stated request sequence; it does not substitute for animated Simulator execution.

## Current state machine

```mermaid
stateDiagram-v2
    [*] --> launching
    launching --> unauthenticated: start / Welcome root
    unauthenticated --> redeeming: accepted active intent
    authenticated --> redeeming: accepted active intent
    redeeming --> phoneAssociation: success and original session absent
    redeeming --> authenticated: success and original session present
    redeeming --> redeeming: unauthenticated failure / Retry
    redeeming --> unauthenticated: failed unauthenticated flow / Return
    phoneAssociation --> phoneAssociation: association failure / retry
    phoneAssociation --> authenticated: Associate success or Skip / Home root
    authenticated --> authenticated: push / Back / present / dismiss
    unauthenticated --> authenticated: explicit demo reset and seed
    authenticated --> unauthenticated: explicit demo reset
```

`AppFlow` (`Domain/Models/Models.swift:18`) is deliberately not the entire business state. `phoneAssociation` already has an authenticated SessionStore. `redeeming` can have either session condition. `authenticated` includes Home, secondary, details, pushed XIBs and modals. The actual screen/stack is read from UIKit via router metadata; it cannot safely be inferred from AppFlow alone.

Alert visibility is an independent UI dimension, outside AppFlow and the push stack. Administrative reset and terminal stop are lifecycle operations outside this enum. Reset can begin in any flow. A synchronous flow assignment can precede completion of an enqueued UIKit transition; diagnostic flow/current-route disagreement during that interval is not automatically invalid state.

## Unauthenticated redeem, traced against code

| Step | Code | Actual behavior |
|---|---|---|
| Accept URL | `App/AppCoordinator.swift:52–66` | All real/custom demo URLs parse into a business intent |
| Own transaction | `Core/DeepLinks/DeepLinks.swift:27–39`; `App/AppCoordinator.swift:73–84` | Processor sets active before callback; app captures original nil session and code |
| Show redeem | `Features/Redeem/RedeemCoordinator.swift:16–19` | Push status hosting controller with blocked Back |
| Resolve account | `Domain/UseCases/RedeemCredentialUseCase.swift:13–22` | Lookup; missing creates deterministic account; both paths login |
| Grant and update client | `:24–28`; `App/AppCoordinator.swift:95–102` | Actor returns credential snapshot; SessionStore applies result; result says onboarding is required |
| Push phone | `App/AppCoordinator.swift:121–136`; `Features/Onboarding/OnboardingCoordinator.swift:22–24` | Redeem coordinator released, its hosting controller remains beneath genuinely pushed phone XIB |
| Associate | `Features/Onboarding/OnboardingCoordinator.swift:26–43` | Loading gate; cancellable async repository call; failure stays; success invokes once-only completion |
| Skip | `:45–46` | Immediate once-only completion when not already loading/finished |
| Finish | `App/AppCoordinator.swift:127–132,138–144` | Release onboarding; install Home root; clear transaction; finish processor and start next waiting intent |

Expected settled stacks: `[welcome]` → `[welcome, redeem]` → `[welcome, redeem, phone]` → `[home]`. There is no modal phone, silent phone root or login-screen navigation to return to. The lower redeem controller remains a valid holding screen, even though its feature coordinator has finished.

On unauthenticated INVALID/EXPIRED/network failure, the active intent remains owned and error UI exposes Retry/Return (`App/AppCoordinator.swift:104–117`, `Features/Redeem/RedeemCoordinator.swift:21,34–37`). Retry reuses `originalSession` (`App/AppCoordinator.swift:75,92`); the actor's possible account history after a partial request does not turn this into an already-authenticated client flow. Return restores Welcome and explicitly finishes the failed intent (`App/AppCoordinator.swift:154–158`).

Skip is disabled while association is running (`Features/Onboarding/AssociatePhoneViewController.swift:38–40`, `Features/Onboarding/OnboardingCoordinator.swift:45`). That is the implemented double-transition policy; it does not make association mandatory because Skip is available before submission and after failure. Do not accidentally turn Skip into a Back/pop path when refactoring.

## Authenticated redeem, traced against code

The starting UserSession is captured when the processor starts this transaction, not when its URL was first queued (`App/AppCoordinator.swift:75`). The use case uses it directly and bypasses account lookup/create/login (`Domain/UseCases/RedeemCredentialUseCase.swift:9–11`). It grants into the existing mock account and returns updated credentials (`Data/Mock/MockBackend.swift:52–69`).

`SessionStore.apply` updates data; `finishAuthenticatedRedeem` makes no root/push/pop request (`App/AppCoordinator.swift:98,146–152`). Existing controller objects and any active modal remain. Home/Secondary/details/sheet observe the same SessionStore, so data-bearing views refresh. A navigation-only XIB does not display credentials; its lack of credential rows is not stale data.

| Before | Intent | After settled success |
|---|---|---|
| `[home]` | ADD-CRED | Same `[home]` controllers, additional grant |
| `[home, secondary]` | ADD-CRED | Same controller identities and stack |
| `[home, lab, details]` | supported authenticated code | Same stack, data updates |
| Any authenticated stack + credential sheet/full-screen lab | supported authenticated code | Same stack/modal, sheet observes updated credentials |

An invisible RedeemCoordinator is still allocated in this path (F05); that is presentation/lifecycle redundancy, not an extra pushed screen. Authenticated failures now retain the active intent and original session while a global Retry/Cancel alert waits or shows (`App/AppCoordinator.swift:104–115`). Retry reuses that context; Cancel finishes and advances the next business intent. The error surface is implemented (F16). The current native run has two failing URL error tests with second-launch evidence (F25), plus native SwiftUI warnings in other passing cases (F23/F24); ownership/lifecycle coverage remains incomplete (F17/F18). Inline status is supplementary, not the only feedback.

## Required business rules comparison

| Requirement | Assessment | Evidence / limit |
|---|---|---|
| Create or login while logged out | Satisfied by source and portable tests | Use case `:13–22`; backend `:32–50`; NEW/EXISTING tests |
| Preserve original auth context | Satisfied | AppCoordinator `:75,90–95`; use case `:6–11,27–28` |
| Phone only after flow's authentication | Satisfied | `needsPhoneAssociation` from original session; no phone on authenticated branch |
| Phone optional, genuinely pushed | Satisfied | Onboarding `:22–24,45–46`; lower controller retained in stack |
| No ordinary Back from phone | Satisfied by layered source policy, partly tested | Controller hides item; router/subclass/gesture guards |
| Associate/Skip both make Home root | Satisfied | App completion `:127–143`; UI/coordinator tests exist |
| No re-login/create for authenticated redeem | Satisfied | Use-case early session branch; actor metrics tests |
| No unnecessary authenticated stack reset | Satisfied by source; identity coverage should improve | Auth finish `:146–152`; F10 |
| Visible recoverable errors from any supported screen | Addressed in source; native acceptance incomplete | F16: shared global alert over top content/modal, remaining F17/F18 coverage |
| One active transaction and queued distinct links | Satisfied for current policy | Processor active held through phone/failure; capacity unbounded, F07 |
| Safe terminal lifecycle teardown | Incomplete API edge | F03: queued router command can survive stop |
| Universal Links entry-level support | Conditional, correctly documented | HTTPS parser + browsing activity; no domain/entitlement configured |

## Back and transition enforcement

`PolicyNavigationController` intercepts direct UIKit pop, popTo and popToRoot (`Core/Navigation/NavigationRouter.swift:32–45`). Router ordinary pop/popTo reject blocked current policy before queuing and again at execution (`Core/Navigation/NavigationRouter.swift:79–80,140–147`). Protected controllers hide the bar item; gesture recognizer is enabled/disabled from current top policy and stack count (`Core/Navigation/NavigationRouter.swift:173–177`) and has its own should-begin guard (`Core/Navigation/NavigationRouter.swift:209–211`).

On leaving a protected route through explicit stack replacement, new Home is allowed; ordinary subsequent pushes regain bar/gesture Back. Keeping the original UIKit gesture delegate is purposeful. Explicit replacement is coordinator authority to finish/reset, not an ordinary Back request; policy must not block it.

Commands are serialized with `transitioning` and a FIFO queue. UIKit `willShow`/`didShow` track both programmatic and user-initiated transitions; metadata is pruned against the actual resulting stack. `didShow` schedules draining after its delegate callback (`Core/Navigation/NavigationRouter.swift:181–191`). An interactive pop that cancels must leave metadata for the actual top controller; deterministic coverage is missing, F01.

The duplicate-route rule checks the whole stack at execution, so a destination already below top is ignored rather than popped-to (`Core/Navigation/NavigationRouter.swift:134–136`). That is explicit demo policy, not a duplicate identity bug. Do not change it to pop-to implicitly without deciding what that means for protected routes and history.

## Modal dimension

HomeCoordinator creates a hosting-controller page sheet with medium/large detents (`Features/Home/HomeCoordinator.swift:38–48`) and a full-screen lab XIB (`Features/Home/HomeCoordinator.swift:50–63`). XIB actions can dismiss then enqueue push or a different presentation. No new UINavigationController or SwiftUI NavigationStack is created.

The router tracks `presentedRoute` separately, uses UIKit presentation/dismissal completion, handles adaptive interactive dismissal/cancellation, rejects detached presentation and ignores an extra presentation while one is visible (`Core/Navigation/NavigationRouter.swift:152–168,193–207`). Root/stack replacement clears obsolete queued commands and queues dismissal before replacement (`Core/Navigation/NavigationRouter.swift:81–86`). A single gate covers these transition types; this is coherent for the demo but needs attached-window tests before simplification.

The user's earlier five UI failures prove an accessibility lookup defect, not failed presentation: the actual result hierarchy shows visible Done/title/stack elements with the same outer identifier. The local baseline removes that identifier and keeps leaf identifiers (`Features/Home/HomeCoordinator.swift:127–149`). A new real-UI regression checks them (`CoordinatorNavigationDemoUITests/NavigationUITests.swift:98–113`). That fix predates this audit; it was not made by the audit and is covered by a later completed 45-test pre-alert pass. That pass does not include the current alert feature.

## Complete URL lifecycle and concurrency policy

```mermaid
sequenceDiagram
    participant OS as Scene / demo URL
    participant P as Parser
    participant Q as Intent processor
    participant A as AppCoordinator
    participant U as Use case / actor
    participant N as Router / nav
    OS->>P: URL
    P->>Q: validated redeem intent
    Q->>A: set active, dispatch
    A->>A: snapshot original session
    A->>U: execute once
    OS->>P: another URL
    P->>Q: distinct intent waits; duplicate suppressed
    U-->>A: result
    alt originally unauthenticated
        A->>N: push protected phone
        Note over Q,A: active remains owned through retry / phone
        N-->>A: Associate success / Skip outcome
        A->>N: replace with Home
    else originally authenticated
        A->>A: update session data without stack change
    end
    A->>Q: finish active
    Q->>A: next intent; capture session now
```

Cold connection URLs/browsing activities (`App/AppDelegate.swift:22–24`), warm URL contexts (`App/AppDelegate.swift:49–51`) and browsing continuation (`App/AppDelegate.swift:52–55`) feed the same `receive` method. Background URL activation uses that scene delivery path; no separate scene-activation handler performs redemption. Simultaneous scene batches arrive as unordered Sets; FIFO means **processor submission order**, not an invented chronological ordering of the OS Set.

Parser uses URLComponents and rejects unsupported routes/hosts, userinfo, port, fragment, missing/duplicate/empty code, disallowed syntax or length. Backend validates supported code meaning separately. Unknown uppercase codes are not a parser error; they are recoverable backend errors. No navigation destination is encoded into AppIntent.

Active/pending duplicate suppression is local to the current queue. Re-delivery after completion is allowed and backend grants are idempotent for the same account/code. New links during phone wait until Associate/Skip, then start against the now-authenticated session. New links during a recoverable unauthenticated error wait until retry succeeds/phone completes or Return explicitly ends the flow. During reset, raw URLs defer until the environment is restored; this should be bounded and preferably validated, F07.

## Cancellation, invalid transitions and ownership

- Reset invalidates generation first, cancels/join redemption, stops children, clears intent state, resets the actor, restores/clears session and installs the chosen root (`App/AppCoordinator.swift:163–194`). Guards follow every await. Administrative caller cancellation deliberately does not leave a half-reset environment.
- Redeem results check cancellation/generation before use; phone results check cancellation/finished and report through a generation-checked app completion. Existing handlers are protected against duplicate Associate/Skip and obsolete UI callbacks.
- Reset cancels phone but does not await it. With current cancellation-aware actor commits no stale phone effect was shown. A noncooperative real backend requires explicit effect/cancellation semantics; generation checks only suppress UI application, not remote server effects.
- **Invalid terminal transition F03:** stop while phone push is queued → release coordinator → didShow drains phone. Pending router work needs explicit shutdown invalidation, distinct from ordinary reset/root replacement.
- **F16 status change:** authenticated failure now retains the intent until global Retry/Cancel. Source-side missing-feedback behavior is addressed; all spy-flow cases passed, but the two native error URL tests failed at the alert wait after another Launch (F25).
- AppCoordinator is effectively one-shot: `started` stays true after stop. Clarify that contract rather than silently adding restart behavior in a cleanup refactor.

No retain cycle was found in injected callbacks; parent/feature UI closures use weak captures. Main-actor observable/navigation ownership is consistent, and backend mutable state is actor-isolated. The missing evidence is staged lifecycle/interactive execution and deallocation testing, not a proven leaked coordinator.

## Prioritized navigation recommendations

1. Add real transition/cancellation evidence and OS delivery smoke tests (F01/F02/F09).
2. Verify the implemented authenticated error/alert recovery contract and specify terminal-stop semantics; keep F16/F03 lifecycle work narrow.
3. Bound incoming intent retention without losing active-flow ownership (F07).
4. Simplify child ownership and invisible presentation state only after those tests protect it (F04/F05/F06).
5. Improve compact phone layout separately (F13), preserving its Back policy and XIB.

See [improvement-plan.md](improvement-plan.md) for implementation acceptance criteria. No navigation change was performed during this audit.

## Global alert dimension and background policy

```mermaid
stateDiagram-v2
    [*] --> Queued: valid typed request
    Queued --> WaitingForActive: scene inactive
    WaitingForActive --> Queued: sceneDidBecomeActive
    Queued --> WaitingForStableUI: navigation or modal transition
    WaitingForStableUI --> Presenting: stable visible controller
    Presenting --> UIKitVisible: UIKit renderer
    Presenting --> AnchorWaiting: SwiftUI hosting child
    AnchorWaiting --> SwiftUIVisible: appeared and active and not cancelled
    UIKitVisible --> Dismissing: allowed action
    SwiftUIVisible --> Dismissing: allowed action
    Dismissing --> Finished: native window absent / cleanup
    Queued --> Cancelled: cancelAll
    Presenting --> Cancelled: reset or root replacement
    Dismissing --> Cancelled: callbacks invalidated by reset
    Finished --> [*]
    Cancelled --> [*]
```

The diagram describes intended and source-selected phases; there is not a single explicit phase enum in code. The window-absence completion criterion needs F18 validation, particularly before attachment and during detachment.

1. A view/XIB action reports intent through coordinator callbacks. AppCoordinator also creates error requests for unsupported URLs and authenticated redeem failures (`App/AppCoordinator.swift:52–59,104–115`). Payloads contain safe messages, not access codes or full URLs.
2. `AppAlertQueue.enqueue` coalesces equal semantic keys across active/pending entries (`Core/Alerts/AppAlert.swift:82–88`). Duplicate callbacks are discarded; different messages/styles can share a key. There is no callback guarantee for every submission.
3. SceneDelegate forwards activation/inactivation (`App/AppDelegate.swift:43–44`). Queue begins inactive, and an already-owned request remains owned through inactivation. iOS suspension is not bypassed.
4. Router drains navigation commands before waiting alerts, then discovers its own window's top controller (`Core/Navigation/NavigationRouter.swift:104–131`). Thus alerts are FIFO relative to alerts, not relative to business intents or all navigation commands.
5. UIKit uses an exact UIAlertController. SwiftUI attaches a noninteractive hosting child to visible content/current modal with native `.alert` (`Core/Alerts/AlertPresentation.swift:23–51`). Direct insertion into another UIHostingController.view is **runtime-warned as unsupported** (F23); this exact bridge must change while preserving native SwiftUI and XIB support. No second UIWindow/navigation stack is created.
6. A second scene check in SwiftUI state covers inactivation between request selection and anchor appearance (`Core/Alerts/AlertPresentation.swift:143–154`). Removing this gate merely because the queue has one would weaken the deferred-appearance case.
7. After selection, the renderer waits for its tracked native view to leave its window, then removes the anchor and invokes queue completion (`Core/Alerts/AlertPresentation.swift:55–116`). Router blocks ordinary pending navigation while this renderer exists. Weak task capture avoids an established cycle; a wrong/stale target could still cause a liveness problem, F18.
8. Queue clears active before invoking a valid callback, permitting safe reentrant enqueue (`Core/Alerts/AppAlert.swift:98–103`). Authenticated Retry starts the use case with the original session; Cancel ends this failed transaction without resetting the user's valid feature/modal.

### Cancellation scopes and invalid combinations

- **Global-vs-flow lifetime:** every `replaceStack` cancels all alerts, including unrelated pending/visible notices. Association completion followed by Home may discard a just-arrived unsupported-link notification (F20). This is documented policy, not a hidden runtime crash; decide whether durable global feedback must outlive that transition.
- **Request validity:** empty actions are accepted but provide no permitted callback action to clear ownership; repeated actions also enter both renderers (F19). Current factories avoid this, but the request API does not enforce it.
- **SwiftUI identity:** hierarchy discovery accepts a different visible controller without proving it is this alert; normal serial use reduces interference, but cleanup/next-command release require attached-window tests (F18).
- **Shutdown:** stop now cancels alerts, and disconnect releases scene owners (`App/AppCoordinator.swift:215–222`; `App/AppDelegate.swift:45–47`). The old pending-navigation queue edge F03 is still distinct; cancelling alert callbacks is not cancellation of router operations.
- **Observability:** feature modal metadata remains intact while an alert shows, which is correct. Diagnostics do not expose current/pending alert ownership and should be labeled accordingly or receive a safe read-only summary (F21).

### Runtime evidence and remaining checks

Seven new portable tests and three native spy tests passed. Of five new alert UI methods, three passed, two failed. The passing SwiftUI/XIB and modal methods recorded unsupported-containment and publication warnings (F23/F24). Authenticated Cancel/background Retry fail waiting for the alert; activities show a second Launch under app.open and hierarchies return to Home (F25). These runs do not prove preservation of the existing warm/background instance. The protected-phone method can also recreate its phone from --link, so its pass is weaker than an identity assertion.

Correct OS delivery tests before attributing these failures to the business queue. Cold connection URLs currently precede Debug --authenticated reset (`App/AppDelegate.swift:22–32`); define seed-before-delivery ordering for that test context. Normal warm handlers converge on receive and have no such launch reset. Hold a response until the scene is inactive, reactivate, and verify exactly one alert above the original controller. Add native anchor/dismissal cleanup tests, not another business pipeline.

The finalized current result is **58 passed / 2 failed** of 60 declarations (39 unit passed, UI 19 passed / 2 failed). All old sheet failures passed here. Keep assertion failures, runtime warnings, conditional lifecycle risks and the audit process's separate Simulator-access failure distinct.
