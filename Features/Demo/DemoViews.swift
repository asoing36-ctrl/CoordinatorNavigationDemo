import SwiftUI

@MainActor final class DemoModel: ObservableObject {
    @Published var code = "NEW-USER"
    @Published var status = "Ready"
    @Published var busy = false
    @Published var flow = "launching"
    @Published var authentication = "Unauthenticated"
    @Published var routes: [String] = []
    @Published var presentedScreen: String?
    @Published var credentialCount = 0
    @Published var permissions: [String] = []
    @Published var activeCoordinator = "AppCoordinator"
    @Published var pendingCount = 0
    @Published var backBlocked = false
    @Published var loginCount = 0
    var inject: ((String) -> Void)?
    var reset: ((Bool) -> Void)?
}
struct WelcomeView: View {
    @ObservedObject var demo: DemoModel
    var body: some View {
        List {
            Section {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 46)).foregroundStyle(.blue).padding(.vertical)
                Text("One stack. Clear ownership.").font(.title2.bold())
                Text("Redeem a credential to create an account or log in. Explore SwiftUI and real UIKit XIB screens on a single navigation stack.")
            }
            DemoControls(model: demo)
        }.navigationTitle("Navigation Demo").accessibilityIdentifier("welcomeScreen")
    }
}
struct DemoControls: View {
    @ObservedObject var model: DemoModel
    var body: some View {
        Section("Demo controls") {
            TextField("Access code", text: $model.code).textInputAutocapitalization(.characters)
                .autocorrectionDisabled().accessibilityIdentifier("accessCode")
            Button("Inject deep link") { model.inject?(model.code) }
                .disabled(model.busy).accessibilityIdentifier("injectLink")
            // Shortcuts use exactly the same parser and intent processor as OS URL delivery.
            HStack {
                Button("Create account") { model.inject?("NEW-USER") }.accessibilityIdentifier("createAccount")
                Spacer()
                Button("Login") { model.inject?("EXISTING-USER") }.accessibilityIdentifier("loginAccount")
            }.buttonStyle(.borderless).disabled(model.busy)
            Button("Add credential") { model.inject?("ADD-CRED") }.disabled(model.busy).accessibilityIdentifier("addCredential")
            Button("Start authenticated") { model.reset?(true) }.disabled(model.busy).accessibilityIdentifier("startAuthenticated")
            Button("Reset / Start unauthenticated") { model.reset?(false) }.disabled(model.busy).accessibilityIdentifier("resetDemo")
            Text(model.status).font(.footnote).accessibilityIdentifier("demoStatus")
        }
        #if DEBUG
        Section("Diagnostics • observed state") {
            LabeledContent("Flow", value: model.flow)
            LabeledContent("Session", value: model.authentication)
            LabeledContent("Current screen", value: model.presentedScreen ?? model.routes.last ?? "none")
            LabeledContent("Presented screen", value: model.presentedScreen ?? "none")
            Text("Stack: " + model.routes.joined(separator: " → ")).accessibilityIdentifier("stackDiagnostics")
            LabeledContent("Credentials", value: "\(model.credentialCount)")
            LabeledContent("Permissions", value: model.permissions.joined(separator: ", "))
            LabeledContent("Coordinator", value: model.activeCoordinator)
            LabeledContent("Pending links", value: "\(model.pendingCount)")
            LabeledContent("Back blocked", value: model.backBlocked ? "Yes" : "No")
            Text("Login requests: \(model.loginCount)").accessibilityIdentifier("loginCount")
        }
        #endif
    }
}

/// Debug-only overlay exposes actual state even while the phone screen protects the stack.
struct DiagnosticsView: View {
    @ObservedObject var model: DemoModel
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(expanded ? "Hide diagnostics" : "Diagnostics") { expanded.toggle() }
                .font(.caption.bold()).accessibilityIdentifier("toggleDiagnostics")
            if expanded {
                Text("Flow: \(model.flow) • \(model.authentication)")
                Text("Current: \(model.presentedScreen ?? model.routes.last ?? "none")")
                Text("Stack: " + model.routes.joined(separator: " → ")).accessibilityIdentifier("overlayStack")
                Text("Credentials: \(model.credentialCount) • Permissions: \(model.permissions.joined(separator: ", "))")
                Text("Coordinator: \(model.activeCoordinator)")
                Text("Queued: \(model.pendingCount) • Back blocked: \(model.backBlocked ? "Yes" : "No")")
            }
        }.font(.caption2).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
