# Lifecycle timing coverage

Baseline `981a91b`: user-run 118 declarations / 136 expanded cases passed on iPhone 17/iOS 27.0 Simulator. The user authorized deterministic lifecycle coverage; no new feature, Swift upgrade, deployment change or architectural simplification is planned.

## Approach and scope

- Inject the existing CredentialRepository into redeem/phone operations. Keep mock reset/seed/metrics administration separate through a small MockEnvironmentManaging boundary implemented by the existing backend. Default composition still uses the same actor for both.
- Test-only actors wrap the real backend and wait on explicit stage gates. A noncooperative mode performs the real backend call in an awaited detached task, representing a server operation that caller cancellation cannot undo. The test still joins/release all work; no private UIKit APIs or duration-based success.
- Cover reset after account creation/login/credential grant, stop with a late result, phone reset/stop, and weak child release. Reset must join cancelled redemption and phone work before resetting the mock environment; terminal stop suppresses callbacks without synchronously waiting for a remote API.
- Cover phone completion with a visible or inactive-buffered global notice in both renderer styles. Normal root replacement preserves the notice; administrative fixture cleanup is explicitly cancellation, not a synthesized user acknowledgment.
- Expose the existing AlertPresentation selection boundary internally to both renderers and @testable tests. Native tests select then cancel before queued dismissal and require one cancelled completion with the underlying feature modal intact. This does not synthesize a button tap. Separate coordinator tests invoke an actually captured old action callback against a new held flow.
- Scene connection accepts an explicitly constructed composition and returns its startup Task; default system entry is unchanged. A separate test delegate/window disconnects during held seeding, reconnects to a second held startup, and releases the old startup before the new one to prove the new URL buffer is untouched.

## Implementation sequence

1. Write lifecycle gate/wrapper utilities and tests before necessary production changes. Test gates expose actual entry/cancellation, not guessed sleeps.
2. Add constructor injection, retain cancelled onboarding task for joining, and join that child during reset. Add internal action and scene-startup ownership seams without test-only production flags.
3. Register native tests/support and portable exclusions. Perform source/config/XML/link checks, one independent read-only review and one fix pass for concrete findings.

## Constraints / ledger

- User owns all builds, compiler/test/Simulator execution. Claim passing cases only from inspected user artifacts; never attribute a user run to agent execution. The baseline and later results validate their own source snapshots.
- Ruling: use the current feature checkout so the user's Xcode sees the edits; the prior recommendation and explicit instruction authorize this focused scope without another approval round.
- No new network/backend feature, generic DI container, event bus, package or queue implementation. Constructor-injected repository/environment must refer to the same mock environment in this demo.
- Baseline source finding: OnboardingCoordinator.stop dropped the task handle; AppCoordinator.reset could reset backend state while noncooperative phone work was still outstanding. Retain/join that operation before environment reset.
- Work remains uncommitted until requested. OS-driven scene destruction, native sheet-pan delivery and physical-device/profiling validation remain separate.
- Current status: the user's newest full run passed all 99 unit + 27 UI declarations / 152 expanded runs. The separate UI suite passed 27/27. Both queue lifetime and sheet gesture follow-ups passed. The user requested committing this verified revision; wider OS/device/audit acceptance is not claimed.

## Source inventory and final review — 2026-11-08

- Eight new native declarations; source inventory is 99 unit + 27 UI = 126. Native project references both LifecycleTimingTests and LifecycleGates exactly once. The portable subset remains 30 declarations; UIKit files are excluded.
- One fresh-context, read-only reviewer checked the working tree against baseline 981a91b. No Critical or definite production/API error was identified; the source-only verdict requested changes for test proof and cleanup. No second reviewer or test execution was requested.
- Important: immediate visible-notice assertions could pass while cancellation was queued. Fix: capture the original alert/owned presentation, allow queued dismissal to start, await settled native transitions, then assert exact identity, window attachment and router ownership before administrative cancellation. All four phone-notice variants passed in both user runs.
- Important: throwing gate/appearance assertions skipped task joins. Fix: native fixtures call async beforeClose cleanup on success/failure, including appearance-construction failure. LifecycleCleanup stops owners, opens gates, joins reset/phone/redeem work and drops retained references. Scene fixtures retain/join every startup handle before final window/lease release. The direct alert test also awaits its exact completion during cleanup. The lifecycle suite passed; the user's run did not deliberately induce construction failure.
- Final: Ruling: the review's selection-positive-control suggestion is part of the Important false-positive test concern — parameterize selection-only versus selection-then-cancel for both renderers, keeping eight declarations. This proves that the expected cancellation result is not the only exercised selection outcome. Cost if wrong: test reliability still requires native execution; no synthesized tap is claimed.
- Final: Ruling: compiler acceptance, native animation/SwiftUI OS implementation, actual test results, OS-driven scene destruction, devices and final documentation were declined by the source reviewer — respect the user's execution boundary and document those unverified gates. Default behavior is judged by source only until the user's run; shipping without that evidence remains inappropriate.
- Static evidence: plutil accepted project/Info.plist; both XIBs/shared scheme parsed; all 34 Swift/XIB paths exist and match project membership; source files appear once in the native test phase; Swift 5.0/iOS 17.0 settings are unchanged. Whitespace checks passed for all 19 changed/new files, and changed-document local links/code fences passed. Static validation does not establish compilation, test success, absence of leaks or production readiness.
- Next: commit the verified code, tests and evidence together as requested, then continue OS/device/consuming-app validation separately; wider audit acceptance remains open.

## Earlier user results and queue failure follow-up — 2026-11-08, 09:49 / 09:51

- Inspected focused 09:49 bundle: 8/8 lifecycle declarations, 16/16 expanded runs passed. Full 09:51 bundle: 125/126 declarations, 151/152 expanded runs passed; all 27 UI methods and all lifecycle cases passed, zero skips/recorded runtime warnings. Exact paths/results are in Verification.md.
- Confirmed failure: QueuePolicyTests.fullNavigationQueueRejectsNewestAndStillAdmitsFlowReplacement, original line 73, weak duplicate still non-nil immediately after a lexical do scope. No other failure in either bundle. Rejection/flow-replacement assertions passed; the artifact does not identify the runtime retainer.
- Ruling: fix the test's uncontrolled lifetime boundary rather than changing router behavior — the adjacent-duplicate enqueue path returns without retaining/passing that controller to UIKit. Use an explicit autoreleasepool around construction and preserve immediate weak-release assertions. Add a positive control requiring accepted work retained until replacement clears it. Apply the same boundary to the matching duplicate-burst test. Cost if wrong: the rerun will still fail and require further ownership evidence; no test threshold or assertion is removed.
- This two-test follow-up is unbuilt/unexecuted. No production source changed after the user runs. The agent only read/exported existing results and performed static checks.
- Full-run console inspection: unit has 16 locked-focus/462 handler-drop entries; UI has zero of either; no matching unsupported-hosting/publication/unbalanced-appearance/unfinished-navigation diagnostics. Cause remains unestablished. No memory-profile or harmlessness claim.

## Queue resolution and sheet UI failure — 2026-11-08, 10:11 / 10:12

- Focused QueuePolicyTests: 8/8 declarations / 10 expanded runs passed. Full: all 99 unit passed, including accepted-work retention/release and duplicate-burst assertions; all lifecycle cases passed again. UI: 26/27 passed; total 125/126 declarations, 151/152 expanded runs, zero skips/recorded runtime warnings.
- Sole failure: NavigationUITests.testSheetSwipeDismissalAllowsPresentingAgain, original line 153. Done still existed after the gesture; the test did not reach its next presentation. The separate cancelled-sheet smoke test and native presentation/cancellation cases passed.
- Evidence from exported activity/event/hierarchy: screen 402×874; sheet remains at medium; native Sheet Grabber centered near (201, 423); drag starts on title near (105, 443) and ends at (201, 857), default velocity 500. Thus the input is diagonal and starts in SwiftUI content, not the native grabber. These artifacts do not prove whether a pan engaged/cancelled or a production router defect. The exported movie could not be decoded for offline frame inspection; no motion inference is made.
- Ruling: change only the UI test to target the actual native grabber — assert one hittable grabber, drag vertically once with explicit fast velocity, require disappearance in the original five-second budget, wait for interactive Home, then require a new UIKit presentation/dismissal. Keep failure screenshot/safe geometry attachments. No retries, fallback Done tap, enlarged timeout, router modification or new production diagnostics. Cost if wrong: the case still fails with stronger input/evidence; native OS/device validation remains open.
- SDK headers confirm the explicit velocity/hold coordinate API; no compiler was invoked. Static checks cover source/project/XML/Markdown only. This gesture follow-up remains unbuilt/unexecuted and all work uncommitted.
- Latest full-run console: native unit 16 locked-focus/465 handler-drop diagnostics, UI zero of either, no matched unsupported-hosting/publication/unbalanced-appearance/unfinished-navigation diagnostics. Cause remains unestablished. The agent inspected/exported existing artifacts only.

## Verified phase — 2026-11-08, 10:32 / 10:42

- User-owned UI run: 27/27 methods passed. Full run: 99/99 unit + 27/27 UI = 126 declarations / 152 expanded runs passed, zero failures/skips/recorded runtime warnings. Exact bundle paths are in Verification.md.
- Full test tree confirms all eight lifecycle declarations, queue saturation retention/release control, duplicate burst, completed sheet gesture and cancelled-sheet smoke passed. Activity evidence confirms the completed case used one native Sheet Grabber drag: horizontal offset zero, vertical travel 419.3 points, velocity 750 points/second; Home became interactive and a UIKit modal was presented/dismissed afterward.
- This verifies the selected lifecycle timing implementation on iPhone 17/iOS 27.0 Simulator. Real OS scene destruction, independent native sheet cancellation engagement, minimum-iOS/devices, Release, consuming-flow policy sizing and profiling remain separate gates. A controlled action-boundary test does not become a native button/reset overlap test because it passed.
- Full-run console counts remain native unit 16 locked-focus/465 handler-drop, UI zero of either, with no matched unsupported-hosting/publication/unbalanced-appearance/unfinished-navigation diagnostics. Diagnostic cause remains unestablished.
- Only documentation changed after inspecting these results. The agent ran no compiler/build/tests/Simulator/app and did not commit or push. All implementation/tests/evidence remain together in the working tree until requested.

## Commit handoff — 2026-11-08

- User explicitly requested committing the code after the verified full pass. Commit implementation, native resources/project membership, test support, tests and updated evidence as one revision on fix/navigation-behavior. No push or merge requested.
- Re-read the completed 10:42 result: 126 declarations / 152 expanded runs passed, zero failures/skips/recorded runtime warnings. No compiler/build/tests/Simulator/app run by the agent.
- Only documentation changes accompany the commit handoff; tested production/test source is unchanged after the successful user run. Earlier ledger notes describe their historical uncommitted/unexecuted state.
