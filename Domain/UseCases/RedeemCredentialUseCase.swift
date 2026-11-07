import Foundation

struct RedeemCredentialUseCase: Sendable {
    let repository: any CredentialRepository

    func execute(code: String, session originalSession: UserSession?) async throws -> RedeemResult {
        let session: UserSession
        let authentication: AuthenticationOutcome
        if let originalSession {
            session = originalSession
            authentication = .unchanged
        } else {
            let account: Account
            if let existing = try await repository.resolveAccount(code: code) {
                account = existing
                authentication = .loggedIn
            } else {
                account = try await repository.createAccount(code: code)
                authentication = .createdAccount
            }
            try Task.checkCancellation()
            session = try await repository.login(account: account)
        }
        try Task.checkCancellation()
        let credentials = try await repository.redeem(code: code, session: session)
        try Task.checkCancellation()
        return RedeemResult(session: session, credentials: credentials, authentication: authentication,
                            needsPhoneAssociation: originalSession == nil)
    }
}
