import Testing
import Combine
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct DiagnosticsIsolationTests {
    @Test(arguments: [false, true])
    func heldMetricsCannotDelayProtectedCompletionOrAuthenticatedNavigation(authenticated: Bool) async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let environment = HeldMetricsEnvironment(backend: backend, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        try await withNavigationWindow(backend: backend, environment: environment,
            beforeClose: { await cleanup.finish() }) { harness in
            let app = harness.composition.coordinator
            cleanup.track(app)
            let router = harness.composition.router
            let navigation = harness.composition.navigationController
            if authenticated {
                await app.reset(authenticated: true)
                app.home?.showSecondary()
                try await waitForNavigationCondition { router.routes == [.home, .secondary] && navigation.transitionCoordinator == nil }
            }
            let stack = navigation.viewControllers.map(ObjectIdentifier.init)
            app.submit(code: authenticated ? "ADD-CRED" : "NEW-USER")
            try await waitForNavigationCondition { gate.arrivals == 1 }
            try await waitForNavigationCondition(diagnostics: { "flow=\(app.flow.rawValue), routes=\(router.routes)" }) {
                app.flow == (authenticated ? .authenticated : .phoneAssociation) && navigation.transitionCoordinator == nil
            }
            await app.waitForOperation()
            if authenticated {
                #expect(app.processor.active == nil)
                app.submit(code: "EXISTING-USER"); await app.waitForOperation()
                #expect(app.session.credentials.count == 3)
                #expect(navigation.viewControllers.map(ObjectIdentifier.init) == stack)
            } else {
                #expect(navigation.topViewController is AssociatePhoneViewController)
                app.submit(code: "ADD-CRED")
                app.onboarding?.skip(); await app.waitForOperation()
                try await waitForNavigationCondition { router.routes == [.home] && navigation.transitionCoordinator == nil }
                #expect(app.session.credentials.count == 2)
            }
            #expect(app.processor.active == nil)
            #expect(!router.backBlocked)
            #expect(gate.arrivals == 1)
            gate.release()
            try await waitForNavigationCondition { gate.arrivals == 2 && app.demo.loginCount == (authenticated ? 0 : 1) }
        }
    }

    @Test func stoppingDuringSessionPublicationCannotPushPhone() async {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        let observation = app.session.$session.dropFirst().sink { [weak app] value in
            if value != nil { app?.stop() }
        }
        defer { observation.cancel() }
        app.start(); app.submit(code: "NEW-USER"); await app.waitForOperation()
        #expect(app.onboarding == nil && app.home == nil && app.redeem == nil)
        #expect(app.processor.active == nil)
        #expect(router.routes == [.welcome, .redeem])
    }

    @Test func resetDoesNotWaitForMetricsOrApplyItsObsoleteResult() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let environment = HeldMetricsEnvironment(backend: backend, gate: gate)
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend, environment: environment)
        let cleanup = LifecycleCleanup(gates: [gate])
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); app.submit(code: "NEW-USER")
            try await waitForNavigationCondition { gate.arrivals == 1 && app.flow == .phoneAssociation }
            let oldRead = try #require(app.demo.refreshMetrics())
            cleanup.track(oldRead)
            var published: [Int] = []
            let observation = app.demo.$loginCount.dropFirst().sink { published.append($0) }
            defer { observation.cancel() }
            let reset = Task { await app.reset(authenticated: true) }
            cleanup.track(reset)
            try await waitForNavigationCondition { router.routes == [.home] && !app.demo.busy }
            await reset.value
            #expect(app.demo.loginCount == 0)
            app.submit(code: "ADD-CRED"); await app.waitForOperation()
            #expect(app.session.credentials.count == 2)
            gate.release(); await oldRead.value
            #expect(!published.contains(1))
            #expect(app.demo.loginCount == 0)
        }
    }

    @Test func sessionOnlyMutationPublishesOneCoherentSnapshotWithoutNavigation() async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        app.start(); await app.reset(authenticated: true)
        let stack = router.screens.map { ObjectIdentifier($0.controller) }
        var snapshots: [NavigationDiagnostics] = []
        let observation = app.demo.$diagnostics.dropFirst().sink { snapshots.append($0) }
        defer { observation.cancel() }
        app.session.restore(session: UserSession(accountID: "demo"), credentials: [
            Credential(id: "one", name: "One", grantedPermissions: ["a"]),
            Credential(id: "two", name: "Two", grantedPermissions: ["b"])
        ])
        try await waitForNavigationCondition { app.demo.diagnostics.credentialCount == 2 }
        let snapshot = app.demo.diagnostics
        #expect(snapshot.flow == .authenticated)
        #expect(snapshot.isAuthenticated)
        #expect(snapshot.routes == [.home])
        #expect(snapshot.presentedRoute == nil)
        #expect(snapshot.permissions == ["a", "b"])
        #expect(snapshot.activeCoordinator == "HomeCoordinator")
        #expect(snapshot.pendingCount == 0 && !snapshot.backBlocked)
        #expect(!snapshots.isEmpty)
        #expect(snapshots.allSatisfy { $0.credentialCount != 2 || $0.permissions == ["a", "b"] })
        #expect(router.screens.map { ObjectIdentifier($0.controller) } == stack)
    }

    @Test(arguments: [false, true])
    func cancelledMetricsCannotPublishObsoleteValuesOrLoseANewRefresh(resetCount: Bool) async throws {
        let gate = LifecycleGate()
        let reader = ScriptedMetricReader(gate: gate)
        let model = DemoModel(readLoginCount: { await reader.read() })
        var published: [Int] = []
        let observation = model.$loginCount.dropFirst().sink { published.append($0) }
        defer { observation.cancel() }
        try await withDemoMetrics(model, gate: gate) {
            let first = try #require(model.refreshMetrics())
            try await waitForNavigationCondition { gate.arrivals == 1 }
            model.cancelMetrics(resetCount: resetCount)
            model.refreshMetrics()
            gate.release(); await first.value
            try await waitForNavigationCondition { model.loginCount == 7 }
            #expect(published == [7])
            #expect(await reader.reads == 2)
        }
    }

    @Test func metricsRefreshesCoalesceWithoutSpawningConcurrentReads() async throws {
        let gate = LifecycleGate()
        let reader = ScriptedMetricReader(gate: gate)
        let model = DemoModel(readLoginCount: { await reader.read() })
        try await withDemoMetrics(model, gate: gate) {
            let first = try #require(model.refreshMetrics())
            try await waitForNavigationCondition { gate.arrivals == 1 }
            for _ in 0..<20 { model.refreshMetrics() }
            #expect(await reader.reads == 1)
            gate.release(); await first.value
            try await waitForNavigationCondition { model.loginCount == 7 }
            #expect(await reader.reads == 2)
            #expect(await reader.maximumConcurrentReads == 1)
        }
    }
}

@MainActor private func withDemoMetrics(_ model: DemoModel, gate: LifecycleGate,
    _ body: @MainActor () async throws -> Void) async rethrows {
    do { try await body() }
    catch { let work = model.cancelMetrics(); gate.release(); await work?.value; throw error }
    let work = model.cancelMetrics(); gate.release(); await work?.value
}

private actor ScriptedMetricReader {
    let gate: LifecycleGate
    private(set) var reads = 0
    private var active = 0
    private(set) var maximumConcurrentReads = 0
    init(gate: LifecycleGate) { self.gate = gate }
    func read() async -> Int {
        reads += 1
        let value = reads == 1 ? 91 : 7
        active += 1; maximumConcurrentReads = max(maximumConcurrentReads, active)
        if reads == 1 { await gate.pause() }
        active -= 1
        return value
    }
}

private actor HeldMetricsEnvironment: MockEnvironmentManaging {
    let backend: MockBackend
    let gate: LifecycleGate
    init(backend: MockBackend, gate: LifecycleGate) { self.backend = backend; self.gate = gate }
    func reset() async { await backend.reset() }
    func seedAuthenticatedSession() async -> UserSession { await backend.seedAuthenticatedSession() }
    func ownedCredentials(accountID: String) async -> [Credential] { await backend.ownedCredentials(accountID: accountID) }
    func metrics() async -> BackendMetrics {
        let value = await backend.metrics()
        await gate.pause()
        return value
    }
}
