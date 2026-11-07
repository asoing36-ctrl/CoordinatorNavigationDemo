import Foundation
import Testing
@testable import CoordinatorNavigationDemo

@MainActor
struct AppAlertQueueTests {
    @Test func inactiveSceneBuffersRequestsUntilActivated() {
        let queue = AppAlertQueue()
        let request = AppAlertRequest.demo(style: .uikit)

        queue.enqueue(request)

        #expect(queue.current == nil)
        #expect(queue.pendingCount == 1)
        #expect(queue.beginNext() == nil)

        queue.sceneIsActive = true

        #expect(queue.current == nil)
        #expect(queue.beginNext() == request)
        #expect(queue.current == request)
        #expect(queue.pendingCount == 0)
        #expect(queue.beginNext() == nil)
    }

    @Test func requestsRemainFIFOAcrossRendererStyles() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let first = AppAlertRequest.demo(style: .swiftUI)
        let second = AppAlertRequest.demo(style: .uikit)
        let third = AppAlertRequest.redeemFailure(message: "Please try again.", style: .swiftUI)
        queue.enqueue(first)
        queue.enqueue(second)
        queue.enqueue(third)

        #expect(queue.beginNext() == first)
        #expect(queue.pendingCount == 2)
        queue.complete(id: first.id, action: .ok)
        #expect(queue.current == nil)
        #expect(queue.pendingCount == 2)
        #expect(queue.beginNext() == second)
        queue.complete(id: second.id, action: .ok)
        #expect(queue.beginNext() == third)
        queue.complete(id: third.id, action: .cancel)
        #expect(queue.beginNext() == nil)
    }

    @Test func duplicateKeysAreSuppressedWhilePendingAndActive() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let original = AppAlertRequest.redeemFailure(message: "Try again.", style: .uikit)
        let duplicate = AppAlertRequest.redeemFailure(message: "A different message.", style: .swiftUI)
        var duplicateCompletions = 0
        queue.enqueue(original)
        queue.enqueue(duplicate) { _ in duplicateCompletions += 1 }
        #expect(queue.pendingCount == 1)
        #expect(queue.beginNext() == original)

        queue.enqueue(duplicate) { _ in duplicateCompletions += 1 }
        #expect(queue.pendingCount == 0)
        queue.complete(id: original.id, action: .cancel)
        #expect(duplicateCompletions == 0)
        #expect(queue.beginNext() == nil)

        queue.enqueue(duplicate)
        #expect(queue.beginNext() == duplicate)
    }

    @Test func completionRunsOnceForTheMatchingRequestAndAllowedAction() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let request = AppAlertRequest.redeemFailure(message: "Please retry.", style: .uikit)
        var receivedActions: [AppAlertAction] = []
        queue.enqueue(request) { receivedActions.append($0) }
        #expect(queue.beginNext() == request)

        queue.complete(id: UUID(), action: .retry)
        queue.complete(id: request.id, action: .ok)
        #expect(queue.current == request)
        #expect(receivedActions.isEmpty)

        queue.complete(id: request.id, action: .retry)
        queue.complete(id: request.id, action: .cancel)
        #expect(queue.current == nil)
        #expect(receivedActions == [.retry])
    }

    @Test func sceneDeactivationPausesOnlyTheNextPresentation() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let first = AppAlertRequest.demo(style: .uikit)
        let second = AppAlertRequest.demo(style: .swiftUI)
        queue.enqueue(first)
        queue.enqueue(second)
        #expect(queue.beginNext() == first)

        queue.sceneIsActive = false
        queue.complete(id: first.id, action: .ok)
        #expect(queue.current == nil)
        #expect(queue.beginNext() == nil)
        #expect(queue.pendingCount == 1)

        queue.sceneIsActive = true
        #expect(queue.beginNext() == second)
    }

    @Test func resetDropsRequestsAndIgnoresStaleCallbacks() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let active = AppAlertRequest.demo(style: .uikit)
        let pending = AppAlertRequest.demo(style: .swiftUI)
        var cancelledCompletions = 0
        queue.enqueue(active) { _ in cancelledCompletions += 1 }
        queue.enqueue(pending) { _ in cancelledCompletions += 1 }
        #expect(queue.beginNext() == active)

        queue.cancelAll()
        #expect(queue.current == nil)
        #expect(queue.pendingCount == 0)
        queue.complete(id: active.id, action: .ok)
        queue.complete(id: pending.id, action: .ok)
        #expect(cancelledCompletions == 0)

        let replacement = AppAlertRequest.demo(style: .uikit)
        var replacementCompletions = 0
        queue.enqueue(replacement) { _ in replacementCompletions += 1 }
        #expect(queue.beginNext() == replacement)
        queue.complete(id: active.id, action: .ok)
        #expect(queue.current == replacement)
        #expect(replacementCompletions == 0)
        queue.complete(id: replacement.id, action: .ok)
        #expect(replacementCompletions == 1)
        #expect(cancelledCompletions == 0)
    }

    @Test func completionCanReentrantlyEnqueueAndBeginTheSameSemanticKey() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let first = AppAlertRequest.demo(style: .uikit)
        let replacement = AppAlertRequest.demo(style: .uikit)
        var currentDuringCompletion: AppAlertRequest?
        var startedDuringCompletion: AppAlertRequest?
        queue.enqueue(first) { _ in
            currentDuringCompletion = queue.current
            queue.enqueue(replacement)
            startedDuringCompletion = queue.beginNext()
        }
        #expect(queue.beginNext() == first)

        queue.complete(id: first.id, action: .ok)

        #expect(currentDuringCompletion == nil)
        #expect(startedDuringCompletion == replacement)
        #expect(queue.current == replacement)
        #expect(queue.pendingCount == 0)
    }
}
