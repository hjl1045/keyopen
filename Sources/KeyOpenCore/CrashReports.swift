import Foundation

/// Finds the crash reports macOS wrote for KeyOpen, so the next launch can offer
/// to send one. macOS already records every crash; there's no SDK and nothing
/// to install.
public enum CrashReports {
    public static let relativeDirectory = "Library/Logs/DiagnosticReports"

    public struct Entry: Equatable {
        public let name: String
        public let modified: Date

        public init(name: String, modified: Date) {
            self.name = name
            self.modified = modified
        }
    }

    /// Reports for `processName` written after `since`, newest first.
    ///
    /// macOS names them `<process>-<yyyy-MM-dd-HHmmss>.ips` (confirmed against
    /// a real report, 2026-10-25). The date must follow the hyphen directly, so
    /// another process whose name merely starts with ours — `KeyOpenHelper` —
    /// can't be mistaken for us.
    public static func new(in entries: [Entry], processName: String, since: Date) -> [Entry] {
        let prefix = processName + "-"
        return entries
            .filter { entry in
                entry.name.hasPrefix(prefix)
                    && entry.name.hasSuffix(".ips")
                    && entry.name.dropFirst(prefix.count).first?.isNumber == true
                    && entry.modified > since
            }
            .sorted { $0.modified > $1.modified }
    }
}
