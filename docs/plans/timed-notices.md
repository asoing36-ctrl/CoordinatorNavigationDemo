# Timed alerts and snackbars implementation plan

**Goal:** support timed and user-dismissed informational notices from SwiftUI and
UIKit, without changing recovery choices or the authoritative navigation stack.

**Architecture:** extend AppAlertRequest with presentation and optional duration.
Reuse its validated bounded queue for each channel. Modal alerts keep the current
owned presentation lifecycle. Snackbars use a scene-bound, non-key, touch-through
UIKit window, with no navigation controller; this keeps them visible above feature
modals while navigation proceeds. A small injected clock/timer owns foreground
remaining time and obsolete-task cancellation for both presentations.

**Constraints:** Swift 5; iOS 17; one UINavigationController; real XIB screens;
no dependencies. Work in the current checkout on a feature branch so Xcode sees
changes. No automatic commit, merge or push. Baseline e07e6f5 passed 148 declarations
/ 237 expanded cases in the user's full run.

## Decisions and authorization

- The user requested implementation, then confirmed both timed and user-dismissed
  types after the proposed persistent-recovery policy. Proceed with that authorized
  behavior inline, using writing-plans/executing-plans, without another permission
  gate. Four seconds is the proposed demo default, configurable per request.
- Informational timed alerts and all snackbars must be global, OK-only notices.
  Retry/Cancel recovery remains manual; invalid configurations are rejected before
  queue ownership. Expiry removes the notice without synthesizing a user action.
- Timers start after visible native presentation. Inactive scenes pause remaining
  time. Modal alerts hide/pause snackbars; native cleanup resumes them. Reset/stop
  cancel all notices and tasks. Root replacement preserves global notices.
- Channels are independently bounded and deduplicated; modal recovery has priority.
  No cross-channel FIFO claim. The snackbar overlay never becomes key and consumes
  touches only inside its banner; no navigation state is mirrored there.
- The snackbars use one UIKit renderer over either UI technology. Existing UIKit
  and SwiftUI modal alert renderers both gain timing support.

## Tasks and ledger

1. [x] Write portable clock/policy tests; observe RED. Implement request validation
   and ForegroundNoticeTimer; run portable tests GREEN.
2. [x] Add native timing, cancellation and ownership tests using a manual clock.
   Integrate timed modal cleanup and nonblocking SnackbarPresenter into the router.
   Preserve existing alert protocol/callback behavior and original native sources.
3. [x] Add SwiftUI and XIB demo controls and native UI tests for timed/manual
   notices, underlying navigation, feature modal preservation and later presentation.
4. [x] Register native/package sources and update docs. Run supported checks and
   attempt native execution; report session limitations rather than claim passes.
5. [x] One final fresh-context read-only review. Fix concrete Important/Critical
   findings in one pass; retain explicit evidence limits for OS/device timing.

Review focus: presentation timer cannot start in a queue; pause/expiry races must
not acknowledge business operations; cancelled tasks must not expire later notices;
snackbar touch passthrough and non-key ownership; reset/stop must release window,
controller, timer and queued callbacks; existing protected Back remains enforced.

## Execution evidence / rulings

- Portable RED failed at missing NoticeClock; GREEN passed **38 declarations / 5
  suites**, including all 8 new timer/admission declarations (10 cases). Logs:
  `/private/tmp/coordinator-timed-notices-red.log` and `-green.log`.
- User then stated they will run tests. No further tests/native app launches will
  be initiated by the agent in this task. Remaining native RED/GREEN is deferred
  to the user; test-first source order is not claimed as native execution evidence.
- Partial UIKit helper typechecking passed, Swift 5 / iOS 17 Simulator SDK /
  complete concurrency, no diagnostics. It excludes router/SwiftUI/app/test targets.
- Project parsed with plutil: 41 Swift/XIB references resolve, all 17 unit source
  files are registered once, both real XIBs' outlets/actions resolve, version floors
  unchanged. Native source inventory is 131 unit + 37 UI = 168 declarations /
  expected 268 expanded runs. Initial portable pass is not a full native pass.
- Ruling: keep one UIKit snackbar renderer, shared by UIKit/SwiftUI origins, instead
  of duplicating banner implementations. A non-key touch-through overlay window is
  required to remain visible above feature modals without inserting subviews into
  SwiftUI-owned hosting views or introducing competing navigation.
- Ruling: timed SwiftUI alerts wait for actual nested native visibility via one
  cancellable bounded observer. Existing persistent renderers keep their lifecycle.
  Expiry uses cancellation cleanup and never an OK/Retry/Cancel callback.

## Final source review

One fresh-context read-only review found no Critical/Important defects in timer
cancellation, scoped admission, modal cleanup, snackbar queue reentrancy, reset/
stop teardown, native source membership or XIB/controller call sites. No reviewer
builds/tests/network were run. The optional suggestion to reset hasAppeared on
window disappearance is deferred: the current flag records a prior successful
appearance, and resume also requires an unhidden attached window and active scene.
Changing that without knowing hide/show callback delivery could strand a timer.

Native compilation/execution remains pending, especially iOS 17 SwiftUI native
alert discovery, non-key overlay appearance, accessibility, keyboard and rotation.
Those limitations are explicit in TimedNotices.md and Verification.md. No claims
of production readiness, universal lifecycle correctness or new native passes.

- [x] User-run NoticeTimerTests, TransientNoticeTests, four UI workflows, full scheme
  inspected; all unit tests passed. The corrected complete UI suite subsequently
  passed all 37 methods, resolving the four earlier tap failures.
- [x] Inspect user result bundles and update actual outcomes before committing.

## User native execution and failure follow-up — 2026-11-08

- Focused `21-12-06` bundle: NoticeTimerTests **8 declarations / 10 cases passed**.
- Focused `21-13-14` bundle: TransientNoticeTests **8 declarations / 17 cases passed**.
- Full `21-14-20` bundle: **131/131 unit passed**, **33/37 UI passed**; total
  **164/168 declarations / 264/268 expanded runs passed**. All four new notice UI
  workflows passed. iPhone 17 / iOS 27.0 Simulator arm64; no skips/recorded runtime
  warnings. Exact artifact names and limits are in Verification.md.
- Four old recovery UI methods failed at the final next-sheet assertion. All four
  exported tap-down events are in status chrome (y55–58), after business, state
  and recovery assertions passed. The Home final hierarchy shows the actual
  presentation button at y688–740; UIKit never received the intended button tap.
- Ruling: correct the UI interaction, not the production router. Replace only the
  final scroll/tap with a fully-visible-content-row check and one measured center
  coordinate tap. Keep all acceptance assertions, five-second timeout and original
  six-scroll bound. Attach safe geometry on failure; no retry/fallback tap.
- Corrected UI source typechecking passed with the SDK's XCTest Swift overlay path
  (Swift5/iOS17 complete concurrency, no diagnostics). The initial standalone
  command lacked that path; no project code was changed to address the command.
- The user will rerun all six recovery UI methods and then the full scheme. Native
  execution of this correction remains pending. No commit or further tests run.

## Passing corrected UI verification and integration — 2026-11-08

- `Test-CoordinatorNavigationDemo-2026.11.08_21-46-44-+0200.xcresult` is a **UI-only**
  run: **37/37 UI methods passed**, zero failures/skips/recorded runtime warnings,
  iPhone 17 / iOS 27.0 Simulator arm64. The full tree confirms all six recovery
  workflows and all four new timed/snackbar workflows passed.
- The 21:14 full run previously passed all **131 unit declarations / 231 cases**.
  Only the UI helper and docs changed afterward. Combined coverage is **168
  declarations / 268 cases across separate runs**, not one new full-scheme pass.
- The user explicitly requested updated docs, commit and local merge into main.
  Native test execution remains user-owned; source changes since the passing UI
  rerun are documentation only. A fast-forward preserves the same tested source
  tree without integration edits. No remote push is part of this instruction.
- Wider iOS17/current OS, device/accessibility/keyboard/rotation and OS-driven
  suspension/native-button-reset overlap remain separate gates.
