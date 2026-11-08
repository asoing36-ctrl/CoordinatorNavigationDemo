import Testing
import Combine
import UIKit
@testable import CoordinatorNavigationDemo

@Suite(.serialized) @MainActor struct SimplificationTests {
    enum RedeemExit: Equatable, Sendable { case close, reset, stop }
    enum PhoneExit: Equatable, Sendable { case skip, associate, reset, stop }

    @Test(arguments: [RedeemExit.close, .reset, .stop])
    func redeemOwnerIsReleasedOnEveryExit(exit: RedeemExit) async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        app.start(); app.submit(code: "INVALID"); await app.waitForOperation()
        weak var owner = app.redeem
        #expect(owner != nil)
        switch exit {
        case .close: app.redeem?.close()
        case .reset: await app.reset(authenticated: false)
        case .stop: app.stop()
        }
        try await waitForNavigationCondition { owner == nil }
        #expect(app.redeem == nil)
        #expect(app.onboarding == nil)
        #expect(app.home == nil)
        #expect(app.processor.active == nil)
        #expect(router.routes == (exit == .stop ? [.welcome, .redeem] : [.welcome]))
    }

    @Test(arguments: [PhoneExit.skip, .associate, .reset, .stop])
    func phoneOwnerIsReleasedAndOnlyCompletionInstallsHome(exit: PhoneExit) async throws {
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: MockBackend(delay: .zero))
        defer { app.stop() }
        app.start(); app.submit(code: "NEW-USER"); await app.waitForOperation()
        weak var owner = app.onboarding
        #expect(owner != nil)
        #expect(app.redeem == nil)
        switch exit {
        case .skip: app.onboarding?.skip()
        case .associate:
            var child = app.onboarding
            child?.associate(simulateFailure: false)
            await child?.waitForOperation()
            child = nil
        case .reset: await app.reset(authenticated: false)
        case .stop: app.stop()
        }
        try await waitForNavigationCondition { owner == nil }
        #expect(app.onboarding == nil)
        #expect(app.processor.active == nil)
        if exit == .skip || exit == .associate {
            #expect(router.routes == [.home])
            #expect(app.home != nil)
            weak var home = app.home
            app.stop()
            try await waitForNavigationCondition { home == nil }
        } else {
            #expect(app.home == nil)
            #expect(!router.routes.contains(.home))
        }
    }

    @Test(arguments: ["ADD-CRED", "INVALID", "EXPIRED", "NETWORK-FAIL"])
    func authenticatedTransactionNeedsNoPresentationOwnerAndPreservesHomeAndModal(code: String) async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .redeem, position: .before, gate: gate)
        let cleanup = LifecycleCleanup(gates: [gate])
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend, repository: repository)
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); await app.reset(authenticated: true)
            app.home?.showSecondary(); app.home?.presentSwiftUI()
            await nextLifecycleMainQueueTurn() // Settle seed observation before testing admission.
            weak var home = app.home
            weak var modal = router.presentedController
            let stack = router.screens.map { ObjectIdentifier($0.controller) }
            let session = app.session.session
            app.submit(code: code)
            try await waitForNavigationCondition { gate.arrivals == 1 }
            #expect(app.redeem == nil)
            #expect(app.demo.diagnostics.flow == .redeeming)
            #expect(app.demo.diagnostics.activeCoordinator == "HomeCoordinator")
            #expect(home != nil && app.home === home)
            #expect(app.onboarding == nil)
            #expect(router.screens.map { ObjectIdentifier($0.controller) } == stack)
            #expect(router.presentedController === modal)
            gate.release(); await app.waitForOperation()
            if code != "ADD-CRED" {
                router.setSceneActive(true)
                let recovery = try #require(router.alerts.beginNext())
                router.alerts.complete(id: recovery.id, action: .cancel)
            }
            #expect(app.processor.active == nil)
            #expect(app.session.session == session)
            #expect(app.session.credentials.count == (code == "ADD-CRED" ? 2 : 1))
            #expect(app.home === home && home != nil)
            #expect(app.redeem == nil && app.onboarding == nil)
            #expect(router.screens.map { ObjectIdentifier($0.controller) } == stack)
            #expect(router.presentedController === modal && modal != nil)
            #expect(await backend.metrics().loginCount == 0)
        }
    }

    @Test func obsoleteRecoveryActionsCannotAffectTheNextTransactionWithoutReset() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let repository = GatedCredentialRepository(backend: backend, stage: .redeem, position: .before,
            gate: gate, codeFilter: "ADD-CRED")
        let cleanup = LifecycleCleanup(gates: [gate])
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend, repository: repository)
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); await app.reset(authenticated: true)
            app.submit(code: "INVALID"); await app.waitForOperation()
            let obsolete = try #require(router.lastAlertAction)
            app.submit(code: "ADD-CRED")
            router.setSceneActive(true)
            let error = try #require(router.alerts.beginNext())
            router.alerts.complete(id: error.id, action: .cancel)
            try await waitForNavigationCondition { gate.arrivals == 1 }
            obsolete(.retry); obsolete(.cancel)
            #expect(app.processor.active == .redeemCredential(accessCode: "ADD-CRED"))
            #expect(app.flow == .redeeming)
            gate.release(); await app.waitForOperation()
            #expect(app.processor.active == nil)
            #expect(app.session.credentials.count == 2)
            #expect(router.routes == [.home])
        }
    }

    @Test func retryAfterLoginAndGrantFailurePreservesUnauthenticatedTransactionContext() async throws {
        let backend = MockBackend(delay: .zero)
        let gate = LifecycleGate()
        let router = RouterSpy()
        let app = AppCoordinator(router: router, backend: backend,
            repository: FailFirstGrantRepository(backend: backend, retryGate: gate))
        let cleanup = LifecycleCleanup(gates: [gate])
        cleanup.track(app)
        try await withLifecycleCleanup(cleanup) {
            app.start(); app.submit(code: "NEW-USER"); await app.waitForOperation()
            #expect(!app.session.isAuthenticated)
            #expect(app.redeem?.model.error != nil)
            #expect(await backend.metrics().loginCount == 1)
            let retry = try #require(app.redeem?.onRetry)
            retry()
            try await waitForNavigationCondition { gate.arrivals == 1 }
            // The first retry has already logged in. Replaying its action must
            // not cancel it and start another login, even if an API ignores cancellation.
            retry()
            gate.release(); await app.waitForOperation()
            #expect(app.session.isAuthenticated)
            #expect(app.onboarding != nil && app.redeem == nil)
            #expect(router.routes == [.welcome, .redeem, .phone])
            #expect(await backend.metrics().createdCount == 1)
            #expect(await backend.metrics().loginCount == 2)
            app.onboarding?.skip()
            #expect(router.routes == [.home])
            #expect(app.session.credentials.count == 1)
        }
    }
}

private actor FailFirstGrantRepository: CredentialRepository {
    let backend: MockBackend
    let retryGate: LifecycleGate
    private var grants = 0
    init(backend: MockBackend, retryGate: LifecycleGate) { self.backend = backend; self.retryGate = retryGate }
    func resolveAccount(code: String) async throws -> Account? { try await backend.resolveAccount(code: code) }
    func createAccount(code: String) async throws -> Account { try await backend.createAccount(code: code) }
    func login(account: Account) async throws -> UserSession { try await backend.login(account: account) }
    func redeem(code: String, session: UserSession) async throws -> [Credential] {
        grants += 1
        if grants == 1 { throw DemoError.network }
        if grants == 2 { await retryGate.pause() }
        let backend = backend
        return try await Task.detached { try await backend.redeem(code: code, session: session) }.value
    }
    func associatePhone(accountID: String, simulateFailure: Bool) async throws {
        try await backend.associatePhone(accountID: accountID, simulateFailure: simulateFailure)
    }
}
