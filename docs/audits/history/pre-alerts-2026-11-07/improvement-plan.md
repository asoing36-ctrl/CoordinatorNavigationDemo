# Incremental architecture improvement plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement an approved phase task-by-task; use superpowers:subagent-driven-development only if that execution method is chosen. Steps use checkbox (`- [ ]`) syntax. This document is a proposal, not authorization to implement during the audit.

**Goal:** Preserve all required mixed-UI/navigation/business behavior while reducing duplicated bookkeeping and improving lifecycle/error reliability and test evidence.

**Architecture:** Keep one UIKit navigation stack, one protocol router, AppCoordinator and the three feature coordinators, a main-actor SessionStore, pure parser/typed intent queue, redeem use case and actor repository. Simplify ownership and diagnostic mirrors; use existing dependency seams before adding abstractions.

**Tech stack:** Swift 5 language mode, iOS 17+, SwiftUI, UIKit/XIB, Swift Concurrency, Swift Testing and XCTest/XCUITest; no third-party dependencies.

**Spec:** [architecture-audit.md](architecture-audit.md) findings F01–F16, [navigation-flow-audit.md](navigation-flow-audit.md) required-behavior comparison, and [test-coverage-matrix.md](test-coverage-matrix.md).

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
- **Approach:** keep the local sheet-identifier fix and regression as baseline. Run the full 29-unit/16-UI declaration set in Debug, record actual failures and expanded parameter counts separately. If a new result fails, investigate it rather than loosen assertions. Preserve the earlier 39-pass/5-fail record as history.
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

### AUD-04 — Make authenticated failures visible without resetting navigation

- **Priority:** P2; **finding:** F16; **effort:** M.
- **Files:** `App/AppCoordinator.swift`, `Features/Demo/DemoViews.swift`, `Features/Home/HomeCoordinator.swift`, `Features/Home/NavigationLabViewController.swift`/XIB if using an inline surface; `Core/Navigation/NavigationRouter.swift` only if the chosen error presentation needs a narrowly defined extension.
- **Dependencies:** AUD-01/AUD-02; use AUD-03 if presenting/dismissing error UI.
- **Approach:** first choose a single recoverable error contract reachable from every supported authenticated screen and current modal. Do not rely on diagnostics or a Home-only status row. Decide whether Retry reuses a retained transaction or submits anew, and whether a following queued intent can replace the visible failure. Use existing coordinator callbacks/router, not an error event bus or another stack.
- **Risks:** dismissing a user's modal unexpectedly; accidentally re-login or resetting the underlying stack; blocking the next intent forever.
- **Acceptance criteria:** INVALID/EXPIRED/network failure is visible and actionable from Home, Secondary, details, lab and active sheet/full-screen lab. Existing session/credentials/permissions and controller identities remain valid. Queue/retry semantics are explicit and tested.
- **Tests required:** table-driven authenticated error cases, no login/create/phone, exact controller identity preservation, retry then success, failure followed by another distinct queued intent, visible UI response on at least details and a modal.
- [ ] Write failing screen-independent error tests.
- [ ] Implement the smallest shared error surface and flow outcome required.
- [ ] Run business/coordinator/router and representative UI regressions; commit this behavior change separately.

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

### AUD-06 — Bound pending/deferred link retention

- **Priority:** P2; **finding:** F07; **effort:** M.
- **Files:** `Core/DeepLinks/DeepLinks.swift`, `App/AppCoordinator.swift`, processor/coordinator tests and README policy.
- **Dependencies:** AUD-02 for a paused reset; AUD-04 for overflow/error response policy.
- **Approach:** choose a documented capacity and overflow behavior appropriate for the demo (for example, a small bounded FIFO that rejects additional distinct work with feedback). Validate before storing raw deferred URLs where it does not change the shared pipeline guarantee. Keep the active intent separate; do not evict it. A bounded array is adequate; no package/custom queue framework.
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
- **Dependencies:** AUD-02/AUD-05, with lifecycle/weak-reference tests green.
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
- **Files:** `Features/Demo/DemoViews.swift`, `App/AppCoordinator.swift`, modal sheet diagnostics in `Features/Home/HomeCoordinator.swift`, snapshot tests.
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
- **Approach:** lead with current baseline/results and clearly label older runs as history. Record blocked execution separately from failing assertions. Update ownership diagrams only for changes actually implemented; do not describe this proposal as shipped.
- **Risks:** erasing historical failures or presenting portable tests as native UI validation.
- **Acceptance criteria:** documentation matches current code/tests, version floors and commands; all pass claims have actual evidence; history remains accessible and sensitive logs are excluded.
- **Tests/checks required:** source/count/link checks, native project/scheme inspection, fresh build and chosen suites.
- [ ] Verify current facts against the working tree and execution artifacts.
- [ ] Update the single current status and preserve dated history.
- [ ] Review documentation against actual final behavior before a separate approved commit.

## Scope, effort and implementation order

Recommended order: **AUD-01 → AUD-02/AUD-03 → AUD-04/AUD-05 → AUD-06 → AUD-07 → AUD-08 → AUD-09 → AUD-10 → AUD-12 → AUD-13**. AUD-11 is conditional and should not block a demo. Pure parser checks from AUD-10 can run earlier; AUD-13 is maintained throughout.

This is a medium incremental effort, dominated by reliable UIKit/cancellation tests rather than replacing production architecture. Broadly, expect roughly **5–9 engineering days for the full recommended set**, with UIKit runtime access and no newly discovered major defect; a narrow correctness-first slice is smaller, optional shipping/layout work is additional. Estimates overlap and are not a mechanical sum of task maxima. The core simplification likely touches around 8–10 existing production files plus tests/docs and can leave the current domain models/repository behavior largely intact.

Do not bundle all tasks into one rewrite. Review each green behavioral change before proceeding, keep commits reversible, and retain the original-session, protected phone and single-stack invariants as phase gates. No implementation or publication was performed by this audit.
