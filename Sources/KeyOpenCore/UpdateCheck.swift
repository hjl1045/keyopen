import Foundation

/// A dotted release number — `0.2.0`, `v1.3` — compared numerically, so 0.10
/// sorts after 0.9 and `1.0` equals `1.0.0`.
public struct AppVersion: Comparable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        // A pre-release or build suffix ("1.2.0-beta") isn't something we
        // publish; the numeric core decides.
        let core = text.split(whereSeparator: { $0 == "-" || $0 == "+" }).first ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        components = parts.compactMap { $0 }
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        padded(lhs, rhs).0 == padded(lhs, rhs).1
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let (a, b) = padded(lhs, rhs)
        return a.lexicographicallyPrecedes(b)
    }

    private static func padded(_ lhs: AppVersion, _ rhs: AppVersion) -> ([Int], [Int]) {
        let width = max(lhs.components.count, rhs.components.count)
        func pad(_ c: [Int]) -> [Int] { c + Array(repeating: 0, count: width - c.count) }
        return (pad(lhs.components), pad(rhs.components))
    }
}

/// A published KeyOpen release, as GitHub describes it.
public struct Release: Equatable {
    public let version: AppVersion
    public let url: URL
    /// The release's title on GitHub, when it says more than the tag does.
    public let title: String?

    /// "KeyOpen 0.2.0 is out — Adds a Raycast reader". Name releases by what
    /// they add and this line explains itself; a bare tag gives the short form.
    public var headline: String {
        let lead = "KeyOpen \(version) is out"
        guard let title else { return lead + "." }
        return "\(lead) — \(title)"
    }
}

/// Asks GitHub whether a newer release exists. No auto-install: the answer is a
/// link, and Homebrew users update through `brew` anyway.
public enum UpdateCheck {
    public static let repository = URL(string: "https://github.com/hjl1045/keyopen")!
    public static let releasesPage = URL(string: "https://github.com/hjl1045/keyopen/releases")!
    public static let latestReleaseAPI =
        URL(string: "https://api.github.com/repos/hjl1045/keyopen/releases/latest")!

    public enum Outcome: Equatable {
        case upToDate
        case available(Release)
    }

    /// Reads GitHub's `releases/latest` response. That endpoint never returns
    /// drafts or pre-releases, so whatever it names is fair to offer.
    ///
    /// Returns nil when we can't tell — offline, rate-limited, a payload we
    /// don't recognise — so the caller can say "couldn't check" rather than
    /// claim the user is current.
    public static func evaluate(statusCode: Int, body: Data, current: AppVersion) -> Outcome? {
        // 404 is what GitHub answers until the first release is published.
        if statusCode == 404 { return .upToDate }
        guard statusCode == 200, let release = decodeLatest(body) else { return nil }
        return release.version > current ? .available(release) : .upToDate
    }

    static func decodeLatest(_ data: Data) -> Release? {
        struct Payload: Decodable {
            let tag_name: String
            let name: String?
            let html_url: URL
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let version = AppVersion(payload.tag_name)
        else { return nil }
        let name = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // GitHub fills an untitled release's name with "" or repeats the tag.
        let saysMore = !name.isEmpty && AppVersion(name) == nil
            && name != payload.tag_name && name != "KeyOpen \(version)"
        return Release(version: version, url: payload.html_url, title: saysMore ? name : nil)
    }
}
