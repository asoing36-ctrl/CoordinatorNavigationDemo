# Navigation validation follow-up

Baseline: `9cddb39`, committed after user-owned 97-declaration/111-expanded passing Simulator results. Implements the next three items from the [audit crosswalk](../audits/implementation-status.md) and [strict review](../audits/navigation-strict-review-2026-11-07.md).

## Scope and rulings

- Keep Swift 5, iOS 17, one router/navigation stack and real XIBs. No backend, account, diagnostics or coordinator-retention redesign.
- Ruling: continue in the existing feature checkout so the user's Xcode sees the edits, as in the prior phase. No additional worktree, merge or push.
- Ruling: the user authorized these next review items; no additional design-approval round. Use native UIKit transitions and test-only probes rather than new production observability APIs solely for tests.
- The user owns all builds/tests. Write cases before any necessary source change, but do not execute tests/compilers/Simulator or claim RED/GREEN. The committed baseline pass does not validate this follow-up.
- Apple's [adaptive dismissal callbacks](https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerwilldismiss(_:)) are not emitted for programmatic dismissal. A custom test-only presentation controller bridges those callbacks from a real interactive transition. This validates the router's cancellation path, not the OS sheet-pan recognizer. Keep the native sheet UI gesture as complementary coverage and retain device gesture verification as a release gate.

## Task 1 — Interactive cancellation

Files: native follow-up tests, a test-only custom sheet/transition probe, native project membership and portable exclusions.

- [x] Write real-router presentation/attachment setup.
- [x] Write a real UIPercentDrivenInteractiveTransition probe requiring isInteractive, callback registration, queued work and UIKit's cancelled completion.
- [x] Write exact modal identity/route/stack assertions and subsequent ordinary dismissal/presentation coverage.
- [x] Preserve the real sheet UI smoke test; document that a short drag alone does not prove cancellation.
- [x] User executed the controlled cancellation case in focused and full runs; passed. Native OS sheet-pan delivery remains a separate gate.

## Task 2 — Scene disconnect and release

Files: App/AppDelegate.swift, shared native-window harness, native follow-up tests.

- [x] Extract production scene connection setup into an internal method consuming UIWindow/URLs/authentication. The system callback continues to parse options and call it. UIScene.ConnectionOptions has no public initializer, so no fabricated options or runtime/KVC injection are used.
- [x] Write cases with a separate SceneDelegate and attached window lease, invoking actual sceneDidDisconnect during held navigation/presentation and owned alert presentation.
- [x] Write native completion, obsolete controller release, callback suppression and weak router/root/modal/navigation release assertions. Restore the host's original window.
- [x] User executed all three disconnect parameter cases; passed. Actual OS-driven scene destruction remains a separate release gate.

## Task 3 — Callback reentrancy

Files: native follow-up tests and NavigationUITests.swift.

- [x] Write observer-triggered root replacement and pending cancellation cases requiring no nested transitions/obsolete work.
- [x] Write rejection-callback recovery with a valid replacement/push.
- [x] Write a real UI Cancel → next distinct error → usable original navigation case.
- [x] User executed focused native/UI cases and the full suite; passed.

## Verification / completion

Static checks: project/plist syntax, source/resource membership, XML, Markdown links and staged/working diff checks. Runtime: user runs NavigationReliabilityTests and the new UI method, then all suites. Tests require actual native engagement/completion; no timeout extension or elapsed-time success.

At handoff, distinguish source-written from executed coverage. Record one final independent read-only review. Do not automatically commit the new unexecuted work with the previously verified baseline.

## Ledger

- Commit `9cddb39` captured prior navigation hardening, strict review and audit status. Index/working tree were clean immediately afterward. One trailing blank line in a new test helper was trimmed before commit; no behavior changed.
- Pre-flight: all tasks share the native-window lease. Scene lifecycle cases need a separate delegate/window, not disconnection of the host app's actual delegate. Test helpers remain native-target only.
- At implementation handoff, source/static review was complete and all runtime execution was deferred to the user.
- Ruling: pass an explicit UIWindow into shared scene connection setup rather than UIWindowScene. This keeps production window ownership visible and lets a test UIWindow install its appearance probe before makeKeyAndVisible; no composition accessors or test-only production flags are needed.
- Wrote 5 native declarations (disconnect has 3 cases) and 1 UI method. The user's subsequent full run passed all 76 unit + 27 UI = 103 declarations, with 119 expanded runs.
- Production diff is limited to scene connection extraction; router/business behavior is unchanged. Native custom-sheet callbacks deliberately bridge programmatic interaction and do not establish native sheet-pan delivery.
- Final independent read-only review found two P2 test-support defects: a stored rejection callback strongly captured its router, and the presentation probe reused a historical interactive flag when forwarding a later ordinary dismissal. Restored the original callback in defer; separated per-attempt interaction state and asserted zero adaptive didDismiss calls after cancelled interaction plus ordinary dismissal. No production blocker or unavailable SDK symbol was identified through source/header inspection.
- One source fix pass addressed both findings. No agent re-review, compiler or test execution followed; the user's later runs provide runtime evidence. No claim was made that the agent observed a RED/GREEN cycle for the added cases.
- Inspected user bundles 21:32 (5 native declarations/7 expanded passed), 21:34 (1 UI method passed), and 21:35 (76 unit + 27 UI declarations/119 expanded passed). All had zero failures/skips/recorded runtime warnings on iPhone 17/iOS 27.0 Simulator. Weak release, interaction cancellation and callback recovery assertions passed.
- Only verification documentation changed after result inspection. The user then requested committing the verified follow-up and its evidence; no push was requested. Native sheet-pan/OS scene destruction and broader OS/device/Release/profiling gates remain open. See [Verification.md](../Verification.md) for exact bundle names and remaining unit-console diagnostics.
