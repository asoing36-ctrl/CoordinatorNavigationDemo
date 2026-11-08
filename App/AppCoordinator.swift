import SwiftUI
import Combine

@MainActor final class AppCoordinator: Coordinator {
    let session = SessionStore()
    let processor: DeepLinkProcessor
    let demo: DemoModel
    private var sessionObservation: AnyCancellable?
    private var diagnosticsUpdateScheduled = false
    private(set) var flow: AppFlow = .launching
    private(set) var redeem: RedeemCoordinator?
    private(set) var onboarding: OnboardingCoordinator?
    private(set) var home: HomeCoordinator?
    private let router: any NavigationRouting
    private let repository: any CredentialRepository
    private let environment: any MockEnvironmentManaging
    private let useCase: RedeemCredentialUseCase
    private var operation: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var generation = UUID()
    private var resetting = false
    private var deferredIntents: PendingIntentBuffer
    private var deferredInvalidNotice = false
    private var deferredCapacityNotice = false
    private struct RedeemTransaction {
        enum Phase { case running, awaitingRecovery }
        let id = UUID()
        let code: String
        let originalSession: UserSession?
        var phase: Phase = .running
    }
    private var transaction: RedeemTransaction?
    private var started = false
    private var stopped = false

    init(router: any NavigationRouting, backend: MockBackend, maximumPendingIntents: Int = 8,
         repository: (any CredentialRepository)? = nil, environment: (any MockEnvironmentManaging)? = nil) {
        self.router = router
        let businessRepository = repository ?? backend
        self.repository = businessRepository
        let administration = environment ?? backend
        self.environment = administration
        demo = DemoModel(readLoginCount: { await administration.metrics().loginCount })
        deferredIntents = PendingIntentBuffer(maximumCount: maximumPendingIntents)
        processor = DeepLinkProcessor(maximumPendingIntents: maximumPendingIntents)
        useCase = RedeemCredentialUseCase(repository: businessRepository)
        router.onChange = { [weak self] in self?.refreshDiagnostics() }
        processor.onChange = { [weak self] in self?.refreshDiagnostics() }
        processor.onIntent = { [weak self] intent in self?.handle(intent) }
        demo.inject = { [weak self] code in self?.submit(code: code) }
        demo.showAlert = { [weak self] style in
            self?.router.showAlert(.demo(style: style), completion: { _ in })
        }
        demo.reset = { [weak self] authenticated in
            guard let self, !self.resetting else { return }
            self.resetTask = Task { [weak self] in await self?.reset(authenticated: authenticated) }
        }
        sessionObservation = session.objectWillChange.sink { [weak self] in self?.scheduleDiagnosticsRefresh() }
    }
    func start() {
        guard !started else { return }
        started = true
        stopped = false
        showWelcome()
    }
    private func showWelcome() {
        flow = .unauthenticated
        router.setRoot(UIHostingController(rootView: WelcomeView(demo: demo)), route: .welcome)
        refreshDiagnostics()
    }
    func receive(_ url: URL) {
        guard !stopped else { return }
        do { receive([try DeepLinkParser().parse(url)]) }
        catch { reportUnsupportedLink() }
    }
    /// Already-validated startup/reset intents join the same business admission boundary.
    func receive(_ intents: [AppIntent]) {
        guard !stopped else { return }
        if resetting {
            for intent in intents {
                if deferredIntents.append(intent) == .capacityExceeded { reportCapacityExceeded() }
            }
        } else if processor.submit(contentsOf: intents).contains(.capacityExceeded) {
            reportCapacityExceeded()
        }
    }
    func reportUnsupportedLink() {
        guard !stopped else { return }
        if resetting { deferredInvalidNotice = true; return }
        demo.status = "Unsupported or malformed deep link."
        router.showAlert(AppAlertRequest(key: "invalid-link", style: demo.alertStyle,
            title: "Unsupported Link", message: "This link is unsupported or malformed.", scope: .global), completion: { _ in })
    }
    func reportCapacityExceeded() {
        guard !stopped else { return }
        if resetting { deferredCapacityNotice = true; return }
        let request = AppAlertRequest.capacityExceeded(style: demo.alertStyle)
        demo.status = request.message
        router.showAlert(request, completion: { _ in })
    }
    func submit(code: String) {
        var components = URLComponents()
        components.scheme = "credentialdemo"; components.host = "redeem"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        if let url = components.url { receive(url) }
    }
    private func stopChildren() {
        redeem?.stop(); redeem = nil
        onboarding?.stop(); onboarding = nil
        home?.stop(); home = nil
    }
    private func handle(_ intent: AppIntent) {
        guard !stopped, case .redeemCredential(let code) = intent else { return }
        let context = RedeemTransaction(code: code, originalSession: session.session)
        transaction = context // Preserve pre-authentication context across retries.
        flow = .redeeming
        demo.status = "Redeeming credential…"
        guard !stopped, transaction?.id == context.id else { return }
        if context.originalSession == nil {
            let coordinator = RedeemCoordinator(router: router)
            let transactionID = context.id
            redeem = coordinator
            coordinator.onRetry = { [weak self] in self?.retry(transactionID: transactionID) }
            coordinator.onClose = { [weak self] in self?.closeFailedRedeem(transactionID: transactionID) }
            coordinator.start()
        }
        refreshDiagnostics()
        guard !stopped, transaction?.id == context.id else { return }
        performRedeem()
    }
    private func retry(transactionID: UUID) {
        guard !stopped, transaction?.id == transactionID, transaction?.phase == .awaitingRecovery else { return }
        performRedeem()
    }
    private func performRedeem() {
        guard !stopped, let context = transaction else { return }
        operation?.cancel()
        transaction?.phase = .running
        redeem?.model.loading = true; redeem?.model.error = nil
        guard !stopped, transaction?.id == context.id else { return }
        let token = context.id
        let useCase = useCase
        let original = context.originalSession
        operation = Task { [weak self] in
            do {
                let result = try await useCase.execute(code: context.code, session: original)
                try Task.checkCancellation()
                guard let self, !self.stopped, self.transaction?.id == token else { return }
                self.session.apply(result)
                guard !self.stopped, self.transaction?.id == token, !Task.isCancelled else { return }
                self.demo.status = result.authentication == .createdAccount ? "Account created" : (result.authentication == .loggedIn ? "Logged in" : "Credential added; session preserved")
                guard !self.stopped, self.transaction?.id == token else { return }
                if result.needsPhoneAssociation { self.beginOnboarding(result, transactionID: token) }
                else { self.finishAuthenticatedRedeem(transactionID: token) }
                if !self.stopped { self.demo.refreshMetrics() }
            } catch is CancellationError { } catch {
                guard let self, !self.stopped, self.transaction?.id == token, !Task.isCancelled else { return }
                self.transaction?.phase = .awaitingRecovery
                self.redeem?.fail(error)
                guard !self.stopped, self.transaction?.id == token else { return }
                self.demo.status = error.localizedDescription
                guard !self.stopped, self.transaction?.id == token else { return }
                if original != nil {
                    // Keep the intent and its original session until an explicit alert action.
                    // The router defers display while inactive and presents over the visible modal/content.
                    let admission = self.router.showAlert(.redeemFailure(message: error.localizedDescription, style: self.demo.alertStyle)) { [weak self] action in
                        guard let self, !self.stopped, self.transaction?.id == token,
                              self.transaction?.phase == .awaitingRecovery else { return }
                        if action == .retry { self.retry(transactionID: token) }
                        else { self.finishAuthenticatedRedeem(transactionID: token) }
                    }
                    if admission == .capacityExceeded || admission == .invalidActions {
                        // Rejected requests own no callback. Preserve session/stack
                        // and release this intent rather than strand the pipeline.
                        self.reportCapacityExceeded()
                        self.finishAuthenticatedRedeem(transactionID: token)
                    }
                }
                self.refreshDiagnostics()
            }
        }
    }
    private func beginOnboarding(_ result: RedeemResult, transactionID: UUID) {
        guard !stopped, transaction?.id == transactionID else { return }
        // Keep Redeem's hosting controller underneath the genuinely pushed XIB screen.
        redeem?.stop(); redeem = nil
        let coordinator = OnboardingCoordinator(router: router, repository: repository, session: result.session, authentication: result.authentication)
        onboarding = coordinator
        coordinator.onFinish = { [weak self] in
            guard let self, !self.stopped, self.transaction?.id == transactionID else { return }
            self.onboarding?.stop(); self.onboarding = nil
            self.installHome()
            guard !self.stopped, self.transaction?.id == transactionID else { return }
            self.clearTransaction()
            self.processor.finish()
        }
        flow = .phoneAssociation
        coordinator.start()
        refreshDiagnostics()
    }
    private func installHome() {
        guard !stopped else { return }
        home?.stop()
        let coordinator = HomeCoordinator(router: router, session: session, demo: demo)
        home = coordinator
        flow = .authenticated
        coordinator.start()
        refreshDiagnostics()
    }
    private func finishAuthenticatedRedeem(transactionID: UUID) {
        guard !stopped, transaction?.id == transactionID else { return }
        redeem?.stop(); redeem = nil
        flow = .authenticated
        // Existing Home/secondary/detail controller identities are deliberately preserved.
        clearTransaction()
        refreshDiagnostics()
        if !stopped { processor.finish() }
    }
    private func closeFailedRedeem(transactionID: UUID) {
        guard !stopped, transaction?.id == transactionID, transaction?.phase == .awaitingRecovery,
              transaction?.originalSession == nil else { return }
        redeem?.stop(); redeem = nil
        clearTransaction()
        showWelcome()
        if !stopped { processor.finish() }
    }
    private func clearTransaction() { transaction = nil }
    // Reset is an administrative transaction: caller cancellation does not leave
    // half-reset state. Lifecycle stop invalidates its generation at every await.
    func reset(authenticated: Bool) async {
        guard !resetting, !stopped else { return }
        deferredIntents.removeAll(); deferredInvalidNotice = false; deferredCapacityNotice = false
        resetting = true
        router.cancelPendingNavigation()
        router.cancelAlerts()
        generation = UUID()
        let resetGeneration = generation
        demo.cancelMetrics(resetCount: true)
        demo.busy = true
        let oldOperation = operation
        let oldOnboarding = onboarding
        operation?.cancel(); operation = nil
        stopChildren()
        processor.reset(); clearTransaction()
        // Cancellation is awaited before resetting the actor, preventing obsolete backend commits.
        await oldOperation?.value
        guard generation == resetGeneration, !stopped else { return }
        await oldOnboarding?.waitForOperation()
        guard generation == resetGeneration, !stopped else { return }
        await environment.reset()
        guard generation == resetGeneration, !stopped else { return }
        if authenticated {
            let restored = await environment.seedAuthenticatedSession()
            guard generation == resetGeneration, !stopped else { return }
            let credentials = await environment.ownedCredentials(accountID: restored.accountID)
            guard generation == resetGeneration, !stopped else { return }
            session.restore(session: restored, credentials: credentials)
            installHome()
        } else {
            session.restore(session: nil)
            showWelcome()
        }
        demo.status = "Mock environment reset"
        demo.busy = false
        let intents = deferredIntents.takeAll()
        let invalidNotice = deferredInvalidNotice
        let capacityNotice = deferredCapacityNotice
        deferredIntents.removeAll(); deferredInvalidNotice = false; deferredCapacityNotice = false
        resetting = false
        receive(intents) // Bulk admission occurs before new callbacks can overtake the buffer.
        if invalidNotice { reportUnsupportedLink() }
        if capacityNotice { reportCapacityExceeded() }
        refreshDiagnostics()
    }
    func waitForOperation() async {
        // A completion may synchronously begin the next queued transaction.
        while let current = operation {
            await current.value
            if processor.active == nil || flow == .phoneAssociation || transaction?.phase == .awaitingRecovery { break }
            await Task.yield()
        }
    }
    private func scheduleDiagnosticsRefresh() {
        guard !stopped, !diagnosticsUpdateScheduled else { return }
        diagnosticsUpdateScheduled = true
        // Combine publishes before assignment. Read after the whole session mutation.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.diagnosticsUpdateScheduled = false
            if !self.stopped { self.refreshDiagnostics() }
        }
    }
    private func refreshDiagnostics() {
        demo.updateDiagnostics(NavigationDiagnostics(flow: flow, isAuthenticated: session.isAuthenticated,
            routes: router.routes, presentedRoute: router.presentedRoute,
            credentialCount: session.credentials.count, permissions: session.permissions.sorted(),
            activeCoordinator: onboarding != nil ? "OnboardingCoordinator" :
                (redeem != nil ? "RedeemCoordinator" : (home != nil ? "HomeCoordinator" : "AppCoordinator")),
            pendingCount: processor.pendingCount, backBlocked: router.backBlocked))
    }
    func stop() {
        stopped = true
        demo.cancelMetrics()
        router.cancelPendingNavigation()
        router.cancelAlerts()
        resetting = false; deferredIntents.removeAll(); deferredInvalidNotice = false; deferredCapacityNotice = false
        generation = UUID(); operation?.cancel(); resetTask?.cancel()
        stopChildren()
        clearTransaction()
        processor.reset()
    }
    deinit { operation?.cancel(); resetTask?.cancel() }
}
