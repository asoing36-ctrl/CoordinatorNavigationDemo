import UIKit
import Combine

@MainActor final class PhoneViewModel: ObservableObject {
    @Published var loading = false
    @Published var error: String?
    @Published var status = "Phone association is optional. Associate or skip to continue."
}
@MainActor final class OnboardingCoordinator: Coordinator {
    let model = PhoneViewModel()
    private let router: any NavigationRouting
    private let repository: any CredentialRepository
    private let session: UserSession
    private var task: Task<Void, Never>?
    private var finished = false
    var onFinish: (() -> Void)?
    init(router: any NavigationRouting, repository: any CredentialRepository, session: UserSession, authentication: AuthenticationOutcome) {
        self.router = router; self.repository = repository; self.session = session
        model.status = authentication == .createdAccount ? "Account created. Phone association is optional." : "Logged in. Phone association is optional."
    }
    func start() {
        let controller = AssociatePhoneViewController(model: model, associate: { [weak self] failure in self?.associate(simulateFailure: failure) }, skip: { [weak self] in self?.skip() })
        router.push(controller, route: .phone, policy: .blocked)
    }
    func associate(simulateFailure: Bool) {
        guard !finished, !model.loading else { return }
        model.loading = true; model.error = nil
        let repository = repository
        let accountID = session.accountID
        task = Task { [weak self] in
            do {
                try await repository.associatePhone(accountID: accountID, simulateFailure: simulateFailure)
                try Task.checkCancellation()
                guard let self, !self.finished else { return }
                self.model.loading = false
                self.model.status = "Phone associated successfully."
                self.complete()
            } catch is CancellationError { } catch {
                guard let self, !self.finished, !Task.isCancelled else { return }
                self.model.loading = false; self.model.error = error.localizedDescription
            }
        }
    }
    func skip() { guard !finished, !model.loading else { return }; complete() }
    private func complete() { guard !finished else { return }; finished = true; let callback = onFinish; onFinish = nil; callback?() }
    // Retain the cancelled operation so administrative reset can join it before
    // clearing the mock environment. The task captures this coordinator weakly.
    func stop() { finished = true; task?.cancel(); onFinish = nil }
    func waitForOperation() async { await task?.value }
    deinit { task?.cancel() }
}
