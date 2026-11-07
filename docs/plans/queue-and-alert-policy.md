# Bounded queues and alert lifetime

Baseline: `a9b7788`; the user authorized AUD-06 and AUD-16 after the 103-declaration/119-expanded passing Simulator run. Keep Swift 5/iOS 17, one UIKit navigation stack, the existing coordinators and native renderers.

## Policy

- Reject newest distinct work at capacity; do not evict active work or previously accepted waiting work. Duplicates are checked first. Limits are per application instance, not inferred from total user population.
- Navigation: 32 ordinary waiting slots by default, configurable with a minimum of 2, plus 2 bounded slots reserved for the single protected flow's Redeem/Phone pushes (maximum 34 waiting by default). Ordinary requests cannot use the reserve. Authorized root replacement discards obsolete waiting navigation and always admits its at-most-two cleanup/replacement commands.
- Business intents: 8 waiting plus one active. Startup and reset each stage at most 8 distinct validated intents, not raw URLs. Staging is not a reservation in the business processor: handoff goes through its normal admission and reports any rejection. Bulk handoff admits retained intents before dispatching callbacks so newer arrivals cannot overtake that batch; initial OS connection URLs keep their existing priority over live startup arrivals.
- Alerts: 9 waiting by default, including one slot reserved for flow recovery. Global notices can fill at most 8; flow alerts may use the final slot. One native alert may additionally be active. Typed admission outcomes report duplicates, invalid action configurations and capacity rejection.
- Flow alerts are cancelled by normal root replacement. Global informational OK notices survive, waiting until the replacement finishes if not already visible. A visible global notice finishes before replacement proceeds. Reset/stop/disconnect cancel all scopes. Deduplication identity includes scope plus semantic key.
- At most 4 non-root navigation commands run before yielding to an eligible waiting alert. Root replacement and its cleanup have precedence. Alerts never interrupt a running native transition or inactive scene. FIFO applies inside each queue, not across navigation and alerts.
- Overflow is observable through typed results/rejections and one coalesced generic global notice/status at composition. No codes, URLs, tokens or controller payloads are included. A flow error that cannot acquire alert ownership must release its protected intent, rather than wait for a callback that will never arrive.

## Implementation order

1. Write pure queue admission/scope/FIFO/reentrant-handoff tests, then implement the small existing arrays and typed results. No generic queue framework.
2. Write native capacity/fairness/root-policy and coordinator reset/recovery tests; bound router work and wire overflow feedback.
3. Update current contracts/audit status and source inventory. Independent read-only review; fix concrete findings in one pass.

## Constraints and ledger

- Ruling: continue in the user's current feature checkout. The existing recommendation and explicit instruction authorize implementation without another permission round. Capacity and lifetime defaults above are implementation choices and remain configurable integration policy.
- User owns all compilation/build/test/Simulator execution. Tests were written first; the agent did not execute a RED/GREEN cycle. Later user-owned execution evidence is recorded below.
- Do not automatically commit/push the follow-up. Preserve historical audit findings and result bundles.
- Current status: user focused/full Simulator runs passed; the verified implementation and evidence are committed at the user's request. No push was requested.
- Added a concrete PendingIntentBuffer shared by startup/reset staging, typed IntentAdmission/AlertAdmission outcomes, scoped alert factories, and bounded/fair router scheduling. No generic queue implementation or third-party dependency.
- Pure queue coverage adds 7 declarations. Native QueuePolicyTests adds 8 declarations, including scope and saturation parameter cases. All 91 native unit + 27 UI = 118 declarations passed in the user's full run; portable subset 30 executed natively rather than via a separate package run.
- Existing 1000-noop pump coverage now explicitly configures a 1001-command ordinary capacity; it still tests yielding/progression without assuming the default is unbounded.
- Independent read-only review found one P1: a full ordinary queue could reject required Redeem/Phone pushes and strand onboarding. One fix pass adds 2 bounded slots reserved for blocked pushes in the single protected flow, with regressions for saturation before Redeem and after its admission but before Phone. Accepted ordinary requests remain in FIFO order and are not evicted. Other consuming applications must size/adapt this policy for their protected flow's outstanding command needs.
- No other concrete review finding was established. The agent performed no compiler/test/Simulator execution; static checks and later user results remain distinct evidence.
- Final static checks passed for project/plist syntax, native test source membership, portable exclusions, unchanged Swift 5/iOS 17 settings, XIB/scheme XML, Markdown local links/fences and tracked/new-file whitespace. This is separate from the later user-owned execution evidence. Only documentation changed after result inspection and before the requested commit.
- Inspected the user's 22:29/22:30 focused bundles: 13 alert declarations, 6 intent declarations and 8 policy declarations/10 expanded runs passed. The full 22:30:57 bundle passed 91 unit + 27 UI declarations/136 expanded runs, zero failures/skips/recorded runtime warnings, iPhone 17/iOS 27.0 Simulator.
- Both protected saturation cases passed, preserving accepted ordinary controllers, reaching protected Phone and completing Skip. Scope, fairness, staging and recovery rejection cases also passed. Only documentation changed after inspection; exact artifacts and remaining unit-console diagnostics are in [Verification.md](../Verification.md).
