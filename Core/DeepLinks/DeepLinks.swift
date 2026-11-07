import Foundation

enum AppIntent: Equatable, Sendable { case redeemCredential(accessCode: String) }
enum IntentAdmission: Equatable, Sendable { case accepted, duplicate, capacityExceeded }
/// Validated intent staging only; business ownership begins at DeepLinkProcessor.
struct PendingIntentBuffer {
    private let maximumCount: Int
    private var values: [AppIntent] = []
    init(maximumCount: Int = 8) { self.maximumCount = max(1, maximumCount) }
    @discardableResult mutating func append(_ intent: AppIntent) -> IntentAdmission {
        guard !values.contains(intent) else { return .duplicate }
        guard values.count < maximumCount else { return .capacityExceeded }
        values.append(intent)
        return .accepted
    }
    mutating func takeAll() -> [AppIntent] { let result = values; values.removeAll(); return result }
    mutating func removeAll() { values.removeAll() }
}
enum DeepLinkError: Error, Equatable { case unsupported, missingCode, malformedCode }
struct DeepLinkParser {
    func parse(_ url: URL) throws -> AppIntent {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil else { throw DeepLinkError.unsupported }
        let custom = parts.scheme?.lowercased() == "credentialdemo" && parts.host?.lowercased() == "redeem" && (parts.path.isEmpty || parts.path == "/")
        let universal = parts.scheme?.lowercased() == "https" && parts.host?.lowercased() == "demo.example.com" && parts.path == "/redeem"
        guard custom || universal else { throw DeepLinkError.unsupported }
        let codes = (parts.queryItems ?? []).filter { $0.name == "code" }
        guard !codes.isEmpty else { throw DeepLinkError.missingCode }
        guard codes.count == 1, let code = codes.first?.value, !code.isEmpty, code.count <= 64,
              code.range(of: "^[A-Z0-9]+(?:-[A-Z0-9]+)*$", options: .regularExpression) != nil else { throw DeepLinkError.malformedCode }
        return .redeemCredential(accessCode: code)
    }
}

/// FIFO of distinct intents. Active ownership extends through optional phone onboarding.
@MainActor final class DeepLinkProcessor {
    private(set) var active: AppIntent?
    private var pending: [AppIntent] = []
    private let maximumPendingIntents: Int
    var pendingCount: Int { pending.count }
    var onIntent: ((AppIntent) -> Void)?
    var onChange: (() -> Void)?
    init(maximumPendingIntents: Int = 8) { self.maximumPendingIntents = max(1, maximumPendingIntents) }
    @discardableResult func submit(_ intent: AppIntent) -> IntentAdmission {
        submit(contentsOf: [intent])[0]
    }
    /// Admit the whole reset buffer before callbacks can submit newer work.
    @discardableResult func submit(contentsOf intents: [AppIntent]) -> [IntentAdmission] {
        var results: [IntentAdmission] = []
        for intent in intents {
            let full = active == nil ? pending.count > maximumPendingIntents : pending.count >= maximumPendingIntents
            if active == intent || pending.contains(intent) { results.append(.duplicate) }
            else if full { results.append(.capacityExceeded) }
            else { pending.append(intent); results.append(.accepted) }
        }
        advance()
        return results
    }
    func finish() { active = nil; advance() }
    func reset() { active = nil; pending = []; onChange?() }
    private func advance() {
        if active == nil, !pending.isEmpty {
            let next = pending.removeFirst()
            active = next
            onChange?()
            onIntent?(next)
        } else { onChange?() }
    }
}
