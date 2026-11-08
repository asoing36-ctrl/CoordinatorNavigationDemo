# AUD-04 — Error recovery acceptance matrix

Baseline: `455999c`; branch: `test/error-recovery-matrix`.

Implement the existing Retry/Cancel contract without changing navigation behavior,
the router protocol, Swift 5 language mode or the iOS 17 deployment target.

## Plan

1. Add a parameterized coordinator matrix: INVALID, EXPIRED and NETWORK-FAIL;
   Home, Secondary, details, pushed XIB, SwiftUI sheet and UIKit full-screen;
   both alert styles. Snapshot controller identities, session, credentials and
   permissions. Cancel must advance distinct queued work without authenticating.
2. Cover repeated Retry failures, eventual recovery, duplicate suppression and
   obsolete request IDs with the real alert queue and a scripted repository.
3. Exercise attached-window native presentations, including cleanup above feature
   modals, an API failure returned while inactive, and stop/reset after selection.
4. Add representative OS-delivered UI workflows using actual Retry/Cancel buttons.
5. Register source membership, update coverage/verification documentation, perform
   static checks and one fresh-context read-only review. Fix important findings
   once, then leave runtime execution to the user.

## Rulings

- The user authorized AUD-04 from the existing audit plan; no new design gate.
- The user initially retained build/test execution, then explicitly authorized
  agent-run tests. Portable tests passed; native execution/build attempts were
  blocked by this session environment. Native RED/GREEN remains pending; static
  checks and portable tests cannot substitute for navigation execution.
- Work in the current checkout so the user's open Xcode sees the changes.
- No automatic commit, merge or push.
- A read-only internal getter for the router's existing owned AlertPresentation
  permits real component selection without a second presenter or factory. The
  NavigationRouting protocol and presentation behavior remain unchanged.
- Calling AlertPresentation.select exercises the typed renderer adapter boundary,
  not a native button tap. UI tests cover actual button taps; deterministic
  selection-before-dismissal stop/reset cases are component tests. Do not claim
  they establish every UIKit auto-dismissal race or actual OS suspension.

## Execution ledger

- [x] Inspect existing contract, fixtures, baseline and project membership.
- [x] Implement flow matrix and repeated recovery cases.
- [x] Implement native lifecycle and UI coverage.
- [x] Static verification and final review (source only; see evidence below).
- [x] Successful user-owned native Xcode validation: focused diagnostics, all UI
  methods and full scheme passed; agent result inspection completed.

Last passing baseline remains 110 unit + 27 UI declarations (173 expanded cases)
from the user's November 8 runs. Newly added cases must be reported separately
until their result bundle is inspected.

## Source review and static evidence

- Inventory: 5 new unit declarations / 58 expanded cases (36 + 4 + 12 + 2 + 4),
  plus 6 UI methods. Total source: 115 unit + 33 UI = 148 declarations,
  expected 237 expanded cases. These are not passing test results.
- `plutil` successfully parsed the native OpenStep project. All 15 native unit
  source files are registered exactly once. All 37 Swift/XIB references resolve.
- XIB, application plist and shared scheme XML parse; every XIB outlet/action
  resolves to its controller symbol. Swift 5.0 and iOS 17.0 settings are unchanged.
- `git diff --check` and changed-Markdown local-link/fence checks passed.
- One fresh-context read-only reviewer found one Important source compilation
  risk: attached-window tests referenced the concrete router's private alert
  queue. Corrected in one pass by observing the existing presentation getter,
  business intent state and real native arrival/cleanup instead. Queue inspection
  remains in the flow tests through RouterSpy. No extra production seam was added.
- Reviewer found no other concrete Important/Critical issue and confirmed case
  counts, native source membership and explicit evidence boundaries. The minor
  ledger omission was corrected here. No native compilation/runtime success is claimed.

Ruling: do not synthesize native UIAlertAction handlers with private APIs or add
production launch modes just to force a button/reset race. The component tests
hold the existing typed selection boundary; six UI cases exercise native buttons.
Actual native-button auto-dismissal/reset overlap and OS suspension remain AUD-14
validation gates, distinct from this source coverage and its pending user run.

## Authorized execution follow-up — 2026-11-08

The user said “run what tests you want now,” superseding the earlier restriction.

- Portable `swift test --disable-sandbox --scratch-path
  /private/tmp/coordinator-aud04-portable`: **30 tests across 4 suites passed**, exit 0.
- Focused native command with both new suites and six UI methods: **exit 70 before
  execution**, CoreSimulatorService connection invalid/refused; requested iPhone 17
  / iOS 27.0 destination unavailable. No new navigation tests ran.
- Generic Simulator `build-for-testing`: **exit 65**, sandbox-exec sandbox_apply
  Operation not permitted; SwiftUI State macro plugin produced malformed responses.
- Full native suite was not retried against the same unavailable destination.
- Logs, requested device ID, invocation result path and exact rerun commands are in
  [Verification.md](../Verification.md). No production workaround, commit or push.

## User full run and failure follow-up — 2026-11-08, 19:38

- Completed user bundle: `Test-CoordinatorNavigationDemo-2026.11.08_19-38-01-+0200.xcresult`.
  iPhone 17 / iOS 27.0 Simulator arm64; 141 passed / 7 failed of 148 declarations,
  230 passed / 7 failed of 237 expanded cases; zero skips/recorded runtime warnings.
- Both new recovery suites passed all 5 declarations / 58 cases. The full source
  compiled in the user's Xcode environment. Earlier agent build restrictions are
  environmental; they are not source compilation defects.
- Six UI failures share one pre-navigation assertion: segmented button value is
  empty. Replaced raw value comparison with a bounded `isSelected` predicate;
  selection is still asserted, with no delay or timeout increase.
- The unauthenticated held-metrics case accepted `.phoneAssociation` and nil
  transition coordinator while the Phone push was still queued behind Redeem.
  The predicate now also requires actual routes, Phone top controller, blocked
  Back and attached view before continuing. Metrics stays held throughout.
- Post-edit focused attempt exited 70 before execution: CoreSimulator unavailable
  in the agent session. Corrections remain unverified; rerun DiagnosticsIsolationTests
  and the six UI methods, then the full scheme. No commit/push.

Ruling: correct demonstrated test assumptions at their boundary. Do not alter
router scheduling or expose more internal state to make these tests pass. The
failed predicates already provide RED evidence; GREEN awaits native execution.

## Passing user verification — 2026-11-08, 20:00 / 20:02 / 20:18

- `Test-CoordinatorNavigationDemo-2026.11.08_20-00-28-+0200.xcresult`:
  DiagnosticsIsolationTests **6/6 declarations / 8 cases passed**.
- `Test-CoordinatorNavigationDemo-2026.11.08_20-02-21-+0200.xcresult`:
  NavigationUITests **33/33 methods passed**, including all six recovery workflows.
- `Test-CoordinatorNavigationDemo-2026.11.08_20-18-38-+0200.xcresult`:
  full scheme **115 unit + 33 UI = 148 declarations / 237 expanded runs passed**.
- Zero failures/skips/recorded runtime warnings in all three bundles. Destination:
  iPhone 17 / iOS 27.0 Simulator arm64. Full tree confirms all 58 new component
  cases and both readiness parameters; all seven earlier
  failures are resolved on this destination. Exact path/scope in Verification.md.
- The user built and ran these tests. The agent inspected completed results;
  earlier agent environment failures remain distinct from source/runtime evidence.
- AUD-04's implemented matrix is verified for this destination. Broader AUD-14
  gates remain: OS suspension, native-button auto-dismissal/reset overlap,
  minimum/current OS, physical devices and repeated gestures/long sessions.
- No further source changes followed the passing runs; documentation only.
  Implementation, test corrections and evidence are included together at the
  user's explicit request to commit. No merge/push is part of this change.
