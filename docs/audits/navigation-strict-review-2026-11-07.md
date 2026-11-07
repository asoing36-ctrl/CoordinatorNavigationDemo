# Strict navigation review — 2026-11-07

An independent review agent inspected the actual working tree on `fix/navigation-behavior`, including untracked tests/support/docs, against base commit `5bb132ab59ff99d6d6dae98e93977fc55f432d2c`. The review was read-only: no production/test/configuration edits, builds, compilers, tests, Simulator or app launches. The parent agent recorded this report and documentation freshness updates separately.

## Verdict

**No confirmed correctness blocker was found within the supported integration contract.** No P0/P1 production defect or concrete P2/P3 implementation defect was established. The layer is ready for application integration validation; production rollout still requires the release gates in [NavigationContract.md](../NavigationContract.md).

The reviewer confirmed these strengths in the inspected source:

- UIKit is the stack authority; route metadata retains exact controller identities through cancellation.
- Controller ownership checks and replacement preflight guard common invalid UIKit operations before mutation.
- Independent navigation/presentation flags, the non-reentrant runner and visible-root drain barrier address transition ordering.
- Stop/reset release waiting controllers before alert cleanup can resume navigation.
- Coordinators own navigation; feature views/controllers communicate actions through closures.
- New test/support files belong to the native unit target, both XIBs remain resources, and Swift 5/iOS 17 settings remain unchanged.

## P2 validation gap: cancelled sheet interaction is not proved

**Evidence:** `CoordinatorNavigationDemoUITests/NavigationUITests.swift:159`, `testCancelledSheetSwipeStillAllowsDismissalAndNextPresentation()`. Its short drag at line 167 is assumed to engage and cancel dismissal. The assertions establish that the sheet remains hittable and ordinary dismissal/next presentation work. The test can also pass when the gesture never starts an interactive transition. No controlled native test independently establishes interactive sheet-cancellation engagement.

**Impact:** a regression in the router's cancelled adaptive-dismissal path can escape the current suite. This is missing validation, not an observed runtime defect.

**Minimal recommendation:** add a test-only presentation delegate/probe that observes an interactive dismissal and its cancelled completion. Then assert the exact same modal identity/route remains and waiting navigation can progress. Retain the real gesture UI test as complementary coverage. Do not weaken existing waits or move test hooks into production solely to inspect state.

## Other coverage limitations

- No actual `SceneDelegate.sceneDidDisconnect` during active navigation/modal/alert transitions followed by weak-reference release checks.
- Observer reentrancy covers a push from didShow, but not replacement/cancellation from observers, rejection recovery, or an alert action submitting more alerts/navigation.
- Replacement tests cover malformed batches and foreign children, but not promotion of the router-owned modal into the stack or execution-time rejection after ownership changes. Reparenting a queued controller is explicitly prohibited by the integration contract; its failure atomicity is not reported as a confirmed supported-use defect.
- Controlled cancelled Back is covered. Real cancelled edge gestures across SwiftUI/XIB screens still require supported-runtime/device repetition.

## Documentation assessment

The reviewed navigation contract, README, verification record and scoped plan describe actual ordering, first-wins route deduplication, typed rejections, scene gating and the inactive-modal cleanup exception. GlobalAlerts documents navigation priority over waiting alerts. Historical audit banners distinguish older baselines. The broader original audit is **not fully implemented**; see [implementation-status.md](implementation-status.md).

## Considered but not reported as new defects

| Area | Reason |
|---|---|
| Unbounded distinct FIFO / alert starvation under sustained navigation | Documented policy/backlog work; user population alone proves neither a runtime failure nor an appropriate capacity |
| Direct feature stack mutation, delegate replacement, queued-controller reparenting | Prohibited integration behavior |
| Backend/account cancellation, phone-task joining, coordinator simplification, routing redesign | Deferred from this navigation phase |
| Native fixture console messages | Eight focus/232 handler messages establish neither a leak, harmlessness nor a production failure; causation is unknown |
| Minimum OS/device, Release and profiling readiness | Missing release evidence already documented; not an invented source defect |

## Execution evidence and limits

The user's targeted run passed 22 router declarations/24 expanded cases; the full run passed 71 unit + 26 UI declarations/111 expanded cases, with zero failures/skips/recorded runtime warnings. See [Verification.md](../Verification.md) for artifacts. This is evidence for iPhone 17/iOS 27.0 Simulator. It does not replace pending iOS 17/current-device, real-gesture, disconnect and long-session validation.

No fixes, architectural simplification, commits or pushes were performed by the review agent. Production/test/resource/configuration hashes were unchanged during the review. The recommendations above are follow-up work, not implemented coverage.
