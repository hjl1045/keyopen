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

/// A published KeyOpen release, as the site's feed describes it.
public struct Release: Equatable {
    public let version: AppVersion
    public let url: URL
    /// What the release adds, in a few words.
    public let title: String?

    /// "KeyOpen 0.2.0 is out — Adds a Raycast reader"; without a title, the
    /// short form.
    public var headline: String {
        let lead = "KeyOpen \(version) is out"
        guard let title else { return lead + "." }
        return "\(lead) — \(title)"
    }
}

/// Asks theautonomes.ai whether a newer release exists. No auto-install: the
/// answer is a link to the download page.
public enum UpdateCheck {
    public static let repository = URL(string: "https://github.com/hjl1045/keyopen")!
    /// Download and release notes, rendered from the same feed.
    public static let releasesPage = URL(string: "https://www.theautonomes.ai/keyopen")!
    public static let feed = URL(string: "https://www.theautonomes.ai/keyopen/releases.json")!
    /// A redirect on the site to the tip page, so the tip service can change
    /// without shipping a new build.
    public static let tipPage = URL(string: "https://www.theautonomes.ai/keyopen/coffee")!

    public enum Outcome: Equatable {
        case upToDate
        case available(Release)
    }

    /// Reads the release feed. Returns nil when we can't tell — offline, a
    /// payload we don't recognise — so the caller can say "couldn't check"
    /// rather than claim the user is current.
    public static func evaluate(statusCode: Int, body: Data, current: AppVersion) -> Outcome? {
        guard statusCode == 200, let release = decodeLatest(body) else { return nil }
        return release.version > current ? .available(release) : .upToDate
    }

    /// The feed is the site's `releases.json`: newest first, the same list the
    /// download page renders as "What's new", so the two can't disagree.
    ///
    ///     [{"version": "0.2.0", "date": "2026-10-26", "title": "Adds an About window",
    ///       "notes": ["…"], "download": "https://…/KeyOpen-0.2.0.zip"}]
    static func decodeLatest(_ data: Data) -> Release? {
        struct Entry: Decodable {
            let version: String
            let title: String?
        }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return nil }
        // Highest version wins even if someone appends instead of prepending.
        let releases = entries.compactMap { entry -> Release? in
            guard let version = AppVersion(entry.version) else { return nil }
            let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Release(version: version, url: releasesPage, title: title.isEmpty ? nil : title)
        }
        return releases.max { $0.version < $1.version }
    }
}
