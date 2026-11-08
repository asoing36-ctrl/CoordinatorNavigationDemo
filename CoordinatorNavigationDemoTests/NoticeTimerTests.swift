import Foundation
import Testing
@testable import CoordinatorNavigationDemo

@MainActor struct NoticeTimerTests {
    @Test func timerStartsOnlyWhenVisibleAndExpiresOnce() async throws {
        let clock = ManualNoticeClock()
        var expirations = 0
        let timer = ForegroundNoticeTimer(duration: .seconds(4), clock: clock) { expirations += 1 }
        clock.advance(by: .seconds(100))
        #expect(clock.waitingCount == 0 && expirations == 0)
        timer.resume()
        try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(3))
        #expect(expirations == 0)
        clock.advance(by: .seconds(1))
        try await waitForNoticeCondition { expirations == 1 }
        timer.resume(); clock.advance(by: .seconds(100))
        #expect(expirations == 1)
    }

    @Test func backgroundTimeDoesNotConsumeRemainingDuration() async throws {
        let clock = ManualNoticeClock()
        var expirations = 0
        let timer = ForegroundNoticeTimer(duration: .seconds(4), clock: clock) { expirations += 1 }
        timer.resume(); try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(1)); timer.pause()
        try await waitForNoticeCondition { clock.waitingCount == 0 }
        clock.advance(by: .seconds(100))
        #expect(expirations == 0)
        timer.resume(); try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(2)); #expect(expirations == 0)
        clock.advance(by: .seconds(1))
        try await waitForNoticeCondition { expirations == 1 }
    }

    @Test func obsoleteSleepCannotExpireAResumedTimer() async throws {
        let clock = ManualNoticeClock(ignoreCancellation: true)
        var expirations = 0
        let timer = ForegroundNoticeTimer(duration: .seconds(4), clock: clock) { expirations += 1 }
        timer.resume(); try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(1)); timer.pause()
        clock.advance(by: .seconds(2)); timer.resume()
        try await waitForNoticeCondition { clock.waitingCount == 2 }
        clock.advance(by: .seconds(1)) // The old deadline; new deadline is two seconds later.
        try await waitForNoticeCondition { clock.waitingCount == 1 }
        #expect(expirations == 0)
        clock.advance(by: .seconds(2))
        try await waitForNoticeCondition { expirations == 1 }
    }

    @Test func cancellationSuppressesAnAlreadyReleasedSleepAndReleasesOwner() async throws {
        let clock = ManualNoticeClock(ignoreCancellation: true)
        var expirations = 0
        var timer: ForegroundNoticeTimer? = ForegroundNoticeTimer(duration: .seconds(4), clock: clock) { expirations += 1 }
        weak var owner = timer
        timer?.resume(); try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(4)) // Ready to return, but its main-actor continuation has not run.
        let work = timer?.cancel()
        timer = nil
        await work?.value
        #expect(expirations == 0 && owner == nil)
    }

    @Test func elapsedDeadlineWhilePausedWaitsForResume() async throws {
        let clock = ManualNoticeClock()
        var expirations = 0
        let timer = ForegroundNoticeTimer(duration: .seconds(4), clock: clock) { expirations += 1 }
        timer.resume(); try await waitForNoticeCondition { clock.waitingCount == 1 }
        clock.advance(by: .seconds(4)); timer.pause()
        #expect(expirations == 0)
        timer.resume()
        try await waitForNoticeCondition { expirations == 1 }
    }

    @Test func automaticNoticesCannotOwnRecoveryActions() {
        let queue = AppAlertQueue()
        let recovery = AppAlertRequest(key: "recovery", style: .uikit, title: "Recovery", message: "",
            actions: [.retry, .cancel], dismissAfter: .seconds(4))
        #expect(queue.enqueue(recovery) == .invalidConfiguration)
        let snackbar = AppAlertRequest(key: "flow", style: .uikit, title: "Flow", message: "", presentation: .snackbar)
        #expect(queue.enqueue(snackbar) == .invalidConfiguration)
        #expect(queue.pendingCount == 0 && queue.current == nil)
        #expect(queue.enqueue(.redeemFailure(message: "Retry", style: .swiftUI)) == .accepted)
    }

    @Test(arguments: [Duration.zero, .seconds(-1), .seconds(86_401)])
    func invalidDurationsAreRejectedBeforeQueueOwnership(duration: Duration) {
        let queue = AppAlertQueue()
        let request = AppAlertRequest(key: "invalid-duration", style: .uikit, title: "Notice", message: "",
            scope: .global, dismissAfter: duration)
        #expect(queue.enqueue(request) == .invalidConfiguration)
        #expect(queue.pendingCount == 0)
    }

    @Test func manualAndTimedInformationalRequestsAreAcceptedAndKeepTheirPolicy() {
        let queue = AppAlertQueue(); queue.sceneIsActive = true
        let timed = AppAlertRequest.timedDemo(style: .swiftUI)
        let manual = AppAlertRequest.snackbarDemo(timed: false)
        #expect(queue.enqueue(timed) == .accepted && queue.enqueue(manual) == .accepted)
        #expect(queue.beginNext()?.dismissAfter == .seconds(4))
        queue.cancel(id: timed.id)
        #expect(queue.beginNext()?.presentation == .snackbar)
        #expect(queue.current?.dismissAfter == nil)
    }
}

/// Test-only monotonic clock. Its noncooperative mode exposes stale cancellation races.
@MainActor final class ManualNoticeClock: NoticeClock {
    private struct Waiter {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Error>
    }
    private(set) var now: Duration = .zero
    var waitingCount: Int { waiting.count }
    private var waiting: [UUID: Waiter] = [:]
    private let ignoreCancellation: Bool
    init(ignoreCancellation: Bool = false) { self.ignoreCancellation = ignoreCancellation }
    func sleep(until deadline: Duration) async throws {
        try Task.checkCancellation()
        if deadline <= now { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiting[id] = Waiter(deadline: deadline, continuation: $0) }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, !self.ignoreCancellation else { return }
                self.waiting.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
            }
        }
    }
    func advance(by duration: Duration) {
        precondition(duration >= .zero)
        now += duration
        let due = waiting.filter { $0.value.deadline <= now }
        for (id, _) in due { waiting.removeValue(forKey: id) }
        for (_, waiter) in due { waiter.continuation.resume() }
    }
}

@MainActor func waitForNoticeCondition(_ condition: @MainActor () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
    try #require(condition(), "The observable notice condition must complete", sourceLocation: sourceLocation)
}
