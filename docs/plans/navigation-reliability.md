# Navigation reliability

Baseline: 5bb132a. The user clarified that this phase should improve navigation itself, not demo account/backend behavior. Keep Swift 5, iOS 17, one UINavigationController and the existing coordinators.

## Scope and approach

- Keep route/controller metadata until UIKit confirms a transition completed. A cancelled interactive pop must restore the same controller identity and route metadata.
- Reconcile the Back button and interactive-pop recognizer after transitions; do not disable the gesture while it is driving a transition.
- Add cancelPendingNavigation to clear waiting commands without interrupting UIKit's current animation. The router remains usable for a later authorized root/flow.
- AppCoordinator invokes invalidation at reset/stop before cancelling alerts, so alert cleanup cannot drain obsolete routes. These are the only coordinator changes; account/session/business behavior is unchanged.
- Test push/pop/popTo, duplicate queued pushes, protected Back, interactive cancellation, replaceStack, modal dismissal → push, dismiss → present, and replacement during presentation through an attached real UIKit stack.
- Reuse the existing native-window appearance/async-cleanup fixture. A test-only forwarding delegate supplies public UIKit custom/interactive animators to hold transitions; no production animation factory or private API.
- Share a main-actor window lease across native suites so concurrently scheduled tests cannot replace each other's key window.

## Acceptance

1. Ending a flow releases waiting protected screens and modals; completing the already-running transition cannot display them.
2. Subsequent authorized root replacement still runs and becomes the sole root.
3. Cancelled interactive Back preserves restored controller identity, route lookup and the ability to popTo it.
4. Completed transitions drain queued navigation once and suppress duplicate routes.
5. Protected Back blocks router/direct UIKit pop, popTo and interactive begin. Explicit replacement restores ordinary Back afterward.
6. Modal transitions complete in order, preserve the underlying controller objects and clear presentation metadata.
7. The existing mixed SwiftUI/XIB, alert and deep-link UI workflows remain covered by the unchanged UI suite.

## Deferred by user direction

Controlled business-repository injection, account/login cancellation fixtures, backend reset changes, phone-task joining, child-retention simplification and diagnostics restructuring are outside this phase. No demo code or backend behavior was added. AUD-03 and the navigation portion of AUD-05 guide this work; broader AUD-02 remains deferred.

## Execution ledger

- Ruling: work in the existing project checkout on fix/navigation-behavior so the user's Xcode sees the edits. Baseline is clean commit 5bb132a; no merge/push/commit requested for this revision.
- The user explicitly deferred all builds and test execution to local Xcode runs. Regression tests were written first but not executed; do not claim RED/GREEN, compilation success or current runtime validation.
- Source finding: synchronizing during an animated pop pruned metadata that UIKit may restore on cancellation. Reconcile metadata and gesture enabled state only after transitioning becomes false.
- Source finding: stop did not clear the operation queue, and reset cleared it only at eventual root replacement. New invalidation drops waiting references early while leaving in-progress UIKit delegate completion intact.
- Initially added 21 native navigation declarations, a real edge-swipe UI case on SwiftUI/XIB, and shared test-only UIKit fixtures. Initial source inventory: 70 unit declarations / 26 UI methods; execution was deferred to the user.
- Static checks confirmed native source membership, plist/project syntax, XIB/scheme XML, Swift 5/iOS 17 settings and documentation links. Independent read-only reviews were addressed; the diff has no whitespace errors. These checks do not establish compilation or runtime behavior. The prior 74-pass result belongs to the baseline.

## Production navigation hardening

The user emphasized reuse in a project serving roughly one million users. Keep the production scope in navigation, with explicit [contracts and release gates](../NavigationContract.md); do not equate a demo/Simulator pass with a flawless component.

- Guard controller identity/ownership and replacement shape before UIKit mutation, reporting safe typed rejection reasons through an optional composition callback.
- Use an iterative, non-reentrant queue runner; coalesce only adjacent duplicate pushes and yield long synchronous batches. Queue observers cannot start another transition inside didShow.
- Track stack and modal completion independently. Do not animate an underlying stack hidden by a modal, and defer windowed requests while the scene is inactive. Initial/root replacement without modal cleanup remains usable before activation; modal cleanup plus replacement waits for activation.
- Tests cover those boundaries without backend/account assertions. No generic navigation framework or business DI layer was added.
- The first static review found the test probe reused an already-cancelled interactive animator for a later ordinary popTo. Restricted that injection to its unfinished transition; current runtime validation remains pending by user instruction.

## Final static review

- An initial test-only interactive animator could be reused by a subsequent ordinary popTo. Restricted injection to the unfinished interaction, preserving ordinary subsequent navigation.
- The later review found that documentation claimed every inactive root replacement proceeds immediately, but a queued modal dismissal correctly blocks until activation. Kept the safe behavior, documented the modal-cleanup exception and added a native regression for that exact sequence.
- Neither review compiled, built, executed tests or launched the Simulator. Runtime verification was pending at the time of review; later user-run results are recorded below.

## User-run failures and sequencing follow-up

- Inspected the user's 19:29 xcresult: 19 of 21 router declarations passed; 2 timed out (20 passed / 2 failed expanded cases). Only the router suite was selected.
- The failed waits occur after visible nonanimated root replacement followed immediately by push, in the inactive-root and protected-Back tests. Initial root and protected-Back assertions passed; the old timeout omitted actual stack/transition values.
- Source gap: replace did not hold the stack gate for its nonanimated display lifecycle; didShow only deferred its own drain, allowing an immediate external enqueue to bypass that deferral.
- Follow-up: reserve the display lifecycle for visible replacements, release completed transitions through a main-queue barrier, and cover same-top replacements without requiring an absent delegate callback. Detached construction remains synchronous.
- Added a parameterized immediate-push regression for new/reused roots. The failed waits now include safe route/transition/Back/rejection diagnostics. Current inventory: 71 unit declarations / 26 UI methods, including 22 router declarations.
- The user-provided failures were the RED evidence for the existing cases. The added regression and implementation were left for the user's targeted/full reruns, without any agent build/test execution.

## User-run verification completed

- Inspected the user's 20:50 result: **22/22 router declarations passed**, **24 expanded runs passed**, no failures/skips or recorded runtime warnings.
- Inspected the user's 20:52 full result: **71 unit + 26 UI declarations passed**, **111 expanded runs passed**, no failures/skips or recorded runtime warnings.
- Both original failures, both new/reused-root regression variants and the SwiftUI/XIB edge-swipe UI test passed. The prior timeout budgets and assertions were preserved.
- Unit console retains locked-focus/handler diagnostics; UI console has none of those messages. Counts and the limits of the evidence are in [Verification.md](../Verification.md). No memory-profile or physical-device validation is claimed.
- No production code changed after result inspection. Changes remain uncommitted on fix/navigation-behavior; no commit/merge/push was requested. Remaining production gates are minimum/current OS and physical-device coverage, long-session profiling and application-specific route/backlog policies.

## Independent strict review and audit reconciliation

The user requested another strict review agent. Its read-only assessment found no confirmed correctness blocker within the supported integration contract. It reported one P2 validation gap: the short sheet drag does not independently prove interactive dismissal engaged and cancelled. Scene-disconnect release and broader callback reentrancy coverage remain blind spots. No fixes or test additions were made during review. See the [strict report](../audits/navigation-strict-review-2026-11-07.md) and the [17-task audit crosswalk](../audits/implementation-status.md); broader architecture simplification is not complete.
