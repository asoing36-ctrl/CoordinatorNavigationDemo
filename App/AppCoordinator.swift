import SwiftUI

@MainActor final class AppCoordinator: Coordinator {
    let id = UUID()
    let session = SessionStore()
    let processor: DeepLinkProcessor
    let demo = DemoModel()
    private(set) var children: [UUID: any Coordinator] = [:]
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
    private var originalSession: UserSession?
    private var activeCode: String?
    private var started = false
    private var stopped = false

    init(router: any NavigationRouting, backend: MockBackend, maximumPendingIntents: Int = 8,
         repository: (any CredentialRepository)? = nil, environment: (any MockEnvironmentManaging)? = nil) {
        self.router = router
        let businessRepository = repository ?? backend
        self.repository = businessRepository
        self.environment = environment ?? backend
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
    private func retain(_ coordinator: any Coordinator) { children[coordinator.id] = coordinator }
    private func release(_ coordinator: (any Coordinator)?) {
        guard let coordinator else { return }
        coordinator.stop(); children.removeValue(forKey: coordinator.id)
    }
    private func handle(_ intent: AppIntent) {
        guard case .redeemCredential(let code) = intent else { return }
        originalSession = session.session // Preserve the original transaction context across retries.
        activeCode = code
        flow = .redeeming
        demo.status = "Redeeming credential…"
        let coordinator = RedeemCoordinator(router: router, showScreen: originalSession == nil)
        redeem = coordinator; retain(coordinator)
        coordinator.onRetry = { [weak self] in self?.performRedeem() }
        coordinator.onClose = { [weak self] in self?.closeFailedRedeem() }
        coordinator.start()
        performRedeem()
    }
    private func performRedeem() {
        guard let code = activeCode, let redeem else { return }
        operation?.cancel()
        redeem.model.loading = true; redeem.model.error = nil
        let token = generation
        let useCase = useCase
        let original = originalSession
        operation = Task { [weak self] in
            do {
                let result = try await useCase.execute(code: code, session: original)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.session.apply(result)
                self.demo.loginCount = await self.environment.metrics().loginCount
                guard self.generation == token, !Task.isCancelled else { return }
                self.demo.status = result.authentication == .createdAccount ? "Account created" : (result.authentication == .loggedIn ? "Logged in" : "Credential added; session preserved")
                if result.needsPhoneAssociation { self.beginOnboarding(result) }
                else { self.finishAuthenticatedRedeem() }
            } catch is CancellationError { } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.redeem?.fail(error)
                self.demo.status = error.localizedDescription
                if original != nil {
                    // Keep the intent and its original session until an explicit alert action.
                    // The router defers display while inactive and presents over the visible modal/content.
                    let admission = self.router.showAlert(.redeemFailure(message: error.localizedDescription, style: self.demo.alertStyle)) { [weak self] action in
                        guard let self, self.generation == token, !self.stopped else { return }
                        if action == .retry { self.performRedeem() }
                        else { self.finishAuthenticatedRedeem() }
                    }
                    if admission == .capacityExceeded || admission == .invalidActions {
                        // Rejected requests own no callback. Preserve session/stack
                        // and release this intent rather than strand the pipeline.
                        self.reportCapacityExceeded()
                        self.finishAuthenticatedRedeem()
                    }
                }
                self.refreshDiagnostics()
            }
        }
    }
    private func beginOnboarding(_ result: RedeemResult) {
        // Keep Redeem's hosting controller underneath the genuinely pushed XIB screen.
        release(redeem); redeem = nil
        let coordinator = OnboardingCoordinator(router: router, repository: repository, session: result.session, authentication: result.authentication)
        onboarding = coordinator; retain(coordinator)
        let token = generation
        coordinator.onFinish = { [weak self] in
            guard let self, self.generation == token else { return }
            self.release(self.onboarding); self.onboarding = nil
            self.installHome()
            self.clearTransaction()
            self.processor.finish()
        }
        flow = .phoneAssociation
        coordinator.start()
        refreshDiagnostics()
    }
    private func installHome() {
        release(home)
        let coordinator = HomeCoordinator(router: router, session: session, demo: demo)
        home = coordinator; retain(coordinator)
        flow = .authenticated
        coordinator.start()
        refreshDiagnostics()
    }
    private func finishAuthenticatedRedeem() {
        release(redeem); redeem = nil
        flow = .authenticated
        // Existing Home/secondary/detail controller identities are deliberately preserved.
        clearTransaction()
        refreshDiagnostics()
        processor.finish()
    }
    private func closeFailedRedeem() {
        release(redeem); redeem = nil
        clearTransaction()
        showWelcome()
        processor.finish()
    }
    private func clearTransaction() { activeCode = nil; originalSession = nil }
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
        demo.busy = true
        let oldOperation = operation
        let oldOnboarding = onboarding
        operation?.cancel(); operation = nil
        for coordinator in children.values { coordinator.stop() }
        children.removeAll(); redeem = nil; onboarding = nil; home = nil
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
        demo.loginCount = 0; demo.status = "Mock environment reset"
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
            if processor.active == nil || flow == .phoneAssociation || redeem?.model.error != nil { break }
            await Task.yield()
        }
    }
    private func refreshDiagnostics() {
        demo.flow = flow.rawValue
        demo.authentication = session.isAuthenticated ? "Authenticated" : "Unauthenticated"
        demo.routes = router.routes.map(\.rawValue)
        demo.presentedScreen = router.presentedRoute?.rawValue
        demo.credentialCount = session.credentials.count
        demo.permissions = session.permissions.sorted()
        demo.activeCoordinator = onboarding != nil ? "OnboardingCoordinator" : (redeem != nil ? "RedeemCoordinator" : (home != nil ? "HomeCoordinator" : "AppCoordinator"))
        demo.pendingCount = processor.pendingCount
        demo.backBlocked = router.backBlocked
    }
    func stop() {
        stopped = true
        router.cancelPendingNavigation()
        router.cancelAlerts()
        resetting = false; deferredIntents.removeAll(); deferredInvalidNotice = false; deferredCapacityNotice = false
        generation = UUID(); operation?.cancel(); resetTask?.cancel()
        for coordinator in children.values { coordinator.stop() }
        children.removeAll(); redeem = nil; onboarding = nil; home = nil
        processor.reset()
    }
    deinit { operation?.cancel(); resetTask?.cancel() }
}
