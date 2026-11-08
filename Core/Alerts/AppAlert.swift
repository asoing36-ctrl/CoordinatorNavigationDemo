import Foundation

enum AppAlertStyle: String, CaseIterable, Sendable {
    case uikit
    case swiftUI
}
enum AppAlertScope: Equatable, Sendable { case flow, global }
enum NoticePresentation: Equatable, Sendable { case alert, snackbar }
enum AlertAdmission: Equatable, Sendable { case accepted, duplicate, invalidActions, invalidConfiguration, capacityExceeded }

enum AppAlertAction: String, Hashable, Sendable {
    case ok
    case retry
    case cancel

    var title: String {
        switch self {
        case .ok: return "OK"
        case .retry: return "Retry"
        case .cancel: return "Cancel"
        }
    }
}

struct AppAlertRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    /// A semantic deduplication key that must never contain access codes or URLs.
    let key: String
    let style: AppAlertStyle
    let title: String
    let message: String
    let actions: [AppAlertAction]
    let scope: AppAlertScope
    let presentation: NoticePresentation
    /// Foreground visible time. nil requires explicit user dismissal.
    let dismissAfter: Duration?

    init(
        id: UUID = UUID(),
        key: String,
        style: AppAlertStyle,
        title: String,
        message: String,
        actions: [AppAlertAction] = [.ok],
        scope: AppAlertScope = .flow,
        presentation: NoticePresentation = .alert,
        dismissAfter: Duration? = nil
    ) {
        self.id = id
        self.key = key
        self.style = style
        self.title = title
        self.message = message
        self.actions = actions
        self.scope = scope
        self.presentation = presentation
        self.dismissAfter = dismissAfter
    }

    var hasValidConfiguration: Bool {
        let informational = scope == .global && actions == [.ok]
        if let dismissAfter {
            guard informational, dismissAfter > .zero, dismissAfter <= .seconds(86_400) else { return false }
        }
        return presentation != .snackbar || informational
    }

    static func timedDemo(style: AppAlertStyle) -> AppAlertRequest {
        AppAlertRequest(key: "timed-demo-\(style.rawValue)", style: style,
            title: style == .uikit ? "Timed UIKit Alert" : "Timed SwiftUI Alert",
            message: "This informational alert closes after four foreground seconds.",
            scope: .global, dismissAfter: .seconds(4))
    }

    static func snackbarDemo(timed: Bool) -> AppAlertRequest {
        AppAlertRequest(key: timed ? "timed-snackbar" : "manual-snackbar", style: .uikit,
            title: timed ? "Timed snackbar" : "Persistent snackbar",
            message: timed ? "Navigation stays available. This message closes automatically." : "Navigate normally, then tap Dismiss when finished.",
            scope: .global, presentation: .snackbar, dismissAfter: timed ? .seconds(4) : nil)
    }

    static func demo(style: AppAlertStyle) -> AppAlertRequest {
        AppAlertRequest(
            key: "demo-alert-\(style.rawValue)",
            style: style,
            title: style == .uikit ? "UIKit Alert" : "SwiftUI Alert",
            message: "This alert was requested through the shared alert queue.",
            scope: .global
        )
    }

    static func redeemFailure(message: String, style: AppAlertStyle) -> AppAlertRequest {
        AppAlertRequest(
            key: "redeem-failure",
            style: style,
            title: "Unable to Redeem",
            message: message,
            actions: [.retry, .cancel]
        )
    }
    static func capacityExceeded(style: AppAlertStyle) -> AppAlertRequest {
        AppAlertRequest(key: "pending-work-limit", style: style, title: "Please Try Again",
            message: "The app is finishing queued work. Please try again shortly.", scope: .global)
    }
}

/// Owns request state while the router owns presentation and dismissal.
@MainActor
final class AppAlertQueue {
    private struct Entry {
        let request: AppAlertRequest
        let completion: @MainActor (AppAlertAction) -> Void
    }

    var sceneIsActive = false
    var current: AppAlertRequest? { active?.request }
    var pendingCount: Int { pending.count }

    private var active: Entry?
    private var pending: [Entry] = []
    private let maximumPendingRequests: Int

    /// Reserve the final pending slot for flow recovery; active ownership is separate.
    init(maximumPendingRequests: Int = 9) { self.maximumPendingRequests = max(2, maximumPendingRequests) }

    @discardableResult func enqueue(
        _ request: AppAlertRequest,
        completion: @escaping @MainActor (AppAlertAction) -> Void = { _ in }
    ) -> AlertAdmission {
        guard !request.actions.isEmpty,
              Set(request.actions).count == request.actions.count,
              request.scope != .global || request.actions == [.ok] else { return .invalidActions }
        guard request.hasValidConfiguration else { return .invalidConfiguration }
        let duplicate: (Entry) -> Bool = { $0.request.key == request.key && $0.request.scope == request.scope }
        guard active.map(duplicate) != true, !pending.contains(where: duplicate) else { return .duplicate }
        let limit = maximumPendingRequests - (request.scope == .global ? 1 : 0)
        guard pending.count < limit else { return .capacityExceeded }
        pending.append(Entry(request: request, completion: completion))
        return .accepted
    }

    func beginNext() -> AppAlertRequest? {
        guard sceneIsActive, active == nil, !pending.isEmpty else { return nil }
        let entry = pending.removeFirst()
        active = entry
        return entry.request
    }

    func complete(id: UUID, action: AppAlertAction) {
        guard let entry = active,
              entry.request.id == id,
              entry.request.actions.contains(action) else { return }
        active = nil
        entry.completion(action)
    }

    /// Presentation cancellation/rejection is not a user action. Preserve the next request.
    func cancel(id: UUID) {
        guard active?.request.id == id else { return }
        active = nil
    }

    func cancelAll() {
        active = nil
        pending.removeAll()
    }
    func cancel(scope: AppAlertScope) {
        if active?.request.scope == scope { active = nil }
        pending.removeAll { $0.request.scope == scope }
    }
}
