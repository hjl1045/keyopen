import Foundation

/// What a bug report needs to be reproducible, and nothing more.
public struct DiagnosticInfo: Equatable {
    public let appVersion: String
    public let build: String
    public let osVersion: String

    public init(appVersion: String, build: String, osVersion: String) {
        self.appVersion = appVersion
        self.build = build
        self.osVersion = osVersion
    }

    /// "KeyOpen 0.1.0 (1) · macOS 26.1"
    public var line: String { "KeyOpen \(appVersion) (\(build)) · macOS \(osVersion)" }
}

/// Builds the text of feedback and crash reports. Sending is always the user's
/// own act — a Mail draft they send — so KeyOpen never transmits anything by
/// itself and needs no server.
public enum Feedback {
    public static let email = "hello@theautonomes.ai"

    public enum Kind {
        case feedback, crash
    }

    public static func subject(_ kind: Kind, info: DiagnosticInfo) -> String {
        switch kind {
        case .feedback: return "KeyOpen feedback (\(info.appVersion))"
        case .crash: return "KeyOpen crash report (\(info.appVersion))"
        }
    }

    public static func body(message: String, info: DiagnosticInfo?) -> String {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let info else { return text }
        return text.isEmpty ? info.line : "\(text)\n\n—\n\(info.line)"
    }

    /// The fallback when no Mail account is set up: the default mail handler,
    /// which can carry text but not an attachment.
    public static func mailtoURL(subject: String, body: String) -> URL {
        url(URL(string: "mailto:\(email)")!, query: [("subject", subject), ("body", body)])
    }

    private static func url(_ base: URL, query: [(String, String)]) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        // URLComponents leaves "+" alone, and mail clients read
        // a bare "+" as a space — which would eat the "+" in "⌘+".
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}
