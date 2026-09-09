import Foundation

public enum ToastKind: String, CaseIterable, Sendable {
    case success, error, warning, info
}

/// A display-only URL contract. No URL field is interpreted as an action.
public struct ToastRequest: Equatable, Sendable {
    public let message: String
    public let duration: Double
    public let type: ToastKind?

    /// Typed entry point for trusted in-app feedback; URLs use the validated initializer.
    public init(message: String, duration: Double = 1, type: ToastKind? = nil) {
        self.message = message
        self.duration = duration
        self.type = type
    }

    public init(url: URL) throws {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "prelude", parts.host?.lowercased() == "toast",
              parts.path.isEmpty || parts.path == "/",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil else {
            throw ConfigError("通知地址格式：prelude://toast?message=消息&duration=1")
        }
        var parameters: [String: String] = [:]
        for item in parts.queryItems ?? [] {
            guard ["message", "duration", "type"].contains(item.name),
                  parameters[item.name] == nil, let value = item.value else {
                throw ConfigError("通知参数无效或重复。")
            }
            parameters[item.name] = value
        }
        guard let text = parameters["message"] else { throw ConfigError("通知缺少 message。") }
        let normalized = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !normalized.isEmpty, normalized.count <= 200 else {
            throw ConfigError("通知消息须为 1–200 个字符。")
        }
        let seconds: Double
        if let value = parameters["duration"] {
            guard let parsed = Double(value), parsed.isFinite, (0.5...10).contains(parsed) else {
                throw ConfigError("duration 须为 0.5–10 秒。")
            }
            seconds = parsed
        } else { seconds = 1 }
        let kind: ToastKind?
        if let value = parameters["type"], !value.isEmpty {
            guard let parsed = ToastKind(rawValue: value.lowercased()) else {
                throw ConfigError("type 须为 success、error、warning、info，或留空。")
            }
            kind = parsed
        } else { kind = nil }
        self.init(message: normalized, duration: seconds, type: kind)
    }
}
