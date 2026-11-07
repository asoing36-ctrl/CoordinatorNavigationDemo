# Alert and deep-link reliability

Scope: execute AUD-14/AUD-17 from the committed audit; preserve the coordinator hierarchy, one navigation controller, Swift 5 and iOS 17. No architecture simplification, dependencies or XIB migration.

User instructions: do not run builds or tests. Add regression tests, perform non-execution source/configuration checks, and leave runtime verification pending the user's logs. The prior native baseline is 58 passing / 2 failing declarations, with four SwiftUI warnings.

## Decisions

- Use system URL dispatch for warm/background UI tests; use application launch-by-URL only for explicit cold starts. Assert a debug instance identity so recreated screens cannot satisfy preservation tests.
- Deliver cold connection URLs after optional authenticated Debug setup. Retain/cancel scene startup work; ignore delivery from a disconnected startup.
- Present a transparent, router-owned hosting controller for native SwiftUI .alert, above the current feature/modal. It owns its own presentation subtree. Do not insert hosting views into another UIHostingController.view or create a second window/navigation stack.
- Start the SwiftUI binding after UIKit's hosting presentation completes, outside SwiftUI view-update callbacks. Use UIKit transition/dismissal completions for cleanup instead of topmost-controller inference or window polling. Cancelling an alert must preserve the underlying feature modal.
- Reject invalid action arrays before they own the queue. Release the matching active request if presentation is cancelled/rejected; never invoke its business callback.
- Keep existing root-replacement cancellation and navigation-before-alert scheduling policies.

## Work and regression coverage

1. Update OS URL tests; add distinct cold-start and queued-link coverage.
2. Add attached-window regression tests for host containment, cancellation, queue resumption, scene gating, actual inactive business completion and modal preservation.
3. Fix cold setup ordering and owned native alert lifecycle; retain exact original session and controller identities.
4. Check project/XIB references and diffs. Update documentation and provide commands for the user to run the complete suites and inspect runtime warnings.

## Execution ledger

- Baseline: commit 621391f, clean working tree. Work is on fix/alert-delivery-reliability in the existing project directory so the user's Xcode project sees the edits.
- Ruling: the user's explicit build/test deferral overrides execution gates. No build or test pass will be claimed for these changes. Existing failure artifacts establish the pre-change symptoms; newly added regressions remain unexecuted.
- Verification pending: full native suite, warning-free SwiftUI presentation, actual background/cold delivery, and deallocation/cleanup on Simulator.

## Implementation record

- Updated warm/background/phone UI tests to use system URL dispatch and compare the Debug instance ID; added separate cold-start, queued-URL and alert-to-alert UI cases.
- Added composition cold-start ordering coverage, two pure queue regression declarations and six attached-window lifecycle declarations (four parameterized by native style). Existing coordinator/route assertions remain intact.
- Replaced hosting child insertion, onAppear publication, guessed native target and 16ms dismissal polling with an owned presentation subtree and UIKit completion callbacks. Added matching queue cancellation and action validation.
- Scene startup now awaits authenticated setup before cold URLs, buffers concurrent OS callbacks, and cancels/invalidates delivery when disconnected. No coordinator hierarchy or navigation stack redesign.
- Independent read-only review found a test could cancel the transparent SwiftUI host before its native alert appeared. Corrected the visible-native predicates to require an attached native alert with completed presentation; kept a separate immediate-cancellation test for both styles. No further confirmed production issue was found by static inspection; UIKit timing and warning removal remain unverified.
- Non-execution checks passed: project/Info.plist lint, shared scheme XML, Swift/XIB source/resource paths and XIB connection destinations, unchanged Swift 5/iOS 17 settings, and git diff whitespace checks.
- Source inventory: 49 native unit declarations, 25 UI methods; portable subset 23 declarations. No compilation or test execution was performed after the user's deferral. Runtime closure of AUD-14/AUD-17 is PENDING the user's build/test trace; prior 58/2 results do not validate this revision.
- No commit, merge or push performed for this revision.

## User-run result and focused follow-up

The user executed the 74-declaration suite in Xcode at 16:34:51. Read-only xcresult inspection found 72 passed / 2 failed declarations (83/3 expanded), all 25 UI methods passed, and three publication warnings on SwiftUI OK dismissal. The result lives in DerivedData, not the example /private/tmp path. No unsupported-containment warning was recorded.

Ruling: keep the passing URL delivery implementation. Native failures share a test harness that installed content after making a fresh window visible and immediately presented; correct its order and wait for actual appearance, rather than increase timeouts. Add caller source attribution and await renderer cleanup during teardown to diagnose any remaining lifecycle failure precisely.

The warning occurs at native SwiftUI dismissal, which wrote the alert binding directly into a Published property. Keep readiness signaling observable but move the dismissal binding into local State, so that update does not publish objectWillChange. This is a focused correction; no architecture simplification.

These post-result source changes are not built or tested. Agent execution remains prohibited by the user's instruction; a new user run is needed.

## Latest verification — user run passed

Completed bundle `Test-CoordinatorNavigationDemo-2026.11.07_16-59-02-+0200.xcresult`: 49 unit + 25 UI declarations passed (74 total; 86 expanded runs), zero failed/skipped and zero recorded runtime warnings on iPhone 17 / iOS 27.0. Console inspection found neither the unsupported hosting insertion nor publication-during-update warning. The user executed this run; the agent only read the artifacts.

The requested cold/warm/background URL and native alert regression baseline is now green. Do not interpret this as completion of the broader architecture audit: capacity policies, full staged cancellation/deallocation profiling, earlier coordinator redundancy and minimum-OS runtime coverage remain separate work. Eight UIKit locked-focus-environment console entries remain in native test-window fixture methods, with no corresponding UI-test entries or recorded runtime warnings; cause unproven and documented for targeted investigation.

Only documentation was updated after result inspection. No further source change, build, test execution, commit, merge or push performed.
