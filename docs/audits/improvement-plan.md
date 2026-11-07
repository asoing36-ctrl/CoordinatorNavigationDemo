# Incremental architecture improvement plan — alert-aware revision

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement an approved phase task-by-task; use superpowers:subagent-driven-development only if that execution method is chosen. Steps use checkbox (`- [ ]`) syntax. This document is a proposal, not authorization to implement during the audit.

**Goal:** Preserve all required mixed-UI/navigation/business behavior while reducing duplicated bookkeeping and improving lifecycle/error reliability and test evidence.

**Architecture:** Keep one UIKit navigation stack, one protocol router, AppCoordinator and the three feature coordinators, a main-actor SessionStore, pure parser/typed intent queue, redeem use case and actor repository. Simplify ownership and diagnostic mirrors; use existing dependency seams before adding abstractions.

**Tech stack:** Swift 5 language mode, iOS 17+, SwiftUI, UIKit/XIB, Swift Concurrency, Swift Testing and XCTest/XCUITest; no third-party dependencies.

**Spec:** [architecture-audit.md](architecture-audit.md) findings F01–F25, [navigation-flow-audit.md](navigation-flow-audit.md) required-behavior comparison, and [test-coverage-matrix.md](test-coverage-matrix.md).

## Global constraints

- Do not upgrade Swift or raise the minimum iOS deployment target.
- Do not remove either real XIB or introduce a competing navigation stack.
- Preserve pre-redeem authentication context across retry and deferred processing.
- Phone is optional, pushed, protected from ordinary Back, and completed only by Associate/Skip.
- Authenticated grants preserve session, existing controllers and valid modal state.
- No additional login/create for an authenticated grant; no data-based automatic root rebuilding.
- Never log URLs, access codes, real tokens or account secrets.
- No generic routing/coordinator framework, service locator or speculative package.
- Keep changes isolated by task; preserve unrelated local project/workspace changes.
- Runtime assertions require actual execution. A successful build cannot close a UI regression ticket.

## Review focus

1. An intent result arrives while an earlier navigation animation is still pending.
2. Reset/stop occurs after a backend operation entered a stage, including a noncooperative completion.
3. An authenticated error occurs on details/XIB or an already-presented modal, not just Home.
4. A sheet or pop gesture actually engages and then cancels; the queue must continue.
5. Additional links arrive during phone, recoverable error and reset; active ownership, ordering and bounded overflow must be explicit.

Each condition is assigned tests below. Definitions: S ≈ 1–3 focused engineering hours; M ≈ half to one day; L ≈ one to two days. These are estimates with a functioning Simulator, not commitments. UI stabilization and product decisions may change them.

## Phase 0 — Establish evidence before simplifying

### AUD-01 — Reconcile baseline and run the real suites

- **Priority:** P1; **findings:** F01/F14 and known historical sheet failure; **effort:** S.
- **Files:** `CoordinatorNavigationDemoTests/*.swift`, `CoordinatorNavigationDemoUITests/NavigationUITests.swift`, `docs/Verification.md`; no production change expected.
- **Dependencies:** none; working Simulator access is required to complete runtime acceptance.
- **Approach:** keep the local sheet-identifier fix and regression as baseline. Run the full 39-unit/21-UI declaration set in Debug, record actual failures and expanded parameter counts separately. If a new result fails, investigate it rather than loosen assertions. Preserve the earlier 39-pass/5-fail record and the later completed 45-pass pre-alert record as history. The newly finalized 11:39 run is the current **58-pass/2-fail** baseline (39 unit passed, UI 19/21). Preserve its two alert-wait failures and F23/F24 runtime warnings; do not erase them with old passes.
- **Risks:** confusing the old result bundle with a post-fix run; publishing machine-specific logs or fixture secrets.
- **Acceptance criteria:** one current status block identifies source revision, toolchain, destination, declaration counts and exact failed tests; every UI pass claimed has an xcresult execution. Unavailable execution is explicitly blocked, not passed.
- **Tests required:** existing full native suites and optional portable subset.
- [ ] Inspect current dirty changes and prior xcresult; run baseline commands from the matrix.
- [ ] Record failures without changing navigation to satisfy the audit.
- [ ] Commit only approved baseline/test-documentation changes after results are reviewed.

### AUD-02 — Install deterministic business suspension seams and cancellation tests

- **Priority:** P1; **findings:** F02/F08; **effort:** L.
- **Files:** `App/AppCoordinator.swift`, `Core/DependencyInjection/AppComposition.swift`, `Domain/Repositories/CredentialRepository.swift` only if an existing signature truly blocks the seam; `CoordinatorNavigationDemoTests/TestSupport/ControllableCredentialRepository.swift`, `CoordinatorNavigationDemoTests/ArchitectureTests.swift` and `CoordinatorNavigationDemoTests/DomainTests.swift`.
- **Dependencies:** AUD-01's baseline classification; no new generic DI layer.
- **Approach:** inject a prebuilt redeem use case / existing `CredentialRepository` for business operations. Keep mock reset/seed administration explicit at composition; do not add those methods to the domain repository. Test utilities wrap the real actor or implement the existing protocol with async stage gates. Gate backend entry, not wall-clock time. Keep reset's generation and administrative cancellation semantics while testing them.
- **Interfaces:** consumes `CredentialRepository` and `RedeemCredentialUseCase.execute(code:session:)`; produces an installable controlled repository in tests, without replacing the app's explicit composition.
- **Risks:** mismatching the repository used by redemption/phone with mock admin state; changing reset's sequencing or pre-auth context.
- **Acceptance criteria:** tests demonstrate work entered each selected stage before reset/stop/cancel, release that work, and observe no obsolete client navigation/session application. Clearly distinguish UI result suppression from server-effect cancellation. Current mock remains deterministic.
- **Tests required:** `resetAfterAccountCreationIgnoresLateResult`, `resetAfterLoginDoesNotShowPhone`, `resetDuringRedemptionPreservesNewEnvironment`, `stopDuringPhoneIgnoresCompletion`, `urlsDuringResetDispatchAfterRestore`, duplicate phone submissions and weak deallocation. Include a noncooperative response to pin the client guarantee without pretending it can undo server effects.
- [ ] Add gated tests and observe their actual baseline behavior.
- [ ] Add only the constructor seam needed to run those tests; retain meaningful boundaries.
- [ ] Run the full unit suite and representative native UI flows; review and commit separately.

### AUD-03 — Add attached-window router integration coverage

- **Priority:** P1; **findings:** F01/F11; **effort:** L.
- **Files:** `CoordinatorNavigationDemoTests/RouterIntegrationTests.swift`, `CoordinatorNavigationDemoTests/TestSupport/RouterWindowHarness.swift`, `CoordinatorNavigationDemoTests/ArchitectureTests.swift`; native PBX test-source membership if a new file is used.
- **Dependencies:** AUD-01; independent of registry cleanup. Minimal production transition observability may be considered only if actual UIKit completion cannot otherwise be observed.
- **Approach:** attach the real router/nav to a test window; preserve/restore the host's window state. Use public delegate/transition completion and expectation-based synchronization, not sleeps, private UIKit APIs or a second production router. Keep RouterSpy for asserting coordinator requests.
- **Risks:** test windows interfering with parallel tests; disabling animation would bypass the feature under test.
- **Acceptance criteria:** tests prove a transition engaged, subsequent commands waited, and actual resulting controllers/modal match after completion/cancellation. The harness tears down its window and releases controllers.
- **Tests required:** queued push/push, duplicate queued push, allowed/protected pop and direct popTo/popToRoot, metadata after user Back/cancelled interactive pop, dismiss→push, modal swipe/cancel→next command, replacement during presentation, normal edge swipe after onboarding. Known stop defect is reproduced/fixed in AUD-05, not suppressed here.
- [ ] Write expectations for currently intended transition behavior and run attached-window tests.
- [ ] Separate coordinator intent assertions from router execution assertions.
- [ ] Run integration and UI tests; record any newly discovered defect as a specific follow-up.

## Phase 1 — Resolve narrow behavioral gaps

### AUD-04 — Verify and complete the implemented global error acceptance matrix

- **Priority:** P2; **finding:** F16 addressed in source, F17 verification open; **effort:** M.
- **Files:** `CoordinatorNavigationDemoTests/ArchitectureTests.swift`, `CoordinatorNavigationDemoUITests/NavigationUITests.swift`, test utilities; existing implementation in `App/AppCoordinator.swift` and `Core/Alerts` is the starting point, not a missing system to recreate.
- **Dependencies:** AUD-01/AUD-02 and AUD-14 for real renderer evidence.
- **Implemented contract:** authenticated errors request one global Retry/Cancel alert. The active intent/original session is retained through Retry; Cancel ends it and advances distinct queued work. Unauthenticated Retry/Return remains on the existing screen. Do not add another error presentation framework.
- **Remaining approach:** strengthen three current spy-flow cases into the required matrix, then execute representative native rendering cases. Alter production behavior only for a demonstrated failure and keep each correction narrow.
- **Risks:** retrying against updated rather than original authentication; cancel losing queued work; renderer cleanup removing the user's valid modal; silently reintroducing error loss.
- **Acceptance criteria:** INVALID/EXPIRED/NETWORK-FAIL on Home, Secondary, details, XIB and current modals produce the chosen contract, preserve controllers/session/credentials/permissions, and perform no login/create/phone. Repeated Retry failure is handled and Cancel allows the next intent. Current scene gating and stale callback suppression are proven at their actual layer.
- **Tests required:** current GlobalAlertFlowTests plus exact state/identity snapshots; error family/destination cases; distinct queued intent after Cancel; stop/reset after native action selected; both renderer styles in representative native UI tests.
- [x] Shared source-side error contract exists (prior feature work, not this audit).
- [ ] Add remaining assertion/case coverage and execute the current suite.
- [ ] Address only demonstrated lifecycle defects; record real runtime results.

### AUD-05 — Invalidate queued navigation when the app flow stops

- **Priority:** P2; **finding:** F03; **effort:** M.
- **Files:** `App/AppCoordinator.swift`, `Core/Navigation/NavigationRouter.swift`, router protocol/spy and attached-window tests.
- **Dependencies:** AUD-03 (reproducible animated queue).
- **Approach:** define terminal stop's screen/ownership contract, then add explicit pending-command invalidation. Let an in-progress UIKit transition finish and reconcile; prevent its completion from draining obsolete commands. A generation on queued flow work or a small pending-clear operation is sufficient; do not replace UIKit's delegate lifecycle.
- **Risks:** clearing newly authorized replacement work or leaving `transitioning` stuck; suppressing valid Associate/Skip completion.
- **Acceptance criteria:** a phone command queued behind redeem cannot execute after stop; no dead feature callback/controller retained solely by a stale queue. Normal reset and flow completion continue to work.
- **Tests required:** `stopDiscardsPhoneQueuedBehindRedeem`, stopped modal/pending push variant, current-transition cancellation, ordinary completion and reset still drain authorized commands.
- [ ] Reproduce the edge with real attached router and a held transition.
- [ ] Implement invalidation and keep actual transition reconciliation.
- [ ] Verify old/current flow generations, deallocation and all protected-screen tests.

### AUD-06 — Define bounded retention for intents, deferred URLs and alerts

- **Priority:** P2; **finding:** F07; **effort:** M.
- **Files:** `Core/DeepLinks/DeepLinks.swift`, `Core/Alerts/AppAlert.swift`, `App/AppCoordinator.swift`, queue/coordinator tests and README policy.
- **Dependencies:** AUD-02 for a paused reset; AUD-04 for overflow/error response policy.
- **Approach:** choose a documented capacity and overflow behavior appropriate for the demo (for example, a small bounded FIFO that rejects additional distinct work with feedback). Validate before storing raw deferred URLs where it does not change the shared pipeline guarantee. Keep active business and alert ownership separate; do not evict an active protected request. Define alert acceptance/coalescing feedback before bounding it (F22), and do not silently drop actionable errors. A bounded array is adequate; no package/custom queue framework.
- **Risks:** changing accepted-intent semantics or duplicate handling; logging a rejected sensitive URL.
- **Acceptance criteria:** memory retention is bounded, duplicates do not consume capacity, valid retained intents remain FIFO, invalid deferred URLs do not occupy business capacity, and overflow is observable without exposing codes.
- **Tests required:** capacity boundary plus one; duplicate/invalid bursts during phone/error/reset; accepted sequence after completion; repeat completed code remains idempotent; no concurrent redeem.
- [ ] Write policy tests before changing behavior.
- [ ] Implement the bounded policy and typed feedback.
- [ ] Verify parser/processor/app tests and update the public demo policy.

## Phase 2 — Simplify proven ownership/state

### AUD-07 — Use one child-retention mechanism

- **Priority:** P2; **finding:** F04; **effort:** M.
- **Files:** `App/AppCoordinator.swift`, `Core/Navigation/Coordinator.swift`, feature coordinator UUID declarations, `ArchitectureTests.swift`.
- **Dependencies:** AUD-02/AUD-05/AUD-14, with lifecycle/weak-reference tests green.
- **Approach:** use existing typed feature properties as the fixed hierarchy's sole strong owners. Replace test/diagnostic registry queries with a derived summary if still useful. Remove registry-only UUID identities after verifying no indirect consumers. Do not merge feature coordinators or invent a generic base class.
- **Risks:** premature release, stale callbacks, losing the retained Home coordinator when redeeming from a secondary/modal.
- **Acceptance criteria:** one authority retains each child; completion/Return/reset/stop releases the right objects exactly once; original navigation/business flow remains unchanged.
- **Tests required:** weak child lifetime and release across every exit, retained Home during authenticated redeem, phone lifetime and once-only finish, no route/session changes from bookkeeping alone.
- [ ] Add lifetime assertions using current design.
- [ ] Remove the duplicate registry and update only its real consumers.
- [ ] Run full native suite and review ownership graph.

### AUD-08 — Remove invisible authenticated redeem presentation state

- **Priority:** P2; **finding:** F05; **effort:** M.
- **Files:** `App/AppCoordinator.swift`, `Features/Redeem/RedeemCoordinator.swift`, app/feature tests.
- **Dependencies:** AUD-04/AUD-07; preserve AUD-02's business injection.
- **Approach:** let a transaction context hold code/pre-auth snapshot and let AppCoordinator's operation run without requiring a RedeemCoordinator. Instantiate that coordinator only when its status screen exists. Preserve retry/Return for the unauthenticated screen; keep the dedicated use case.
- **Risks:** accidentally deciding eligibility from updated SessionStore; losing error/queue completion; changing diagnostics from “active UI coordinator” to “active business transaction” silently.
- **Acceptance criteria:** authenticated success has no invisible child/model/callback lifecycle, no phone/login/root reset and no controller replacement. Unauthenticated retry still uses the original nil session.
- **Tests required:** both starting session states and all failure classes, queued ADD-CRED after new-user onboarding, retry after partial account creation, active-coordinator diagnostics.
- [ ] Pin business/UI outcome invariants.
- [ ] Remove `showScreen` mode and relax only the presentation dependency of the transaction.
- [ ] Run full unit/UI scenarios and compare stack identities.

### AUD-09 — Consolidate read-only diagnostics and remove metric coupling

- **Priority:** P2; **findings:** F06/F08; **effort:** M.
- **Files:** `Features/Demo/DemoViews.swift`, `App/AppCoordinator.swift`, modal sheet diagnostics in `Features/Home/HomeCoordinator.swift`, snapshot tests. Include safe alert phase/count/scene eligibility only if diagnostics are intended to describe current presentation (F21); otherwise rename the label to current feature.
- **Dependencies:** AUD-07/AUD-08 stabilize ownership semantics.
- **Approach:** keep editable code/status/reset state distinct from a typed read-only diagnostic snapshot. Build it from actual owners and publish once per relevant change. Query metrics independently of successful navigation; do not make credentials/router state derive from diagnostic copies. Keep Combine; migrating observation systems is not necessary.
- **Risks:** stale modal data, different publication timing, exposing sensitive transaction context in a convenient snapshot.
- **Acceptance criteria:** snapshots match actual stack/session/queue after transition completion and updates; controls do not write navigation state; no codes/URLs/account tokens; holding a metrics read cannot hold successful flow navigation.
- **Tests required:** snapshot coherence on all state transitions, sheet live data refresh, no navigation from credential-only mutation, privacy assertions and held-metrics timing test.
- [ ] Add owner-to-snapshot assertions.
- [ ] Replace individual mirrors with one value and narrow mutation access.
- [ ] Run diagnostics/mixed-screen and error-recovery tests.

## Phase 3 — Harden coverage and polish without redesign

### AUD-10 — Strengthen requirement assertions and OS delivery coverage

- **Priority:** P2; **findings:** F09/F10/F11; **effort:** L.
- **Files:** `CoordinatorNavigationDemoTests/DomainTests.swift`, `CoordinatorNavigationDemoTests/ArchitectureTests.swift`, `CoordinatorNavigationDemoUITests/NavigationUITests.swift`, optional `scripts/test-url-delivery.sh`; `App/AppDelegate.swift` only for a demonstrated entry test seam.
- **Dependencies:** AUD-01/AUD-03; can begin pure parser cases earlier.
- **Approach:** cover every existing parser guard with valid/invalid boundary fixtures; compare real controller identities and relevant store emissions for authenticated redemption; exercise actual custom-scheme delivery from terminated/background states. Target known lists/actions and specific Back items; retain the explicit default-launch smoke test and mixed-UI scenarios.
- **Risks:** flaky external Simulator orchestration; overcoupling tests to notification counts or private UIKit behavior; accidentally treating placeholder Universal Links as enabled.
- **Acceptance criteria:** scenario names match the layer/behavior asserted; cold-start tests include the real scene entry; normal swipe-back success proves policy restoration; critical gestures have independent transition evidence.
- **Tests required:** all gaps listed in the coverage matrix, including authenticated error families, original-context retry, direct popTo/popToRoot, and modal credential refresh. Keep the identifier regression; no timeout inflation.
- [ ] Add meaningful unit/integration assertions and parser boundaries.
- [ ] Add minimal OS-entry UI smoke coverage, recording its environment prerequisites.
- [ ] Run all tests and compare per-test timings before consolidating genuinely redundant UI setup.

### AUD-11 — Make demo-only shipping boundaries explicit, conditionally

- **Priority:** P2; **finding:** F12; **effort:** M; **optional for this explicitly standalone demo**.
- **Files:** `Features/Demo/DemoViews.swift`, `Core/DependencyInjection/AppComposition.swift`, `Features/Onboarding/AssociatePhoneViewController.swift`/XIB, PBX build conditions/configuration and release smoke tests.
- **Dependencies:** a decision that any non-demo shipping build is intended; otherwise keep the documented demo behavior and record this task as not applicable.
- **Approach:** retain reproducible Debug/Release demo operation. If a real product composition is introduced, make demo controls and seed/failure capabilities explicit opt-in there; do not pretend a mock-only app becomes secure production authentication merely by hiding a button. No additional target/framework is justified solely for this audit.
- **Risks:** losing Release reproducibility, inconsistent gating between controls and backend, overstating authorization guarantees.
- **Acceptance criteria:** demo build remains functional; any intended non-demo composition cannot expose seed/reset/failure administration; real server authorization remains required and documented.
- **Tests required:** configuration-specific absence/presence checks; no sensitive diagnostics/log output; full demo onboarding still works.
- [ ] Decide applicability and configuration contract.
- [ ] If applicable, implement narrow gates at composition and UI together.
- [ ] Verify both demo and intended shipping configurations without changing Swift/iOS settings.

### AUD-12 — Improve compact phone layout and tiny presentation state

- **Priority:** P3; **findings:** F13/F15; **effort:** S/M.
- **Files:** `Features/Onboarding/AssociatePhoneViewController.xib`, `Features/Redeem/RedeemCoordinator.swift`, layout/flow tests.
- **Dependencies:** protected phone behavior tests from AUD-03; independent of diagnostic refactor.
- **Approach:** use the lab's existing scroll content/frame-guide pattern for phone; preserve connected actions and Back policy. Make constant progress copy immutable. Do not migrate XIB to SwiftUI or build a generalized render-state framework.
- **Risks:** scroll view interfering with gesture attempts; hidden/disabled controls during loading; accidental outlet mismatch.
- **Acceptance criteria:** landscape and supported text-size error/loading content is readable; Associate/Skip remain reachable at allowed times; root replacement and Back restrictions unchanged; progress copy still correct.
- **Tests required:** real XIB loading, portrait/landscape failure+retry/Skip, protected and restored Back, SwiftUI progress/error UI.
- [ ] Capture layout regression expectations.
- [ ] Make resource/constant changes and validate native resource membership.
- [ ] Run the focused UI scenarios and full unit suite.

### AUD-13 — Maintain one current verification/architecture record

- **Priority:** P3; **finding:** F14; **effort:** S.
- **Files:** `README.md`, `docs/Verification.md`, relevant architecture diagrams/counts.
- **Dependencies:** after each approved phase; final pass after all chosen tasks.
- **Approach:** lead with current baseline/results and clearly label older runs as history. Record blocked execution separately from failing assertions. Describe alert callbacks as at-most-once for accepted user-completed requests, with zero for coalesced/cancelled submissions; update the portable subset description to include alert queue tests. Update ownership diagrams only for changes actually implemented; do not describe this proposal as shipped.
- **Risks:** erasing historical failures or presenting portable tests as native UI validation.
- **Acceptance criteria:** documentation matches current code/tests, version floors and commands; all pass claims have actual evidence; history remains accessible and sensitive logs are excluded.
- **Tests/checks required:** source/count/link checks, native project/scheme inspection, fresh build and chosen suites.
- [ ] Verify current facts against the working tree and execution artifacts.
- [ ] Update the single current status and preserve dated history.
- [ ] Review documentation against actual final behavior before a separate approved commit.

## Phase 0/1 extension — Alert correctness evidence and policy

### AUD-14 — Correct unsupported alert containment, trace warnings and prove owned lifetime

- **Priority:** P1; **findings:** F23/F24 confirmed warnings, F17/F18 lifecycle evidence and F09 inactive-response limitation; **effort:** L.
- **Files:** `CoordinatorNavigationDemoTests/RouterIntegrationTests.swift`, `CoordinatorNavigationDemoTests/TestSupport/RouterWindowHarness.swift`, `CoordinatorNavigationDemoUITests/NavigationUITests.swift`; `Core/Alerts/AlertPresentation.swift` for confirmed containment correction and traced publication correction; `Core/Navigation/NavigationRouter.swift` or owned SwiftUI hosts only as needed for supported attachment/lifecycle.
- **Dependencies:** AUD-01; attached-window infrastructure AUD-03 for full lifetime coverage; AUD-17 for meaningful warm/background UI delivery; business gates AUD-02 for actual inactive-response cases. The confirmed containment warning can be reproduced independently first.
- **Approach:** first reproduce F23/F24 warnings from the two passing UI methods with runtime diagnostics. Replace direct insertion into UIHostingController.view with supported SwiftUI-owned alert content or a regular UIKit container/common ancestor, keeping the native alert on XIB screens. Re-run with warning diagnostics and trace the exact remaining publication mutation before changing scheduling. Then add real renderer/scene tests, not more RouterSpy assertions. Establish native controller ownership, whether attachment occurred, the dismissal/cancellation terminal outcome and exactly when router work may resume. If tests demonstrate identity/liveness failure, replace the heuristic with a small lifecycle adapter or explicit state representation; retain both native renderers and one navigation stack. Do not blindly proceed on a timeout or use a fixed delay.
- **Risks:** removing an anchor too early, dismissing feature content, waiting on the wrong controller indefinitely, calling a stale business outcome or presenting while inactive.
- **Acceptance criteria:** both native renderer paths run without unsupported-containment or publication-during-update warnings; repeated UIKit and SwiftUI alerts leave no extra hosting children/owned controllers; alert→alert and alert→push start after native dismissal; reset before attachment/during presentation/dismissal cannot strand the queue; scene inactivation before SwiftUI onAppear pauses actual presentation until active. A held backend completion while inactive queues exactly one error and preserves its underlying modal.
- **Tests required:** both styles on SwiftUI/XIB, sheet/full-screen/phone; exact identity relationships; cancel immediately and after action selection; scene detach/reconnect; callback at most once; deallocation; real inactive response distinct from Home→app.open re-entry. Native UI cases must actually execute.
- [ ] Reproduce the recorded native warnings; add attached-window/scene expectations.
- [ ] Correct supported containment; trace and separately correct any remaining publication warning.
- [ ] Change only the lifecycle mechanism shown inadequate; prove ownership and terminal outcomes.
- [ ] Run complete native suite and retain artifacts; portable passes cannot close this task.

### AUD-15 — Enforce valid alert action configurations

- **Priority:** P2; **finding:** F19; **effort:** S.
- **Files:** `Core/Alerts/AppAlert.swift`, `CoordinatorNavigationDemoTests/AppAlertQueueTests.swift`, renderer tests if validation occurs at the boundary.
- **Dependencies:** none for pure contract tests; AUD-14 for native parity acceptance.
- **Approach:** choose construction-time validation or an enum/value shape that guarantees at least one unique supported action. Reject empty/repeated actions and repeated Cancel with explicit feedback; ensure invalid input cannot become an uncompletable active request. Keep valid existing factories unchanged in user behavior.
- **Risks:** trapping on recoverable caller mistakes; silently changing request acceptance/callback semantics.
- **Acceptance criteria:** invalid arrays are unrepresentable or rejected before renderer activation; the queue remains usable after rejection; valid UIKit/SwiftUI actions match and complete at most once.
- **Tests required:** empty array, duplicate OK/Retry/Cancel, all supported valid combinations, queue continuation and no callback on rejected request. The temporary re-audit probe is evidence, not a replacement for persistent tests.
- [ ] Write the failing pure request tests.
- [ ] Implement the smallest invariant boundary and update call sites if required.
- [ ] Run portable and native unit tests; execute representative renderer acceptance.

### AUD-16 — Decide global-versus-flow alert lifetime and arbitration

- **Priority:** P3 policy / conditional P2 if global acknowledgment must survive normal feature completion; **finding:** F20; **effort:** M.
- **Files:** `Core/Navigation/NavigationRouter.swift`, `Core/Alerts/AppAlert.swift`, `App/AppCoordinator.swift`, tests and `docs/GlobalAlerts.md`/README.
- **Dependencies:** product decision on durable global feedback, AUD-14 lifecycle evidence.
- **Approach:** document whether normal Home installation should discard an unrelated unsupported-link notice. If not, distinguish global/flow-scoped requests or cancellation reasons using the smallest explicit data/operation needed. Keep reset/disconnect invalidation. State navigation-before-alert priority separately from per-alert FIFO; do not merge all queues or introduce an event bus.
- **Risks:** stale Retry/Cancel after flow replacement versus losing unrelated important alerts. Changing dedupe callback fan-out would be a separate semantic change.
- **Acceptance criteria:** tests make visible and inactive-buffered association-completion cases deterministic; expected survivor/cancellation is explicit; reset/stop invalidate callbacks; allowed global requests do not mutate a stale business flow. Scheduling guarantees match documentation.
- **Tests required:** association running → malformed URL alert → Home completion; same while inactive; flow-scoped error reset; duplicate keys with different content; finite navigation burst before an alert. Do not claim starvation is a current observed failure.
- [ ] Decide and pin current/intended policy in tests.
- [ ] If policy changes, implement a narrow scope/cancellation contract.
- [ ] Verify both renderers and update current lifecycle/queue documentation.

### AUD-17 — Separate cold URL launch from real warm/background delivery

- **Priority:** P1; **finding:** F25, and F09 coverage; **effort:** M.
- **Files:** `CoordinatorNavigationDemoUITests/NavigationUITests.swift`; `App/AppDelegate.swift` only for a demonstrated cold Debug seed/delivery ordering correction; existing lower-level tests and `docs/GlobalAlerts.md`/verification record.
- **Dependencies:** AUD-01's current failed bundle; independent of child-registry/state cleanup. AUD-02's gate needed only for the separate inactive-response case.
- **Approach:** inspect test activities/process continuity before changing business code. Current `app.open` is a launch operation and activities record a second Launch. Use system URL dispatch for a true existing-instance test (for example `XCUIDevice.shared.system.open`, verifying availability on the supported test environment); wait for background state before dispatch. Assert a safe process/scene marker remains stable and complement it with controller identity assertions in attached tests. Keep a distinct terminated cold URL case. For Debug authenticated cold entry, reproduce connection-URL-before-reset cancellation and arrange seed completion before URL processing if confirmed; do not modify ordinary warm handlers to compensate for test relaunches.
- **Risks:** accidentally testing launch again, losing cold coverage, test marker exposing secrets or driving navigation, external delivery UI producing timing flakes. Do not relax assertions or extend timeouts as the fix.
- **Acceptance criteria:** details→real warm URL→Cancel returns to original details; background full-screen→URL→Retry returns to original modal and refreshes data; no additional create/login/phone. Dedicated cold URLs run once after initial setup without reset erasing them. Protected-phone alert test proves original controller survives. All cases are separate from the held-response-while-inactive test.
- **Tests required:** rerun the two currently failing methods; assert process continuity; true cold URL with/without authenticated seed; repeat delivery; background response gating; retain original stack/modal identities and permissions. Existing phone test must not pass solely by recreating the launch-argument flow.
- [ ] Demonstrate the current second-launch behavior and invalid preservation assumption from activities/continuity.
- [ ] Correct only test delivery, execute both failing cases, and inspect resulting assertions before attributing further defects.
- [ ] Reproduce and, if necessary, fix cold Debug setup ordering with a dedicated test.
- [ ] Run full unit/UI suites with warning diagnostics; update the current result without rewriting history.

## Revised implementation order and scope

**AUD-01 → AUD-17 and AUD-14 warning reproduction/containment → AUD-02/AUD-03 → AUD-14 remaining lifetime coverage and AUD-15 → AUD-04 acceptance/AUD-05 → AUD-06 → AUD-07/AUD-08/AUD-09 → AUD-10 → AUD-12/AUD-13.** AUD-16 is a policy decision alongside renderer work, not an automatic rewrite; AUD-11 remains conditional for a standalone demo.

The original source-side AUD-04 error feature is already implemented; verification and remaining cases replace that task's old implementation scope. The new work increases native lifecycle testing, not coordinator count. All 17 tasks are proposed, except the explicitly marked source work completed before this re-audit. AUD-01's result reconciliation is documented here; its future rerun must retain the current failing baseline. No task was executed as a production change here.

The original 5–9 day estimate is not silently reused for the larger alert-aware scope. Allow roughly **1–3 additional engineering days** for confirmed containment/test-delivery corrections, publication tracing and renderer lifecycle/request-policy coverage, with a working Simulator; this is directional and overlaps existing router-test infrastructure. Overall work remains incremental. First resolve the current two failing URL tests and recorded native warnings; then stabilize the full 60-declaration baseline and simplify bookkeeping. No Swift upgrade, deployment-target change, XIB migration, new generic framework or GitHub publication is part of this re-audit.
