import Testing
import Foundation
@testable import CoordinatorNavigationDemo

struct ParserTests {
    @Test func validCustomAndUniversalLinks() throws {
        let parser = DeepLinkParser()
        #expect(try parser.parse(URL(string: "credentialdemo://redeem?code=NEW-USER")!) == .redeemCredential(accessCode: "NEW-USER"))
        #expect(try parser.parse(URL(string: "https://demo.example.com/redeem?code=ADD-CRED")!) == .redeemCredential(accessCode: "ADD-CRED"))
    }
    @Test(arguments: ["other://redeem?code=NEW-USER", "credentialdemo://other?code=NEW-USER", "credentialdemo://redeem/extra?code=NEW-USER", "credentialdemo://redeem?code=", "credentialdemo://redeem?code=a%20b", "credentialdemo://redeem?code=A&code=B", "https://evil.example/redeem?code=A"])
    func rejectsMalformedLinks(_ value: String) {
        #expect(throws: DeepLinkError.self) { try DeepLinkParser().parse(URL(string: value)!) }
    }
    @Test func missingCode() { #expect(throws: DeepLinkError.missingCode) { try DeepLinkParser().parse(URL(string: "credentialdemo://redeem")!) } }
}

struct BusinessTests {
    @Test func newAccountAndIdempotency() async throws {
        let backend = MockBackend(delay: .zero)
        let useCase = RedeemCredentialUseCase(repository: backend)
        let first = try await useCase.execute(code: "NEW-USER", session: nil)
        #expect(first.authentication == .createdAccount)
        #expect(first.needsPhoneAssociation)
        let second = try await useCase.execute(code: "NEW-USER", session: first.session)
        #expect(second.authentication == .unchanged)
        #expect(!second.needsPhoneAssociation)
        #expect(second.credentials == first.credentials)
        #expect(await backend.metrics().loginCount == 1)
    }
    @Test func existingAccountLogin() async throws {
        let backend = MockBackend(delay: .zero)
        let result = try await RedeemCredentialUseCase(repository: backend).execute(code: "EXISTING-USER", session: nil)
        #expect(result.authentication == .loggedIn)
        #expect(result.needsPhoneAssociation)
        #expect(await backend.metrics().createdCount == 0)
    }
    @Test func authenticatedRedeemNeverLogsIn() async throws {
        let backend = MockBackend(delay: .zero)
        let session = await backend.seedAuthenticatedSession()
        let result = try await RedeemCredentialUseCase(repository: backend).execute(code: "ADD-CRED", session: session)
        #expect(result.session == session)
        #expect(!result.needsPhoneAssociation)
        #expect(result.credentials.contains { $0.grantedPermissions.contains("premium") })
        #expect(await backend.metrics().loginCount == 0)
    }
    @Test(arguments: ["INVALID", "EXPIRED", "ADD-CRED"])
    func errorsDoNotAuthenticate(_ code: String) async {
        let backend = MockBackend(delay: .zero)
        await #expect(throws: DemoError.self) { try await RedeemCredentialUseCase(repository: backend).execute(code: code, session: nil) }
        #expect(await backend.metrics().loginCount == 0)
    }
    @Test func networkRetry() async throws {
        let backend = MockBackend(delay: .zero)
        let useCase = RedeemCredentialUseCase(repository: backend)
        await #expect(throws: DemoError.network) { try await useCase.execute(code: "NETWORK-FAIL", session: nil) }
        #expect(try await useCase.execute(code: "NETWORK-FAIL", session: nil).credentials.count == 1)
    }
    @Test func concurrentRedemptionEffectsAreIdempotent() async throws {
        let backend = MockBackend(delay: .zero)
        let session = await backend.seedAuthenticatedSession()
        try await withThrowingTaskGroup(of: [Credential].self) { group in
            for _ in 0..<10 { group.addTask { try await backend.redeem(code: "ADD-CRED", session: session) } }
            for try await result in group { #expect(result.count == 2) }
        }
        #expect(await backend.ownedCredentials(accountID: session.accountID).count == 2)
    }
    @Test func cancelledRedeemDoesNotAuthenticate() async {
        let backend = MockBackend(delay: .milliseconds(100))
        let task = Task {
            try Task.checkCancellation()
            return try await RedeemCredentialUseCase(repository: backend).execute(code: "NEW-USER", session: nil)
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled transaction returned a result") }
        catch { #expect(error is CancellationError) }
        #expect(await backend.metrics().loginCount == 0)
        #expect(await backend.metrics().createdCount == 0)
    }
    @Test func phoneFailureRetryAndSuccess() async throws {
        let backend = MockBackend(delay: .zero)
        let session = await backend.seedAuthenticatedSession()
        await #expect(throws: DemoError.network) { try await backend.associatePhone(accountID: session.accountID, simulateFailure: true) }
        try await backend.associatePhone(accountID: session.accountID, simulateFailure: false)
        #expect(await backend.metrics().phoneAssociationCount == 1)
    }
}
