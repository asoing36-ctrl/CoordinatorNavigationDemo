# Previous audit: implementation status

Reconciled on 2026-11-07 against the working tree on `fix/navigation-behavior`, based on commit `5bb132a`, after the user's successful targeted and full Simulator reruns. The previous [17-task improvement plan](improvement-plan.md) is not fully completed. Work deliberately prioritized alert/URL reliability and reusable navigation over demo/business changes and architectural simplification.

The full run passed 71 unit and 26 UI declarations (111 expanded runs); the targeted router run passed 22 declarations (24 expanded runs). These results validate the selected Simulator destination, not every proposed audit acceptance criterion. See [Verification.md](../Verification.md) for exact artifacts and limits.

## Task-level crosswalk

| Task | Status | Current evidence and remaining work |
|---|---|---|
| AUD-01 — Baseline and real suites | Verification completed | Current passing results, prior failures and environment are recorded in [Verification.md](../Verification.md). Current navigation changes remain uncommitted; this is not a claim that the plan's commit checklist is complete. |
| AUD-02 — Deterministic business suspension/cancellation seams | Deferred | `App/AppCoordinator.swift:26–28` still accepts MockBackend and constructs its redeem use case. Stage-gated repository, noncooperative-completion and phone-task/reset-join coverage were deferred when focus shifted to navigation. |
| AUD-03 — Attached-window router integration | Substantially implemented; acceptance incomplete | 22 native router declarations and shared test-only window/transition fixtures execute real UIKit lifecycle and cancelled Back. [Strict review](navigation-strict-review-2026-11-07.md) found that interactive sheet-cancellation engagement is still unproved. |
| AUD-04 — Global error acceptance matrix | Implemented behavior; matrix incomplete | Authenticated Retry/Cancel and stack/modal preservation are implemented and tested. `CoordinatorNavigationDemoTests/ArchitectureTests.swift:258` and `NavigationUITests.swift:243` cover representative cases; the full error-family × destination matrix, repeated failures and selected-action reset timing are not all covered. |
| AUD-05 — Stop invalidates queued navigation | Implemented and verified | `App/AppCoordinator.swift:165,218` clears waiting commands before alert cleanup. Router lifecycle tests cover stale protected pushes, pending modal release, authorized replacement and normal progression after held transitions. |
| AUD-06 — Bounded retention and overflow | Open policy/implementation work | Distinct navigation, business-intent, deferred-URL and alert queues remain unbounded. See `Core/Navigation/NavigationRouter.swift:58`, `Core/DeepLinks/DeepLinks.swift:23`, `App/AppCoordinator.swift:20` and `Core/Alerts/AppAlert.swift:80`. Dedupe and bounded synchronous drain batches do not bound retained distinct work. |
| AUD-07 — One child-retention mechanism | Deferred | `App/AppCoordinator.swift:8,10–12` still owns both the children dictionary and typed child references. No ownership simplification was performed. |
| AUD-08 — Remove invisible authenticated redeem state | Deferred | `App/AppCoordinator.swift:79–83` still creates/retains RedeemCoordinator for both contexts; `Features/Redeem/RedeemCoordinator.swift:17` suppresses its screen when already authenticated. |
| AUD-09 — Derived diagnostics and metric decoupling | Deferred | `Features/Demo/DemoViews.swift:12–21` retains published diagnostic mirrors. `App/AppCoordinator.swift:99` still awaits backend metrics before advancing successful navigation; `refreshDiagnostics()` copies state at line 205. |
| AUD-10 — Stronger assertions and real OS delivery | Partially implemented | Cold/warm/background OS URL tests, instance continuity and real SwiftUI/XIB swipe Back now pass. Parser boundary expansion, the full behavioral assertion matrix and independent cancelled-sheet evidence remain incomplete. |
| AUD-11 — Non-demo shipping boundaries | Conditional; not implemented | This is still a standalone mock demo. Production composition must explicitly exclude seed/reset/failure controls if app code is reused. Reusing navigation alone does not require shipping demo controls. |
| AUD-12 — Compact phone layout and constant state | Deferred | Phone XIB still uses its existing non-scroll stack layout (`Features/Onboarding/AssociatePhoneViewController.xib:7`). Redeem progress copy remains mutable published state (`Features/Redeem/RedeemCoordinator.swift:5`). No compact/Dynamic Type layout work was undertaken. |
| AUD-13 — Current documentation/evidence | Maintained; ongoing | README, NavigationContract, GlobalAlerts and Verification reflect the implementation/latest results. Older audit baselines are explicitly historical. This crosswalk and the strict review distinguish implemented work from remaining recommendations; historical checkboxes remain unchanged. |
| AUD-14 — Supported alert containment and owned lifecycle | Corrections implemented; acceptance incomplete | Unsupported hosting containment/publication warnings are absent in the latest full run; native ownership/cancellation and inactive-modal scenarios pass. Stage-gated inactive backend completion, actual scene disconnect/release, cancellation after action selection and full deallocation evidence remain incomplete. The existing inactive test starts work while already inactive; it does not substitute for a held mid-flight response across a scene change. |
| AUD-15 — Valid alert action configurations | Implemented and native tests passed | `Core/Alerts/AppAlert.swift:86–87` rejects empty/duplicate actions before activation. Persistent queue tests cover invalid input, continuation and once-only matching completion; renderer scenarios run natively. The portable command was not separately rerun; its shared tests executed in the native target. |
| AUD-16 — Alert scope/lifetime and arbitration policy | Decision/testing still open | Current behavior is documented: navigation takes priority; normal root replacement cancels all alerts. Distinguishing durable global acknowledgments from flow alerts, explicit overflow/fairness choices and deterministic association-completion cases remain deferred. |
| AUD-17 — Cold versus real warm/background URLs | Implemented and verified | `NavigationUITests.swift:283–355` separates real system dispatch, instance-preserving warm/background delivery, terminated cold launch, authenticated setup and repeated/queued links. Required representative workflows pass. Stage-gated response timing remains the separate AUD-02/AUD-14 gap. |

Statuses describe implementation and evidence, not a completion percentage or production certification. A passing suite cannot close cases it does not contain.

## Next work for the user's navigation priority

1. Prove an actual interactive sheet dismissal engages and cancels; assert exact modal identity/route and continued queue progress.
2. Exercise scene disconnect during navigation/modal/alert transitions with weak-reference release checks, and broaden observer/rejection/action reentrancy tests.
3. Set explicit consuming-application queue capacity/overflow, alert lifetime and arbitration policies; preserve accepted ordering and protected flow ownership.
4. Complete iOS 17/current supported OS and physical-device validation, real gesture repetition and long-session profiling.

Coordinator/diagnostic/DI simplification and phone-layout polish can remain separate. No production refactor was performed as part of this reconciliation.
