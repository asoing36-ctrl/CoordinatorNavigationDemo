import Testing
import Foundation
@testable import CoordinatorNavigationDemo

@MainActor struct IntentProcessorTests {
    @Test func startupAndResetStagingDeduplicateBeforeCapacityAndDrainFIFO() {
        var buffer = PendingIntentBuffer(maximumCount: 2)
        let a = AppIntent.redeemCredential(accessCode: "FIRST")
        let b = AppIntent.redeemCredential(accessCode: "SECOND")
        let c = AppIntent.redeemCredential(accessCode: "THIRD")
        #expect(buffer.append(a) == .accepted)
        #expect(buffer.append(a) == .duplicate)
        #expect(buffer.append(b) == .accepted)
        #expect(buffer.append(c) == .capacityExceeded)
        #expect(buffer.takeAll() == [a, b])
        #expect(buffer.append(c) == .accepted)
        #expect(buffer.takeAll() == [c])
    }

    @Test func capacityPreservesActiveAndAcceptedFIFOAndChecksDuplicatesFirst() {
        let processor = DeepLinkProcessor(maximumPendingIntents: 2)
        let a = AppIntent.redeemCredential(accessCode: "FIRST")
        let b = AppIntent.redeemCredential(accessCode: "SECOND")
        let c = AppIntent.redeemCredential(accessCode: "THIRD")
        let d = AppIntent.redeemCredential(accessCode: "FOURTH")
        var received: [AppIntent] = []
        processor.onIntent = { received.append($0) }
        #expect(processor.submit(a) == .accepted)
        #expect(processor.submit(b) == .accepted)
        #expect(processor.submit(c) == .accepted)
        #expect(processor.submit(b) == .duplicate)
        #expect(processor.submit(d) == .capacityExceeded)
        #expect(processor.active == a)
        #expect(processor.pendingCount == 2)
        processor.finish(); processor.finish(); processor.finish()
        #expect(received == [a, b, c])
        #expect(processor.active == nil)
        #expect(processor.submit(d) == .accepted)
    }

    @Test func bufferedBatchIsAdmittedBeforeReentrantNewArrivals() {
        let processor = DeepLinkProcessor(maximumPendingIntents: 3)
        let a = AppIntent.redeemCredential(accessCode: "FIRST")
        let b = AppIntent.redeemCredential(accessCode: "SECOND")
        let c = AppIntent.redeemCredential(accessCode: "THIRD")
        let d = AppIntent.redeemCredential(accessCode: "FOURTH")
        var received: [AppIntent] = []
        var reentrant: IntentAdmission?
        processor.onIntent = { [weak processor] intent in
            received.append(intent)
            if intent == a { reentrant = processor?.submit(d) }
        }
        #expect(processor.submit(contentsOf: [a, b, c]) == [.accepted, .accepted, .accepted])
        #expect(reentrant == .accepted)
        #expect(processor.pendingCount == 3)
        processor.finish(); processor.finish(); processor.finish(); processor.finish()
        #expect(received == [a, b, c, d])
    }

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
