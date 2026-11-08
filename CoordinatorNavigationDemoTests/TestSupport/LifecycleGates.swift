import Foundation
@testable import CoordinatorNavigationDemo

/// A one-shot suspension whose entry and cancellation remain observable.
/// Cancellation deliberately does not open it: tests choose when a late API returns.
@MainActor final class LifecycleGate {
    private(set) var arrivals = 0
    private(set) var cancellations = 0
    private var open = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func pause() async {
        arrivals += 1
        guard !open else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiting.append($0) }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancellations += 1 }
        }
    }
    func release() {
        open = true
        let continuations = waiting
        waiting.removeAll()
        for continuation in continuations { continuation.resume() }
    }
}

@MainActor final class LifecycleTrace {
    enum Event: Equatable { case phoneReturned, environmentReset }
    private(set) var events: [Event] = []
    func record(_ event: Event) { events.append(event) }
}

/// Runs before the native window lease is released, including throwing paths.
/// Explicit ownership here keeps noncooperative operations joinable during cleanup.
@MainActor final class LifecycleCleanup {
    private let gates: [LifecycleGate]
    private var apps: [AppCoordinator] = []
    private var tasks: [Task<Void, Never>] = []
    var phone: OnboardingCoordinator?

    init(gates: [LifecycleGate]) { self.gates = gates }
    func track(_ app: AppCoordinator) { apps.append(app) }
    func track(_ task: Task<Void, Never>) { tasks.append(task) }
    func joinPhone() async { await phone?.waitForOperation(); phone = nil }
    func finish() async {
        for app in apps { app.stop() }
        let diagnostics = apps.compactMap { $0.demo.cancelMetrics() }
        for gate in gates { gate.release() }
        await joinPhone()
        for task in tasks { await task.value }
        for task in diagnostics { await task.value }
        tasks.removeAll()
        for app in apps { await app.waitForOperation() }
        apps.removeAll()
    }
}

@MainActor func withLifecycleCleanup(_ cleanup: LifecycleCleanup, _ body: @MainActor () async throws -> Void) async rethrows {
    do { try await body(); await cleanup.finish() }
    catch { await cleanup.finish(); throw error }
}

@MainActor func nextLifecycleMainQueueTurn() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async { continuation.resume() }
    }
}

actor GatedCredentialRepository: CredentialRepository {
    enum Stage: Equatable, Sendable { case create, login, redeem, phone }
    enum Position: Equatable, Sendable { case before, after }
    private let backend: MockBackend
    private let stage: Stage
    private let position: Position
    private let gate: LifecycleGate
    private let ignoreCancellation: Bool
    private let codeFilter: String?
    private let trace: LifecycleTrace?

    init(backend: MockBackend, stage: Stage, position: Position = .after, gate: LifecycleGate,
         ignoreCancellation: Bool = true, codeFilter: String? = nil, trace: LifecycleTrace? = nil) {
        self.backend = backend; self.stage = stage; self.position = position; self.gate = gate
        self.ignoreCancellation = ignoreCancellation; self.codeFilter = codeFilter; self.trace = trace
    }
    private func perform<Value: Sendable>(stage current: Stage, code: String? = nil,
        operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let gated = stage == current && (codeFilter == nil || codeFilter == code)
        if gated, position == .before { await gate.pause() }
        let value: Value
        if ignoreCancellation { value = try await Task.detached(operation: operation).value }
        else { try Task.checkCancellation(); value = try await operation() }
        if gated, position == .after { await gate.pause() }
        if current == .phone { await trace?.record(.phoneReturned) }
        return value
    }
    func resolveAccount(code: String) async throws -> Account? { try await backend.resolveAccount(code: code) }
    func createAccount(code: String) async throws -> Account {
        let backend = backend
        return try await perform(stage: .create, code: code) { try await backend.createAccount(code: code) }
    }
    func login(account: Account) async throws -> UserSession {
        let backend = backend
        return try await perform(stage: .login) { try await backend.login(account: account) }
    }
    func redeem(code: String, session: UserSession) async throws -> [Credential] {
        let backend = backend
        return try await perform(stage: .redeem, code: code) { try await backend.redeem(code: code, session: session) }
    }
    func associatePhone(accountID: String, simulateFailure: Bool) async throws {
        let backend = backend
        try await perform(stage: .phone) { try await backend.associatePhone(accountID: accountID, simulateFailure: simulateFailure) }
    }
}

actor GatedMockEnvironment: MockEnvironmentManaging {
    private let backend: MockBackend
    private let seedGate: LifecycleGate?
    private let trace: LifecycleTrace?
    init(backend: MockBackend, seedGate: LifecycleGate? = nil, trace: LifecycleTrace? = nil) {
        self.backend = backend; self.seedGate = seedGate; self.trace = trace
    }
    func reset() async { await trace?.record(.environmentReset); await backend.reset() }
    func seedAuthenticatedSession() async -> UserSession {
        await seedGate?.pause()
        return await backend.seedAuthenticatedSession()
    }
    func ownedCredentials(accountID: String) async -> [Credential] { await backend.ownedCredentials(accountID: accountID) }
    func metrics() async -> BackendMetrics { await backend.metrics() }
}
