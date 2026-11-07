import SwiftUI

@MainActor final class RedeemViewModel: ObservableObject {
    @Published var loading = true
    @Published var message = "Redeeming credential…"
    @Published var error: String?
}
@MainActor final class RedeemCoordinator: Coordinator {
    let id = UUID()
    let model = RedeemViewModel()
    private let router: any NavigationRouting
    private let showScreen: Bool
    var onRetry: (() -> Void)?
    var onClose: (() -> Void)?
    init(router: any NavigationRouting, showScreen: Bool) { self.router = router; self.showScreen = showScreen }
    func start() {
        guard showScreen else { return }
        let view = RedeemView(model: model, retry: { [weak self] in self?.onRetry?() }, close: { [weak self] in self?.close() })
        router.push(UIHostingController(rootView: view), route: .redeem, policy: .blocked)
    }
    func fail(_ error: Error) { model.loading = false; model.error = error.localizedDescription }
    func close() { onClose?() }
    func stop() { onRetry = nil; onClose = nil }
}
struct RedeemView: View {
    @ObservedObject var model: RedeemViewModel
    let retry: () -> Void
    let close: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.horizontal").font(.system(size: 56)).foregroundStyle(.blue)
            Text("Redeem Credential").font(.largeTitle.bold())
            if model.loading { ProgressView(model.message) }
            if let error = model.error {
                Text(error).foregroundStyle(.red).accessibilityIdentifier("redeemError")
                Button("Retry", action: retry).buttonStyle(.borderedProminent)
                Button("Return", action: close)
            }
        }.padding().navigationTitle("Redeem")
    }
}
