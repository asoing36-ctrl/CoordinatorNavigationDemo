# Navigation ownership and state simplification

> Execution: use superpowers:executing-plans inline, with one fresh-context final review. User owns all builds and test execution.

**Goal:** Complete the agreed AUD-07–09 simplifications while preserving navigation, authentication context, protected onboarding and alert/intent ownership.

**Spec:** [Audit improvement plan, phase 2](../audits/improvement-plan.md#phase-2--simplify-proven-ownershipstate), the original application requirements and the user's instruction that navigation takes priority over demo UI.

**Baseline:** de12aab, merged/pushed main; user-run 99 unit + 27 UI = 126 declarations / 152 expanded runs passed on iPhone 17 / iOS 27.0 Simulator. These results do not validate this follow-up.

## Design and constraints

- Keep Swift 5, iOS 17, Combine, one UINavigationController and actual XIBs. Preserve the router's validated transition, Back, queue, scope and lifetime policies.
- Typed AppCoordinator properties are the sole strong child owners. Remove the redundant registry and registry-only coordinator UUIDs; retain explicit start/stop and weak UI callbacks.
- A concrete private redeem transaction carries its own identity, original session, code and recovery phase. It owns business context independently of whether there is a status-screen coordinator. Construct RedeemCoordinator only for unauthenticated presentation; remove showScreen mode.
- Retry/Cancel/Return callbacks validate transaction identity and recovery eligibility. Keep the pre-redeem session through retries. Do not create/login/show Phone or replace an authenticated stack after credential-only success.
- Replace individual navigation diagnostic mirrors with one typed, read-only value snapshot. Derive it from owners, observe session-only mutations, and update consumers without changing accessibility identifiers or control behavior. UI diagnostics never drive routing.
- DemoModel owns a bounded metrics refresh separately: one active read plus one coalesced refresh request, cancellation/generation guards, weak owner capture across awaits. A slow/noncooperative read cannot delay navigation, reset or the next intent; stale reads cannot overwrite reset metrics. Keep login count separate from the navigation snapshot because it is asynchronous backend observation.
- Ruling: the existing audit and preceding conversation define the approach; the user explicitly said to start. No further design/permission round. Alternative generic coordinator registries and a routing rewrite would increase scope and are excluded.
- Ruling: use the existing checkout on a new feature branch so the user's Xcode sees changes; honor the established in-place preference rather than creating a second worktree.
- Ruling: write tests before implementation, but do not execute compiler/build/tests/Simulator or claim RED/GREEN. User-run artifacts validate their own source snapshots. No automatic commits, pushes or merges.

## Review focus

1. Old recovery callbacks must not cancel/retry the next queued transaction, including without reset.
2. Weak child lifetimes must survive running operations and end on Return, phone completion, reset and stop; Home survives authenticated grants/errors.
3. Removing the awaited metric must preserve cancellation checks across synchronous session/status publication and router callback reentrancy.
4. Held metrics must not strand navigation or spawn unbounded replacement tasks; obsolete metrics must not publish after reset/stop.
5. Snapshot publication must observe actual completed mutations, including session-only credential changes, while preserving modal live updates and safe values.

## Task 1 — One child owner (AUD-07)

Files: App/AppCoordinator.swift, Core/Navigation/Coordinator.swift, the three feature coordinator files, ArchitectureTests.swift, LifecycleTimingTests.swift and new SimplificationTests.swift.

- [x] Write weak-lifetime tests for redeem Return/reset/stop, Phone Skip/Associate/reset/stop, and retained Home while authenticated redemption is suspended.
- [x] Remove the child registry/retain/release bookkeeping and unused coordinator UUIDs. Stop/nil the typed properties explicitly through one cleanup helper.
- [x] Update registry-dependent assertions to observable typed ownership/weak release. Do not touch UIKit children or alert/credential IDs.
- [x] Static usage/ownership check; user execution remains pending.

## Task 2 — Business transaction independent of presentation (AUD-08)

Consumes: typed child owners from task 1; existing injected CredentialRepository and DeepLinkProcessor.

- [x] Write held authenticated success/error tests requiring original controller/Home identity and no RedeemCoordinator; replay an old captured action against the next transaction.
- [x] Write partial-login failure/retry coverage preserving the original unauthenticated context and once-only retry admission.
- [x] Introduce the concrete transaction context/recovery phase, remove activeCode/originalSession fields and showScreen mode, and adapt waitForOperation to business state.
- [x] Keep cancellation and transaction checks before applying results and after observable publications; preserve real pushed Phone and queue completion.

## Task 3 — Diagnostics cannot gate navigation (AUD-09)

Consumes: stable typed ownership and business transaction from tasks 1/2. Files: Features/Demo/DemoViews.swift, App/AppCoordinator.swift, Features/Home/HomeCoordinator.swift, new DiagnosticsIsolationTests.swift, shared lifecycle cleanup and project/package membership.

- [x] Write native held-metrics cases for unauthenticated Phone and authenticated queue/stack progression, plus a stop triggered by session publication.
- [x] Write stale metric cancellation/coalescing and coherent snapshot/session-only update tests. Join held test work on success and failure.
- [x] Publish one typed navigation snapshot and update demo/sheet consumers. Keep editable demo controls separate.
- [x] Move the asynchronous metrics read into independently owned, bounded DemoModel work. Navigation completion contains no metrics await.
- [x] Register new native tests/support and portable exclusions. Update architecture/audit/verification docs with source inventory and unexecuted status.

## Verification and review

- [x] Static project/plist/XML/source membership, Swift/deployment settings, whitespace and Markdown local-link/fence checks.
- [x] One fresh-context read-only review of the whole working tree against de12aab; no reviewer build/test execution or further agents. Fix concrete Important/Critical findings in one source pass; record limitations rather than claiming tests passed.
- [x] Handoff: user ran focused SimplificationTests/DiagnosticsIsolationTests and the full native scheme including LifecycleTimingTests. Results inspected: 137 declarations / 173 expanded runs passed; exact artifacts below.

## Ledger

- Pre-flight 1→2: removing registry IDs does not remove transaction identity; queued callbacks require a meaningful business token rather than coordinator UUIDs.
- Pre-flight 2→3: authenticated error completion can no longer inspect an invisible RedeemViewModel; the transaction recovery phase must drive waiting/retry rules.
- Pre-flight 3→2: deleting the metrics await removes a suspension point that formerly rechecked reset/stop. Preserve an explicit transaction check after SessionStore.apply and after status publication.
- Status: implementation and all 11 new declarations passed in focused/full user runs; 110 unit + 27 UI = 137 declarations / 173 expanded runs passed. No agent-initiated build/test execution; the user requested committing the verified revision.

## Final source review and fix pass

- One fresh-context reviewer inspected the tracked diff and new tests/plan against de12aab, without mutations, compilers, builds, tests or additional agents. No Critical finding or additional confirmed production blocker beyond the snapshot gap below. Verdict: source fixes required; runtime acceptance remains pending.
- Important: DeepLinkProcessor notifies before dispatch, and authenticated admission performs no push. The snapshot could stay authenticated while the actual transaction was redeeming. Source fix: refresh after admission and recheck the current transaction before starting work. The held authenticated test settles earlier seed observation, then requires redeeming with HomeCoordinator ownership. No new execution is claimed.
- Final: Ruling: the review's minor once-only Retry coverage gap is treated as an important navigation/business admission regression boundary — hold the retry after login has actually happened, replay Retry while recovery is no longer eligible, and assert real backend login counts and one Phone/Home completion. A mere synchronous double call could be hidden by cancellation-aware mock timing. The source test exercises the held boundary and subsequently passed in both focused/full user runs.
- Final: Ruling: the reviewer declined compiler/concurrency diagnostics, native accessibility/animations, runtime results and final documentation — user owns execution; perform only static checks and hand off exact suite commands. No merge/build/green claim. Unchanged router algorithms retain their earlier evidence; this review checks their new coordinator integration, not a fresh full router proof.
- Final: Ruling: real remote side effects are not rolled back by cancelling the client. Business/phone reset still joins effectful work before resetting the mock; read-only metrics is cancelled/invalidated independently and cannot hold navigation. Existing broader OS/device and full error-family/destination matrices remain open.
- Test structure: ownership/transaction cases live in SimplificationTests; diagnostics independence and reentrancy live in DiagnosticsIsolationTests. Both are native-only, registered once and excluded from portable verification. The UI accessibility identifiers are unchanged.

## Static handoff

- plutil accepted the native project and Info.plist. Both real XIBs and the shared scheme parse; outlet/action destinations exist. All 36 Swift/XIB paths match project membership, and every native test source is included exactly once. Both new suites are excluded from portable verification. Swift 5.0 and iOS 17.0 remain unchanged.
- Whitespace and changed Markdown local-link/fence checks passed across 20 changed/new files. Existing native alert/router/deep-link implementations and all UI accessibility identifiers are unchanged; UIKit children and alert/credential IDs remain intact.
- Source inventory is 110 unit + 27 UI = 137 declarations. This is not a passing execution count. User should run SimplificationTests, DiagnosticsIsolationTests, LifecycleTimingTests and the full scheme before committing. No source/build/runtime success claim beyond the stated static checks.

## Verified user execution — 2026-11-08, 15:00 / 15:02 / 15:05

- SimplificationTests: 5/5 declarations / 13 expanded runs passed. DiagnosticsIsolationTests: 6/6 / 8 passed. Full suite: 110/110 unit + 27/27 UI = 137 declarations / 173 expanded runs passed, with zero failures/skips/recorded runtime warnings.
- Exact bundles: Test-CoordinatorNavigationDemo-2026.11.08_15-00-21-+0200.xcresult; Test-CoordinatorNavigationDemo-2026.11.08_15-02-25-+0200.xcresult; Test-CoordinatorNavigationDemo-2026.11.08_15-05-33-+0200.xcresult. Full paths/destination are in Verification.md. All are user-owned runs on iPhone 17/iOS 27.0 Simulator, arm64.
- Inspected full test tree confirms every new parameter, existing lifecycle/queue and UI case passed, including both review follow-ups. AUD-07–09 is implemented and verified for this destination. Broader error/destination matrices, real OS teardown, repeated engaged cancellation, minimum-iOS/devices and profiling remain open.
- Full console: native unit 16 locked-focus/478 handler-drop entries; UI zero of either. No matched unsupported-hosting, publication-during-update, unbalanced-appearance or unfinished-navigation diagnostics. Cause of remaining native-fixture messages is unestablished. No leak/harmlessness claim.
- Only documentation changed after inspecting these results. The agent ran no compiler/build/tests/Simulator/app, and performed no commit/push/merge. Preserve the tested source; work stays uncommitted until requested. Earlier unexecuted notes describe their historical pre-run state.

## Commit handoff — 2026-11-08

- User explicitly requested committing the verified simplification after the full pass. Include the implementation, native project/test membership, two new suites and refreshed audit evidence on refactor/navigation-simplification. No merge/push requested in this handoff.
- Re-read the completed 15:05 xcresult: 137 declarations / 173 expanded runs passed, zero failures/skips/recorded runtime warnings. Only documentation changed after that run. No agent compiler/build/test/Simulator/app execution.
- Earlier uncommitted notes record their historical state; this revision commits code, tests and evidence together as requested.
