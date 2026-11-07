import Foundation

enum AppAlertStyle: String, CaseIterable, Sendable {
    case uikit
    case swiftUI
}

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

    init(
        id: UUID = UUID(),
        key: String,
        style: AppAlertStyle,
        title: String,
        message: String,
        actions: [AppAlertAction] = [.ok]
    ) {
        self.id = id
        self.key = key
        self.style = style
        self.title = title
        self.message = message
        self.actions = actions
    }

    static func demo(style: AppAlertStyle) -> AppAlertRequest {
        AppAlertRequest(
            key: "demo-alert-\(style.rawValue)",
            style: style,
            title: style == .uikit ? "UIKit Alert" : "SwiftUI Alert",
            message: "This alert was requested through the shared alert queue."
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

    func enqueue(
        _ request: AppAlertRequest,
        completion: @escaping @MainActor (AppAlertAction) -> Void = { _ in }
    ) {
        guard !request.actions.isEmpty,
              Set(request.actions).count == request.actions.count else { return }
        guard active?.request.key != request.key,
              !pending.contains(where: { $0.request.key == request.key }) else { return }
        pending.append(Entry(request: request, completion: completion))
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
}
