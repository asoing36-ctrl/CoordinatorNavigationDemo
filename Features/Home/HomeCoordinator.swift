import SwiftUI

@MainActor final class HomeCoordinator: Coordinator {
    private let router: any NavigationRouting
    private let session: SessionStore
    private let demo: DemoModel
    init(router: any NavigationRouting, session: SessionStore, demo: DemoModel) {
        self.router = router; self.session = session; self.demo = demo
    }
    func start() {
        router.setRoot(UIHostingController(rootView: HomeView(session: session, demo: demo,
            secondary: { [weak self] in self?.showSecondary() },
            details: { [weak self] in self?.showDetails() },
            lab: { [weak self] in self?.showLab() },
            presentSwiftUI: { [weak self] in self?.presentSwiftUI() },
            presentUIKit: { [weak self] in self?.presentUIKit() })), route: .home)
    }
    func showSecondary() {
        router.push(UIHostingController(rootView: SecondaryView(session: session, demo: demo,
            lab: { [weak self] in self?.showLab() },
            presentSwiftUI: { [weak self] in self?.presentSwiftUI() },
            presentUIKit: { [weak self] in self?.presentUIKit() })), route: .secondary, policy: .allowed)
    }
    func showDetails() {
        router.push(UIHostingController(rootView: CredentialDetailsView(session: session,
            lab: { [weak self] in self?.showLabDetail() }, showAlert: { [weak self] in self?.showAlert($0) },
            showNotice: { [weak self] in self?.showNotice($0) })), route: .details, policy: .allowed)
    }
    func showLab() { showUIKit(route: .lab) }
    func showLabDetail() { showUIKit(route: .labDetail) }
    private func showUIKit(route: Route) {
        let controller = NavigationLabViewController(openSwiftUI: { [weak self] in self?.showDetails() },
            openUIKit: { [weak self] in self?.showLabDetail() },
            presentSwiftUI: { [weak self] in self?.presentSwiftUI() },
            showAlert: { [weak self] style in self?.showAlert(style) },
            showNotice: { [weak self] in self?.showNotice($0) })
        controller.title = route == .lab ? "UIKit Lab" : "UIKit Detail"
        router.push(controller, route: route, policy: .allowed)
    }
    func presentSwiftUI() {
        let controller = UIHostingController(rootView: PresentedCredentialView(session: session, demo: demo,
            dismiss: { [weak self] in self?.dismissPresentedScreen() },
            showAlert: { [weak self] style in self?.showAlert(style) }))
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        router.present(controller, route: .credentialSheet)
    }
    func presentUIKit() {
        let controller = NavigationLabViewController(openSwiftUI: { [weak self] in
            self?.dismissPresentedScreen()
            self?.showDetails()
        }, openUIKit: { [weak self] in
            self?.dismissPresentedScreen()
            self?.showLabDetail()
        }, presentSwiftUI: { [weak self] in
            self?.dismissPresentedScreen()
            self?.presentSwiftUI()
        }, dismiss: { [weak self] in self?.dismissPresentedScreen() },
           showAlert: { [weak self] style in self?.showAlert(style) },
           showNotice: { [weak self] in self?.showNotice($0) })
        controller.modalPresentationStyle = .fullScreen
        router.present(controller, route: .uikitFullScreen)
    }
    func showAlert(_ style: AppAlertStyle) { router.showAlert(.demo(style: style), completion: { _ in }) }
    func showNotice(_ request: AppAlertRequest) { router.showAlert(request, completion: { _ in }) }
    func dismissPresentedScreen() { router.dismiss() }
    func stop() {}
}

struct HomeView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var demo: DemoModel
    let secondary: () -> Void
    let details: () -> Void
    let lab: () -> Void
    let presentSwiftUI: () -> Void
    let presentUIKit: () -> Void
    var body: some View {
        List {
            Section {
                Label("Your access, in one place", systemImage: "key.fill").font(.headline)
                CredentialSummary(session: session)
            } header: { Text("Authenticated") }
            Section("Explore navigation") {
                Button("Secondary SwiftUI screen", action: secondary).accessibilityIdentifier("openSecondary")
                Button("Credential details", action: details).accessibilityIdentifier("openDetails")
                Button("UIKit / XIB lab", action: lab).accessibilityIdentifier("openUIKit")
            }
            PresentationControls(presentSwiftUI: presentSwiftUI, presentUIKit: presentUIKit)
            DemoControls(model: demo)
        }.navigationTitle("Home").accessibilityIdentifier("homeScreen")
    }
}
struct SecondaryView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var demo: DemoModel
    let lab: () -> Void
    let presentSwiftUI: () -> Void
    let presentUIKit: () -> Void
    var body: some View {
        List {
            Section {
                Text("This screen stays on the stack when a credential is added.")
                CredentialSummary(session: session)
                Button("Open UIKit lab", action: lab).accessibilityIdentifier("openUIKit")
            }
            PresentationControls(presentSwiftUI: presentSwiftUI, presentUIKit: presentUIKit)
            DemoControls(model: demo)
        }.navigationTitle("Secondary").accessibilityIdentifier("secondaryScreen")
    }
}
struct PresentationControls: View {
    let presentSwiftUI: () -> Void
    let presentUIKit: () -> Void
    var body: some View {
        Section("Present screens") {
            Button("Present SwiftUI sheet", action: presentSwiftUI).accessibilityIdentifier("presentSwiftUI")
            Button("Present UIKit full screen", action: presentUIKit).accessibilityIdentifier("presentUIKit")
        }
    }
}
struct PresentedCredentialView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var demo: DemoModel
    let dismiss: () -> Void
    let showAlert: (AppAlertStyle) -> Void
    var body: some View {
        // A container identifier overrides the direct descendants in the UI hierarchy.
        // Keep the title, Done button and stack label independently identifiable.
        VStack(spacing: 0) {
            HStack {
                Text("Credential sheet").font(.title2.bold()).accessibilityIdentifier("presentedSwiftUITitle")
                Spacer()
                Button("Done", action: dismiss).accessibilityIdentifier("dismissSwiftUIModal")
            }.padding()
            Text("Underlying stack: " + demo.diagnostics.stackDescription)
                .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 8).accessibilityIdentifier("modalStack")
            List {
                Section {
                    Text("Presented with UIKit, rendered with SwiftUI. Drag down or tap Done to return.")
                    CredentialSummary(session: session)
                }
                Section("Alerts over this sheet") { AlertDemoButtons(show: showAlert, showNotice: { demo.showNotice?($0) }) }
                Section("Navigation underneath") {
                    Text("Presented: " + (demo.diagnostics.presentedRoute?.rawValue ?? "none")).accessibilityIdentifier("modalDiagnostics")
                }
            }
        }.background(Color(uiColor: .systemGroupedBackground))
    }
}
struct CredentialSummary: View {
    @ObservedObject var session: SessionStore
    var body: some View {
        Text("Credentials: \(session.credentials.count)").accessibilityIdentifier("credentialCount")
        Text("Permissions: \(session.permissions.sorted().joined(separator: ", "))").accessibilityIdentifier("permissions")
        ForEach(session.credentials) { credential in
            Label(credential.name, systemImage: "checkmark.seal")
        }
    }
}
struct CredentialDetailsView: View {
    @ObservedObject var session: SessionStore
    let lab: () -> Void
    let showAlert: (AppAlertStyle) -> Void
    let showNotice: (AppAlertRequest) -> Void
    var body: some View {
        List {
            CredentialSummary(session: session)
            Button("Open UIKit detail", action: lab).accessibilityIdentifier("openUIKitDetail")
            Section("Alerts") { AlertDemoButtons(show: showAlert, showNotice: showNotice) }
        }.navigationTitle("Credential Details").accessibilityIdentifier("detailsScreen")
    }
}
