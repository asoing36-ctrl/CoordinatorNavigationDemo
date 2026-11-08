import Foundation

/// Mock administration is separate from credential business operations.
protocol MockEnvironmentManaging: Sendable {
    func reset() async
    func seedAuthenticatedSession() async -> UserSession
    func ownedCredentials(accountID: String) async -> [Credential]
    func metrics() async -> BackendMetrics
}

/// Actor state is changed only after cancellation-aware delay. No awaits inside commits.
actor MockBackend: CredentialRepository, MockEnvironmentManaging {
    private let delay: Duration
    private var accounts: [String: Account] = [:]
    private var credentials: [String: [Credential]] = [:]
    private var networkFailureDelivered = false
    private var counters = BackendMetrics()

    init(delay: Duration = .milliseconds(250)) {
        self.delay = delay
        accounts["existing"] = Account(id: "existing")
        accounts["demo"] = Account(id: "demo")
    }
    private func pause() async throws {
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
    }
    private func validate(_ code: String, authenticated: Bool) throws {
        switch code {
        case "INVALID": throw DemoError.invalidCode
        case "EXPIRED": throw DemoError.expiredCode
        case "ADD-CRED" where !authenticated: throw DemoError.requiresAuthentication
        case "NETWORK-FAIL" where !networkFailureDelivered:
            networkFailureDelivered = true
            throw DemoError.network
        case "NEW-USER", "EXISTING-USER", "ADD-CRED", "NETWORK-FAIL": break
        default: throw DemoError.invalidCode
        }
    }
    func resolveAccount(code: String) async throws -> Account? {
        try await pause()
        try validate(code, authenticated: false)
        return accounts[code == "EXISTING-USER" ? "existing" : "new"]
    }
    func createAccount(code: String) async throws -> Account {
        try await pause()
        try validate(code, authenticated: false)
        if let existing = accounts["new"] { return existing }
        let account = Account(id: "new")
        accounts[account.id] = account
        counters.createdCount += 1
        return account
    }
    func login(account: Account) async throws -> UserSession {
        try await pause()
        guard accounts[account.id] != nil else { throw DemoError.missingAccount }
        counters.loginCount += 1
        return UserSession(accountID: account.id)
    }
    func redeem(code: String, session: UserSession) async throws -> [Credential] {
        try await pause()
        try validate(code, authenticated: true)
        guard accounts[session.accountID] != nil else { throw DemoError.missingAccount }
        let suffix: String
        let name: String
        let permissions: Set<String>
        switch code {
        case "ADD-CRED": suffix = "additional"; name = "Premium Library"; permissions = ["library", "premium"]
        case "EXISTING-USER": suffix = "existing"; name = "Member Library"; permissions = ["library", "members"]
        case "NETWORK-FAIL": suffix = "retry"; name = "Recovered Library"; permissions = ["library", "recovered"]
        default: suffix = "welcome"; name = "Welcome Library"; permissions = ["library"]
        }
        let credential = Credential(id: session.accountID + "." + suffix, name: name, grantedPermissions: permissions)
        var owned = credentials[session.accountID, default: []]
        if !owned.contains(where: { $0.id == credential.id }) { owned.append(credential) }
        credentials[session.accountID] = owned
        return owned
    }
    func associatePhone(accountID: String, simulateFailure: Bool) async throws {
        try await pause()
        guard accounts[accountID] != nil else { throw DemoError.missingAccount }
        if simulateFailure { throw DemoError.network }
        counters.phoneAssociationCount += 1
    }
    func seedAuthenticatedSession() -> UserSession {
        let account = Account(id: "demo")
        accounts[account.id] = account
        credentials[account.id] = [Credential(id: "demo.base", name: "Starter Library", grantedPermissions: ["library"])]
        return UserSession(accountID: account.id)
    }
    func ownedCredentials(accountID: String) -> [Credential] { credentials[accountID, default: []] }
    func metrics() -> BackendMetrics { counters }
    func reset() {
        accounts = ["existing": Account(id: "existing"), "demo": Account(id: "demo")]
        credentials = [:]
        networkFailureDelivered = false
        counters = BackendMetrics()
    }
}
