import Foundation
import Testing
@testable import CoordinatorNavigationDemo

@MainActor
struct AppAlertQueueTests {
    @Test func capacityReservesFlowRecoveryAndDoesNotEvictAcceptedNotices() {
        let queue = AppAlertQueue(maximumPendingRequests: 3)
        let a = AppAlertRequest(key: "a", style: .uikit, title: "A", message: "", scope: .global)
        let b = AppAlertRequest(key: "b", style: .swiftUI, title: "B", message: "", scope: .global)
        let overflow = AppAlertRequest(key: "overflow", style: .uikit, title: "Overflow", message: "", scope: .global)
        let recovery = AppAlertRequest.redeemFailure(message: "Recover", style: .uikit)
        var completed: [String] = []
        #expect(queue.enqueue(a, completion: { _ in completed.append("a") }) == .accepted)
        #expect(queue.enqueue(b, completion: { _ in completed.append("b") }) == .accepted)
        #expect(queue.enqueue(b, completion: { _ in completed.append("duplicate") }) == .duplicate)
        #expect(queue.enqueue(overflow, completion: { _ in completed.append("overflow") }) == .capacityExceeded)
        #expect(queue.enqueue(recovery, completion: { _ in completed.append("recovery") }) == .accepted)
        #expect(queue.pendingCount == 3)
        queue.sceneIsActive = true
        #expect(queue.beginNext() == a); queue.complete(id: a.id, action: .ok)
        #expect(queue.beginNext() == b); queue.complete(id: b.id, action: .ok)
        #expect(queue.beginNext() == recovery); queue.complete(id: recovery.id, action: .cancel)
        #expect(completed == ["a", "b", "recovery"])
    }

    @Test func flowCancellationPreservesActiveGlobalAndScopeSeparatesDeduplication() {
        let queue = AppAlertQueue()
        let global = AppAlertRequest(key: "same", style: .uikit, title: "Global", message: "", scope: .global)
        let flow = AppAlertRequest(key: "same", style: .uikit, title: "Flow", message: "")
        var actions: [String] = []
        #expect(queue.enqueue(global, completion: { _ in actions.append("global") }) == .accepted)
        #expect(queue.enqueue(flow, completion: { _ in actions.append("flow") }) == .accepted)
        queue.sceneIsActive = true
        #expect(queue.beginNext() == global)
        queue.cancel(scope: .flow)
        #expect(queue.current == global)
        #expect(queue.pendingCount == 0)
        queue.complete(id: global.id, action: .ok)
        #expect(actions == ["global"])
    }

    @Test func cancellingActiveFlowLeavesGlobalNoticesInFIFOOrder() {
        let queue = AppAlertQueue()
        let flow = AppAlertRequest.redeemFailure(message: "Recover", style: .uikit)
        let a = AppAlertRequest.demo(style: .uikit)
        let b = AppAlertRequest.demo(style: .swiftUI)
        var cancelledAction = false
        queue.enqueue(flow) { _ in cancelledAction = true }
        queue.sceneIsActive = true
        #expect(queue.beginNext() == flow)
        queue.enqueue(a); queue.enqueue(b)
        queue.cancel(scope: .flow)
        #expect(queue.current == nil)
        #expect(queue.beginNext() == a)
        queue.complete(id: a.id, action: .ok)
        #expect(queue.beginNext() == b)
        #expect(!cancelledAction)
    }

    @Test func durableGlobalNoticesCannotCarryFlowRecoveryActions() {
        let queue = AppAlertQueue()
        let invalid = AppAlertRequest(key: "bad", style: .uikit, title: "Bad", message: "", actions: [.retry, .cancel], scope: .global)
        #expect(queue.enqueue(invalid) == .invalidActions)
        #expect(queue.pendingCount == 0)
        #expect(queue.enqueue(.demo(style: .uikit)) == .accepted)
    }

    @Test func invalidActionsCannotOwnOrBlockTheQueue() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let invalidActions: [[AppAlertAction]] = [[], [.ok, .ok], [.retry, .retry], [.cancel, .cancel]]
        for actions in invalidActions {
            queue.enqueue(AppAlertRequest(key: "invalid", style: .swiftUI,
                title: "Invalid", message: "Invalid configuration", actions: actions))
        }
        #expect(queue.pendingCount == 0)
        #expect(queue.beginNext() == nil)
        let valid = AppAlertRequest.demo(style: .uikit)
        queue.enqueue(valid)
        #expect(queue.beginNext() == valid)
    }

    @Test func cancelledPresentationReleasesOnlyItsOwnRequestWithoutAnAction() {
        let queue = AppAlertQueue()
        queue.sceneIsActive = true
        let first = AppAlertRequest.demo(style: .swiftUI)
        let next = AppAlertRequest.demo(style: .uikit)
        var actions: [AppAlertAction] = []
        queue.enqueue(first) { actions.append($0) }
        queue.enqueue(next) { actions.append($0) }
        #expect(queue.beginNext() == first)
        queue.cancel(id: UUID())
        #expect(queue.current == first)
        queue.cancel(id: first.id)
        #expect(actions.isEmpty)
        #expect(queue.beginNext() == next)
        queue.cancel(id: first.id)
        queue.complete(id: first.id, action: .ok)
        #expect(queue.current == next)
        queue.complete(id: next.id, action: .ok)
        #expect(actions == [.ok])
    }

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
