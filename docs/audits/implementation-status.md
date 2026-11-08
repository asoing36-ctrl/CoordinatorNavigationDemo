# Previous audit: implementation status

The timed/manual notice feature passed the user's **131 unit declarations / 231
expanded cases**, followed by the corrected UI suite passing **37/37 methods**.
These separate runs cover **168 declarations / 268 expanded cases**, including all
four formerly failing recovery taps. Only the UI helper/docs changed between runs;
no single post-correction full-scheme run is claimed. Source, tests and evidence
are included together for the user's requested commit/local main merge. See
[TimedNotices.md](../TimedNotices.md) and [Verification.md](../Verification.md).
Wider OS/device/accessibility gates remain open.

Reconciled on 2026-11-08 against `test/error-recovery-matrix`, based on verified `455999c` (its parent de12aab is merged/pushed). The previous [17-task improvement plan](improvement-plan.md) is not fully completed. The user authorized AUD-07–09 after prioritizing and verifying navigation/alert lifecycle reliability.

The simplification passed the user's focused/full runs: **110 unit + 27 UI = 137 declarations / 173 expanded runs**, zero failures/skips/recorded runtime warnings. Typed child owners replace the registry/UUIDs; business transaction/recovery state replaces invisible authenticated UI; a read-only snapshot and independently owned metrics replace diagnostic mirrors and the awaited navigation metric. AUD-07–09 is implemented and verified for the selected Simulator. See [the plan/review ledger](../plans/navigation-simplification.md). The verified implementation, tests and evidence are committed together at the user's request.

Focused SimplificationTests passed 5 declarations / 13 expanded runs; DiagnosticsIsolationTests passed 6 / 8. The full run passed both new suites, all lifecycle/queue tests and all 27 UI methods. The previous de12aab baseline passed 126 declarations / 152 expanded runs. See [Verification.md](../Verification.md) for exact artifacts and limits.

The earlier phase added **8 LifecycleTimingTests declarations**. All eight / 16 expanded runs passed again in the simplification full run, including the reset phone-task join and business/startup suspension gates. This is representative Simulator evidence, not closure of the wider audit matrices. See [lifecycle-timing.md](../plans/lifecycle-timing.md).

The [validation follow-up](../plans/navigation-validation-follow-up.md) passed controlled interactive cancellation, separate-delegate disconnect/release and observer/rejection/alert-action reentrancy cases and is committed with its verification record. Actual native sheet gestures, OS-driven scene teardown and the wider audit acceptance matrices still require separate validation.

AUD-06/AUD-16 work in [queue-and-alert-policy.md](../plans/queue-and-alert-policy.md) passed focused/full user runs: bounded admission, reserved flow capacity, scoped lifetime and fair scheduling. Source review identified a saturation/stranded-onboarding path; both regression cases passed with two protected slots, reaching Phone and completing Skip without dropping accepted ordinary work. The verified policy work is committed with its evidence; consuming-application policy tuning and OS/device evidence remain open.

The corrected AUD-04 revision passed focused DiagnosticsIsolationTests (6/8),
all UI tests (33/33) and the full scheme: **115 unit + 33 UI = 148 declarations /
237 expanded runs**, zero failures/skips/recorded runtime warnings. All 58 new
component cases and six recovery UI workflows passed on iPhone 17 / iOS 27.0
Simulator. The seven earlier failures from two test assumptions are resolved in
these runs. Implementation and evidence are recorded together; wider OS/device and
native-button/reset timing gates remain separate. See [Verification.md](../Verification.md).

## Task-level crosswalk

| Task | Status | Current evidence and remaining work |
|---|---|---|
| AUD-01 — Baseline and real suites | Current unit and corrected UI results verified separately | 131/131 unit declarations / 231 cases passed in the 21:14 full run; 37/37 corrected UI methods passed in the 21:46 rerun. Combined source coverage: 168 declarations / 268 cases, with production/unit source unchanged between runs. No single post-correction full-scheme run is claimed. See [Verification.md](../Verification.md). |
| AUD-02 — Deterministic business suspension/cancellation seams | Selected timings implemented and passed | Constructor injection separates CredentialRepository from mock reset/seed/metrics administration. LifecycleTimingTests holds completed create/login/redeem results and in-flight phone/seed calls, checking reset/stop, weak release and obsolete completion. Reset retains and joins cancelled phone work before environment reset. All selected lifecycle cases passed; wider failure/double-submission matrices remain open. |
| AUD-03 — Attached-window router integration | Controlled callback and representative swipe cases verified | 22 router and 5 follow-up declarations execute real UIKit lifecycle, cancelled Back/presentation, disconnect release and observer/rejection recovery. Those cases and the native-grabber completed sheet swipe passed. Controlled native cancellation proves interaction; the short UI cancellation smoke does not independently prove engagement. Repeated OS/device gestures and scene teardown remain separate validation. |
| AUD-04 — Global error acceptance matrix | Implemented matrix verified on selected Simulator | Business/native matrix tests passed in the feature full run. All six recovery UI workflows passed in the corrected 37-method UI rerun, resolving four missed final taps without production navigation changes. Prior baseline also passed one full 148/237 run. Native-button/reset overlap and broader AUD-14 gates remain separate. |
| AUD-05 — Stop invalidates queued navigation | Implemented and verified | AppCoordinator.reset/stop clear waiting commands before alert cleanup. The full rerun passed lifecycle cases for stale protected pushes, pending modal release, authorized replacement and normal progression after held transitions, including the policy integration. |
| AUD-06 — Bounded retention and overflow | Implemented; representative tests passed | Router, business, typed startup/reset staging and alert arrays have explicit bounds and reject-newest feedback. Reserved slots protect required screens and recovery. Saturation, FIFO, handoff and staging passed. The duplicate weak-release failure now passed with explicit autoreleasepool boundaries, accepted-work retention/release control and duplicate-burst coverage. App-specific sizing/stress remain separate. |
| AUD-07 — One child-retention mechanism | Implemented and verified | Typed redeem/onboarding/home properties are the sole child owners. Registry, retain/release bookkeeping and coordinator-only IDs are removed. Weak exit tests and retained Home across authenticated grants/errors passed. No feature merger or generic registry was introduced. |
| AUD-08 — Remove invisible authenticated redeem state | Implemented and verified | A concrete transaction stores original session, identity and recovery phase. RedeemCoordinator exists only for unauthenticated UI; showScreen mode is removed. Held authenticated outcomes, original controller/modal identity, stale callbacks versus the next intent, and partial-login/held duplicate-Retry cases passed. |
| AUD-09 — Derived diagnostics and metric decoupling | Implemented and verified | NavigationDiagnostics is one typed read-only owner projection; session-only changes refresh after assignment. DemoModel owns bounded independent metrics work, invalidated at reset/stop. Navigation has no metrics await. Held-read navigation/reset, coherent snapshots, stop during publication and stale/coalescing cases passed, including the review's admission-state regression. |
| AUD-10 — Stronger assertions and real OS delivery | Partially implemented | Cold/warm/background OS URL tests, instance continuity and real SwiftUI/XIB swipe Back now pass. Parser boundary expansion, the full behavioral assertion matrix and independent cancelled-sheet evidence remain incomplete. |
| AUD-11 — Non-demo shipping boundaries | Conditional; not implemented | This is still a standalone mock demo. Production composition must explicitly exclude seed/reset/failure controls if app code is reused. Reusing navigation alone does not require shipping demo controls. |
| AUD-12 — Compact phone layout and constant state | Deferred | Phone XIB still uses its existing non-scroll stack layout (`Features/Onboarding/AssociatePhoneViewController.xib:7`). Redeem progress copy remains mutable published state (`Features/Redeem/RedeemCoordinator.swift:5`). No compact/Dynamic Type layout work was undertaken. |
| AUD-13 — Current documentation/evidence | Maintained; ongoing | README, NavigationContract, GlobalAlerts and Verification reflect the implementation/latest results. Older audit baselines are explicitly historical. This crosswalk and the strict review distinguish implemented work from remaining recommendations; historical checkboxes remain unchanged. |
| AUD-14 — Supported alert containment and owned lifecycle | Corrections and selected timings passed | Unsupported hosting containment/publication warnings are absent in the last full run; native ownership/cancellation, inactive-modal and separate-delegate disconnect/weak-release scenarios pass. Passing new cases suspend phone work across activity change, cancel after the typed renderer selection boundary, and disconnect/reconnect during held seeding. OS-driven teardown, actual native action/reset overlap and broader profiling remain open. |
| AUD-15 — Valid alert action configurations | Implemented and verified | `Core/Alerts/AppAlert.swift:100–102` rejects empty/duplicate actions and limits global notices to OK. All 13 alert-queue declarations passed, including new scope/admission rules, alongside existing native renderer/UI cases. |
| AUD-16 — Alert scope/lifetime and arbitration policy | Policy/root and selected phone timings passed | Flow alerts cancel at normal replacement; global informational notices survive. Administrative reset/stop cancels both. Native visible/inactive root scope, reserved recovery and bounded fairness cases passed. New parameter cases passed for both renderers with visible/inactive global notices across held phone completion. Broader timing and consuming-app policy validation remain open. |
| AUD-17 — Cold versus real warm/background URLs | Implemented and verified for representative cases | NavigationUITests separates system dispatch, instance-preserving warm/background delivery, terminated cold launch, authenticated setup and repeated/queued links. Required representative workflows pass, alongside held startup/phone completion cases. Actual OS teardown and wider timing matrices remain open. |

Statuses describe implementation and evidence, not a completion percentage or production certification. A passing suite cannot close cases it does not contain.

## Next work for the user's navigation priority

1. Preserve the verified simplification revision and exact result artifacts; keep its suites as regression gates. Implementation, tests and evidence are committed together at the user's request.
2. Preserve the AUD-04 implementation and inspected focused/full evidence together: 148 declarations / 237 expanded runs passed. Keep both recovery suites, DiagnosticsIsolationTests and all UI workflows as regression gates. Commands and exact artifacts are in [Verification.md](../Verification.md).
3. Repeat native sheet-pan delivery and validate OS-driven scene teardown on supported runtimes/devices. The controlled reconnection case suspends real startup but invokes a separate delegate; it cannot establish OS callback delivery. Native action/reset overlap still needs separate validation.
4. Tune the tested capacity/reservation/lifetime/fairness defaults for the consuming application's flows and workloads; extend startup interruption and association-completion timing coverage where needed.
5. Complete iOS 17/current supported OS and physical-device validation, real gesture repetition and long-session profiling.

The authorized ownership/transaction/diagnostic simplifications now have passing user-run evidence; they preserve the coordinator hierarchy and router implementation. Phone-layout polish and the broader acceptance matrices remain separate.
