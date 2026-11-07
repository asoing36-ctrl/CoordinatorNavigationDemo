import Combine

@MainActor final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published private(set) var credentials: [Credential] = []
    var isAuthenticated: Bool { session != nil }
    var permissions: Set<String> { credentials.reduce(into: []) { $0.formUnion($1.grantedPermissions) } }
    func apply(_ result: RedeemResult) {
        session = result.session
        credentials = result.credentials
    }
    func restore(session: UserSession?, credentials: [Credential] = []) {
        self.session = session
        self.credentials = credentials
    }
}
