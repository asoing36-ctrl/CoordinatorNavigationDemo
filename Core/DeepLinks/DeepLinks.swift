import Foundation

enum AppIntent: Equatable, Sendable { case redeemCredential(accessCode: String) }
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
    var pendingCount: Int { pending.count }
    var onIntent: ((AppIntent) -> Void)?
    var onChange: (() -> Void)?
    func submit(_ intent: AppIntent) {
        guard active != intent, !pending.contains(intent) else { return }
        pending.append(intent)
        advance()
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
