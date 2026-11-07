import Foundation

protocol CredentialRepository: Sendable {
    func resolveAccount(code: String) async throws -> Account?
    func createAccount(code: String) async throws -> Account
    func login(account: Account) async throws -> UserSession
    func redeem(code: String, session: UserSession) async throws -> [Credential]
    func associatePhone(accountID: String, simulateFailure: Bool) async throws
}
