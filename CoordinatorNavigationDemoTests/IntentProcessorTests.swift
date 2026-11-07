import Testing
import Foundation
@testable import CoordinatorNavigationDemo

@MainActor struct IntentProcessorTests {
    @Test func duplicateSuppressionAndFIFO() {
        let processor = DeepLinkProcessor()
        var received: [AppIntent] = []
        processor.onIntent = { received.append($0) }
        let first = AppIntent.redeemCredential(accessCode: "NEW-USER")
        let second = AppIntent.redeemCredential(accessCode: "ADD-CRED")
        processor.submit(first); processor.submit(first)
        processor.submit(second); processor.submit(second)
        #expect(received == [first])
        #expect(processor.pendingCount == 1)
        processor.finish()
        #expect(received == [first, second])
        #expect(processor.active == second)
        processor.finish()
        #expect(processor.active == nil)
    }
    @Test func resetDropsPendingAndActive() {
        let processor = DeepLinkProcessor()
        processor.submit(.redeemCredential(accessCode: "NEW-USER"))
        processor.submit(.redeemCredential(accessCode: "ADD-CRED"))
        processor.reset()
        #expect(processor.active == nil)
        #expect(processor.pendingCount == 0)
    }
    @Test func finishedIntentMayBeSubmittedAgainForIdempotentRefresh() {
        let processor = DeepLinkProcessor()
        let intent = AppIntent.redeemCredential(accessCode: "ADD-CRED")
        processor.submit(intent); processor.finish(); processor.submit(intent)
        #expect(processor.active == intent)
    }
}
