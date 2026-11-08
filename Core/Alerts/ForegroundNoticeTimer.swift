import Foundation

/// Monotonic time; native presentations and tests share the same timing contract.
@MainActor protocol NoticeClock: AnyObject {
    var now: Duration { get }
    func sleep(until deadline: Duration) async throws
}

@MainActor final class SystemNoticeClock: NoticeClock {
    private let origin = ContinuousClock.now
    var now: Duration { origin.duration(to: .now) }
    func sleep(until deadline: Duration) async throws {
        try await ContinuousClock().sleep(until: origin.advanced(by: deadline))
    }
}

/// Counts only resumed time. Cancellation invalidates even a ready/noncooperative sleep.
@MainActor final class ForegroundNoticeTimer {
    private let clock: any NoticeClock
    private var remaining: Duration
    private var startedAt: Duration?
    private var work: Task<Void, Never>?
    private var generation = UUID()
    private var expiration: (() -> Void)?

    init(duration: Duration, clock: any NoticeClock, expiration: @escaping () -> Void) {
        self.clock = clock; remaining = duration; self.expiration = expiration
    }
    func resume() {
        guard work == nil, expiration != nil else { return }
        let clock = clock
        startedAt = clock.now
        let deadline = clock.now + remaining
        let token = UUID(); generation = token
        work = Task { [weak self] in
            do { try await clock.sleep(until: deadline) } catch { return }
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.work = nil; self.startedAt = nil; self.remaining = .zero
            let callback = self.expiration; self.expiration = nil
            callback?()
        }
    }
    func pause() {
        if let startedAt { remaining = max(.zero, remaining - (clock.now - startedAt)) }
        startedAt = nil
        generation = UUID()
        work?.cancel(); work = nil
    }
    @discardableResult func cancel() -> Task<Void, Never>? {
        let task = work
        pause(); expiration = nil
        return task
    }
    deinit { work?.cancel() }
}
