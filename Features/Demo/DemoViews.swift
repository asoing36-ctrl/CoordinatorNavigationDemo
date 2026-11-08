import SwiftUI

/// A read-only projection; UIKit, the session and the intent processor remain owners.
struct NavigationDiagnostics: Equatable {
    let flow: AppFlow
    let isAuthenticated: Bool
    let routes: [Route]
    let presentedRoute: PresentationRoute?
    let credentialCount: Int
    let permissions: [String]
    let activeCoordinator: String
    let pendingCount: Int
    let backBlocked: Bool

    var authentication: String { isAuthenticated ? "Authenticated" : "Unauthenticated" }
    var currentFeature: String { presentedRoute?.rawValue ?? routes.last?.rawValue ?? "none" }
    var stackDescription: String { routes.map(\.rawValue).joined(separator: " → ") }
    static var empty: NavigationDiagnostics {
        NavigationDiagnostics(flow: .launching, isAuthenticated: false, routes: [], presentedRoute: nil,
            credentialCount: 0, permissions: [], activeCoordinator: "AppCoordinator", pendingCount: 0, backBlocked: false)
    }
}

@MainActor final class DemoModel: ObservableObject {
    #if DEBUG
    let instanceID = UUID().uuidString
    #endif
    @Published var code = "NEW-USER"
    @Published var status = "Ready"
    @Published var alertStyle: AppAlertStyle = .uikit
    var showAlert: ((AppAlertStyle) -> Void)?
    @Published var busy = false
    @Published private(set) var diagnostics = NavigationDiagnostics.empty
    @Published private(set) var loginCount = 0
    private let readLoginCount: @Sendable () async -> Int
    private var metricsTask: Task<Void, Never>?
    private var metricsRequested = false
    private var metricsGeneration = UUID()
    var inject: ((String) -> Void)?
    var reset: ((Bool) -> Void)?

    init(readLoginCount: @escaping @Sendable () async -> Int = { 0 }) { self.readLoginCount = readLoginCount }
    func updateDiagnostics(_ snapshot: NavigationDiagnostics) {
        if diagnostics != snapshot { diagnostics = snapshot }
    }
    /// One read can run; further requests coalesce into one follow-up read.
    @discardableResult func refreshMetrics() -> Task<Void, Never>? {
        metricsRequested = true
        startMetricsIfNeeded()
        return metricsTask
    }
    /// Keeps a cancelled read joinable without making flow completion await it.
    @discardableResult func cancelMetrics(resetCount: Bool = false) -> Task<Void, Never>? {
        metricsGeneration = UUID()
        metricsRequested = false
        metricsTask?.cancel()
        if resetCount, loginCount != 0 { loginCount = 0 }
        return metricsTask
    }
    private func startMetricsIfNeeded() {
        guard metricsRequested, metricsTask == nil else { return }
        metricsRequested = false
        let read = readLoginCount
        let generation = metricsGeneration
        metricsTask = Task { [weak self] in
            let count = await read()
            guard let self else { return }
            self.metricsTask = nil
            if !Task.isCancelled, self.metricsGeneration == generation, self.loginCount != count {
                self.loginCount = count
            }
            self.startMetricsIfNeeded()
        }
    }
    deinit { metricsTask?.cancel() }
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
        Section("Alerts") {
            Picker("Error alert style", selection: $model.alertStyle) {
                Text("UIKit").tag(AppAlertStyle.uikit)
                Text("SwiftUI").tag(AppAlertStyle.swiftUI)
            }.pickerStyle(.segmented).accessibilityIdentifier("errorAlertStyle")
            AlertDemoButtons(show: { model.showAlert?($0) })
        }
        #if DEBUG
        Section("Diagnostics • observed state") {
            LabeledContent("Flow", value: model.diagnostics.flow.rawValue)
            LabeledContent("Session", value: model.diagnostics.authentication)
            LabeledContent("Current feature", value: model.diagnostics.currentFeature)
            LabeledContent("Presented screen", value: model.diagnostics.presentedRoute?.rawValue ?? "none")
            Text("Stack: " + model.diagnostics.stackDescription).accessibilityIdentifier("stackDiagnostics")
            LabeledContent("Credentials", value: "\(model.diagnostics.credentialCount)")
            LabeledContent("Permissions", value: model.diagnostics.permissions.joined(separator: ", "))
            LabeledContent("Coordinator", value: model.diagnostics.activeCoordinator)
            LabeledContent("Pending links", value: "\(model.diagnostics.pendingCount)")
            LabeledContent("Back blocked", value: model.diagnostics.backBlocked ? "Yes" : "No")
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
                #if DEBUG
                Text("Instance: \(model.instanceID)").accessibilityIdentifier("instanceIdentity")
                #endif
                Text("Flow: \(model.diagnostics.flow.rawValue) • \(model.diagnostics.authentication)")
                Text("Current feature: \(model.diagnostics.currentFeature)")
                Text("Stack: " + model.diagnostics.stackDescription).accessibilityIdentifier("overlayStack")
                Text("Credentials: \(model.diagnostics.credentialCount) • Permissions: \(model.diagnostics.permissions.joined(separator: ", "))")
                Text("Coordinator: \(model.diagnostics.activeCoordinator)")
                Text("Queued: \(model.diagnostics.pendingCount) • Back blocked: \(model.diagnostics.backBlocked ? "Yes" : "No")")
            }
        }.font(.caption2).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AlertDemoButtons: View {
    let show: (AppAlertStyle) -> Void
    var body: some View {
        Button("Show UIKit alert") { show(.uikit) }.accessibilityIdentifier("showUIKitAlert")
        Button("Show SwiftUI alert") { show(.swiftUI) }.accessibilityIdentifier("showSwiftUIAlert")
    }
}
