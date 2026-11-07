import Foundation

struct Credential: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let grantedPermissions: Set<String>
}
struct Account: Equatable, Sendable { let id: String }
struct UserSession: Equatable, Sendable { let accountID: String }
enum AuthenticationOutcome: String, Sendable { case unchanged, createdAccount, loggedIn }
struct RedeemResult: Sendable {
    let session: UserSession
    let credentials: [Credential]
    let authentication: AuthenticationOutcome
    // Derived from the transaction's ORIGINAL session, never from the updated store.
    let needsPhoneAssociation: Bool
}
enum AppFlow: String { case launching, unauthenticated, redeeming, phoneAssociation, authenticated }
enum DemoError: Error, Equatable, LocalizedError {
    case invalidCode, expiredCode, network, requiresAuthentication, missingAccount
    var errorDescription: String? {
        switch self {
        case .invalidCode: return "This access code is invalid. Try another code."
        case .expiredCode: return "This access code has expired. Request a new code."
        case .network: return "The simulated request failed. Please retry."
        case .requiresAuthentication: return "Start authenticated before using this demo code."
        case .missingAccount: return "The account is unavailable. Reset the demo."
        }
    }
}
struct BackendMetrics: Sendable {
    var loginCount = 0
    var createdCount = 0
    var phoneAssociationCount = 0
}
