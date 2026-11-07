# Redundancy and simplification analysis

Analysis-only, 2026-11-07. References use the same dirty working-tree baseline as [architecture-audit.md](architecture-audit.md). Finding IDs refer to its full evidence/priority register. No item below authorizes deletion or refactoring during this audit.

## What is actually redundant

| Area / evidence | Overlap | Smallest worthwhile change | Benefit / rough scale | Regression risk and test gate |
|---|---|---|---|---|
| F04: `App/AppCoordinator.swift:8,10–12,61–64,109–157,200–206`; `Core/Navigation/Coordinator.swift:3–6` | Three typed strong child slots plus UUID-keyed strong dictionary | Make typed slots the sole owners; derive a diagnostic/test child summary if needed. Remove registry IDs only when their usages are gone | About 15–30 lines of bookkeeping and one lifecycle invariant removed; four per-coordinator UUIDs may become unnecessary | Medium: child must survive until completion; weak-release tests and existing child-count/flow tests first |
| F05: `App/AppCoordinator.swift:66–88`; `Features/Redeem/RedeemCoordinator.swift:12–19` | Invisible coordinator/model/callback lifecycle for authenticated redeem, although AppCoordinator already owns its Task | Instantiate the presentation coordinator only for unauthenticated status/retry UI; let an explicit transaction context own the work | Removes an allocation/retention path and `showScreen` mode, not necessarily many lines; reduces false active-coordinator diagnostics | Medium: original session snapshot, error response and next-intent advancement must remain correct; authenticated success/failure tests |
| F06: `Features/Demo/DemoViews.swift:7–16`; `App/AppCoordinator.swift:189–198` | Nine independently published diagnostic mirrors, plus the metric (ten total), copy data from owners | One read-only typed diagnostic snapshot and one refresh assignment; keep actual input/status/reset state separate | Collapses ten observable copies into one value and centralizes formatting/ownership; no measured frame-time claim | Low/medium: observe after UIKit delegate completion, modal swipe, reset and credential update |
| F08: `App/AppCoordinator.swift:14–15,26–28,92,149–175` | App coordinator knows business repository construction and concrete mock admin/metrics | Inject existing use case/repository separately from reset/seed administration; keep composition explicit | Better controlled tests and clearer dependency direction; may initially add a few constructor lines | Medium: do not move reset across cancellation/join boundaries or enlarge repository with admin-only methods |
| F15: `Features/Redeem/RedeemCoordinator.swift:5,33` | Constant progress text is mutable published state | Immutable localized copy | One unnecessary observable property removed; tiny change | Low: build + loading/retry UI smoke |
| `Domain/Models/Models.swift:10–16`; `Domain/UseCases/RedeemCredentialUseCase.swift:27–28` | Eligibility Boolean can currently be derived from authentication outcome | Optional computed eligibility, with invariant tests; alternatively keep explicit documented outcome | Removes one representational invariant, little complexity saving | Medium if future login outcomes have different onboarding rules. Keeping it explicit is defensible |
| `App/AppCoordinator.swift:16–24`; `Features/Onboarding/OnboardingCoordinator.swift:15–17` | Finished Task handles and multiple lifecycle flags | Clear finished handles if it makes ownership clearer; document one-shot stop/start semantics. Consider a tiny lifecycle enum only if illegal states become a real problem | Readability, not proven memory savings | Low/medium: avoid changing cancellation/reset behavior just to remove booleans |
| `Features/Onboarding/AssociatePhoneViewController.swift:22–23`; router `Core/Navigation/NavigationRouter.swift:94,133` | Phone controller and router both hide bar Back | Optional removal of controller's visual duplication only after router-level creation tests | One line; low value | Low: keep actual blocked policy and direct UIKit/gesture enforcement |

Estimates are engineering judgments, not measured complexity metrics. The core ownership/presentation/diagnostic simplifications are likely a **net 20–50 production lines** removed after useful test seams are added, with a larger reduction in independent invariants. Added integration tests will increase total repository size; that is a worthwhile trade. Do not promise a percentage reduction or performance gain without measurement.

## Similar code that should remain separate

### Coordinator hierarchy

Redeem presents status/retry/Return; onboarding owns a cancellable phone operation and once-only completion; Home configures authenticated pushes/modals. These are not interchangeable coordinators. Merging them merely moves distinct lifecycle rules into one object. The AppCoordinator has no references between unrelated feature coordinators and callbacks are weak. Keep these boundaries; remove only the authenticated invisible presentation path.

A no-op `HomeCoordinator.stop()` (`Features/Home/HomeCoordinator.swift:63`) is an explicit conformance/lifecycle contract, not proof the coordinator is useless. A default protocol no-op could shorten code but also conceal future cleanup; this is lower value than removing the duplicate registry. No abstract base coordinator or generic child framework is recommended.

### The router's repeated checks

`NavigationRouting.pop/popTo`, queued execution and `PolicyNavigationController` each check policy (`Core/Navigation/NavigationRouter.swift:31–41,74–75,97–104`). The entry check prevents a blocked request entering the queue; the execution check catches policy changes while it waits; the subclass closes direct UIKit calls. The gesture delegate handles a fourth entry path (`:166–168`). Removing them as DRY duplication would weaken behavior.

`metadata[ObjectIdentifier]` and `Route` prevent different problems: identity-to-policy reconciliation versus duplicate semantic destinations. `routes` is computed from UIKit. `presentedRoute` is not a parallel push stack. Keep both push/modal dimensions and delegate reconciliation.

`setRoot` delegates to `replaceStack`; push helpers delegate to one queue. The code is already consolidated. `popTo` and explicit `replaceStack` are sparsely used by the demo but were requested capabilities and are exercised by tests. They are not dead API. Do not replace the small protocol with a generic `perform(route)` dispatcher to save a few methods.

### Deep-link layers

| Layer | Distinct value | Keep / change |
|---|---|---|
| URLComponents parser | Input validation and trust boundary, no navigation | Keep pure; extend boundary tests |
| AppIntent | Business meaning without controller instructions | Keep typed case |
| DeepLinkProcessor | One active intent, FIFO waiting intents, active/pending de-duplication | Keep state owner; bound capacity if required |
| AppCoordinator | Captures pre-operation session, chooses global flow and session transition | Keep orchestration |
| RedeemCoordinator | Status UI only | Keep when a screen exists; avoid treating it as a business pipeline layer |
| RedeemCredentialUseCase | Account resolution/create/login/grant sequence independent of UIKit | Keep business boundary |
| CredentialRepository / MockBackend | Async test seam and actor-backed deterministic server behavior | Keep; no service locator required |

The real successful path is parser → typed intent → processor → AppCoordinator → use case, with RedeemCoordinator as an optional **UI branch**, not another transformation required to execute business work. The demo injection builds a URL to exercise the same parser (`App/AppCoordinator.swift:55–59`); that round trip is intentional testing/demo behavior, not a reason to bypass validation for OS delivery.

### Session and backend data

Actor account/credential storage and SessionStore's client snapshot are separate authorities at different boundaries. They are not duplicate writable global stores. The store computes permission union, and views observe it. Do not remove the store and have SwiftUI call an actor synchronously, or cache a second independent permission set.

`originalSession` is not redundant with `SessionStore.session`: the latter changes after authentication, while the former must remain the operation's starting context across retries. Task-local copies are deliberate snapshots across suspension. Removing them recreates the phone-eligibility bug the architecture was designed to prevent.

### UIKit/SwiftUI bridges

A hosting controller for each genuinely new SwiftUI screen is appropriate. There is no `UIViewControllerRepresentable` chain to remove. Home's XIB factories for pushed versus full-screen lab differ in dismissal behavior and style (`Features/Home/HomeCoordinator.swift:30–60`). A tiny local constructor helper is optional, but a configurable builder/factory protocol would cost more than the repetition. Similarly, three repeated dismiss-then-action closures are readable examples of the router queue; do not introduce a generic navigation action framework.

The root container is purposeful: it prevents diagnostics from becoming a managed navigation child. Removing it would regress the earlier white-screen fix. Keep real XIBs and initializer injection, including required `init(coder:)` implementations.

## Dead-code and indirect-usage review

No whole application source file or major abstraction was proven unused.

| Candidate | Usage evidence | Conclusion |
|---|---|---|
| `AppDelegate`, `SceneDelegate` | `@main`, configuration delegate class, Info.plist scene delegate (`App/AppDelegate.swift:3–6`; `App/Info.plist:32–45`) | Runtime entry points; keep |
| Phone outlets / private IBAction methods | XIB owner connections; controller selectors at `Features/Onboarding/AssociatePhoneViewController.swift:43–44` | Runtime selector usage; keep |
| Lab present/dismiss actions | XIB connections; controller `:29–32`; full-screen coordinator closures | Runtime selector usage; keep |
| `required init?(coder:)` | UIViewController required initializer; intentionally rejects unsupported construction | Keep; not unused optional factory |
| `popTo`, direct popToRoot override | Required router capability/direct UIKit defense; unit policy exercise | Keep, add positive/direct path tests |
| `waitForOperation` methods | Coordinator tests use them (`CoordinatorNavigationDemoTests/ArchitectureTests.swift:17,34,46,60–66`) | Test-facing synchronization; not dead production logic. Could later move synchronization to a testable dependency boundary |
| `BackendMetrics.createdCount/phoneAssociationCount` | Domain tests assert them (`CoordinatorNavigationDemoTests/DomainTests.swift:36,78,85`) | Meaningful tests/demo support; keep |
| `CredentialDetailsView`, `.labDetail` route | Multiple real UI action closures (`Features/Home/HomeCoordinator.swift:25–35,49–57,156–164`) | Required mixed navigation; keep |
| `RedeemViewModel.message` | Read at `Features/Redeem/RedeemCoordinator.swift:33`, no later writes | Mutable observation is redundant; text itself is used |
| `Coordinator.id` / AppCoordinator.id | Child registry uses feature IDs; root ID is only protocol ceremony | Only remove together with retention redesign, not independently |
| `Package.swift` | Deliberate host-only verification when Simulator unavailable | Keep optional; it is not a native project dependency or generator |
| App icon/XIB resources | Native PBX resources, Info.plist icon compilation, successful build | Keep; not unused because Swift has no direct filename reference for every asset |

`.build`, DerivedData, personal workspace/user data and result bundles are generated/local artifacts. They are excluded from source review and should not be published as application code. Existing untracked workspace files were left untouched.

## Observation and performance trade-offs

`AssociatePhoneViewController` subscribes to `objectWillChange` and schedules a main-actor render (`Features/Onboarding/AssociatePhoneViewController.swift:29–41`). Deferring a read until after mutation matters because will-change publishes before assignment. Do not replace it with an immediate read solely to remove a Task. A single immutable phone render state with one publication could reduce redundant tasks, but this is optional without a measured issue.

Likewise, `SessionStore.apply` publishes session and credentials separately (`Core/Session/SessionStore.swift:8–10`). Current main-actor flow does not rebuild navigation from either publisher. An atomic client snapshot would clarify observation if future subscribers require it; it is not evidence of a current authentication/navigation defect. Keep Combine/ObservableObject: it bridges existing UIKit observation cleanly. Migrating to iOS-17 Observation is available but not automatically simpler for this mixed stack.

## Recommended consolidation sequence

1. Add the minimum existing-protocol injection alongside gated cancellation fixtures (F08/F02).
2. Establish real transition and staged cancellation tests (F01/F02).
3. Define error and terminal-stop contracts, then address F16/F03 without changing unrelated navigation.
4. Choose one child-retention owner (F04).
5. Remove the invisible authenticated redeem UI coordinator (F05).
6. Consolidate diagnostics as a read-only value (F06), preserving source ownership.
7. Apply tiny constant/formatting cleanups (F15) only alongside relevant feature work.
8. Leave optional computed eligibility/lifecycle enums/factories alone unless their benefits exceed their transition risk.

See [improvement-plan.md](improvement-plan.md) for acceptance criteria, dependencies, risks and required tests. No Swift upgrade, deployment-target change, dependency addition or XIB-to-SwiftUI migration is part of the proposal.
