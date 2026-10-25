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
/// own act — a Mail draft or a prefilled GitHub issue they submit — so KeyOpen
/// never transmits anything by itself and needs no server.
public enum Feedback {
    public static let email = "hello@theautonomes.ai"
    static let newIssue = URL(string: "https://github.com/hjl1045/keyopen/issues/new")!

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

    /// A prefilled "new issue" page. The title is the message's first line, so
    /// the issue list stays scannable.
    public static func issueURL(message: String, info: DiagnosticInfo?) -> URL {
        let firstLine = message.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let title = firstLine.isEmpty ? "Feedback" : String(firstLine.prefix(80))
        // Browsers and GitHub both choke on very long URLs; a report that
        // long belongs in an email anyway.
        let body = String(body(message: message, info: info).prefix(6000))
        return url(newIssue, query: [("title", title), ("body", body)])
    }

    /// The fallback when no Mail account is set up: the default mail handler,
    /// which can carry text but not an attachment.
    public static func mailtoURL(subject: String, body: String) -> URL {
        url(URL(string: "mailto:\(email)")!, query: [("subject", subject), ("body", body)])
    }

    private static func url(_ base: URL, query: [(String, String)]) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        // URLComponents leaves "+" alone, and both GitHub and mail clients read
        // a bare "+" as a space — which would eat the "+" in "⌘+".
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}
