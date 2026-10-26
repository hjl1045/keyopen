import XCTest
@testable import KeyOpenCore

final class FeedbackTests: XCTestCase {
    private let info = DiagnosticInfo(appVersion: "0.1.0", build: "1", osVersion: "26.1")

    private func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func testBodyAppendsVersionLineOnlyWhenAsked() {
        XCTAssertEqual(Feedback.body(message: "  Alfred missed  \n", info: nil), "Alfred missed")
        XCTAssertEqual(Feedback.body(message: "Alfred missed", info: info),
                       "Alfred missed\n\n—\nKeyOpen 0.1.0 (1) · macOS 26.1")
        XCTAssertEqual(Feedback.body(message: "", info: info), "KeyOpen 0.1.0 (1) · macOS 26.1")
    }

    func testPlusSignsSurviveEncoding() {
        // "+" read as a space would turn "⌘+" into "⌘ ".
        let url = Feedback.mailtoURL(subject: "a+b", body: "Bind ⌘+ please")
        XCTAssertFalse(url.absoluteString.contains("+"), url.absoluteString)
        XCTAssertEqual(query(url)["body"], "Bind ⌘+ please")
        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:hello@theautonomes.ai?"))
    }

    func testSubjectsNameTheVersion() {
        XCTAssertEqual(Feedback.subject(.feedback, info: info), "KeyOpen feedback (0.1.0)")
        XCTAssertEqual(Feedback.subject(.crash, info: info), "KeyOpen crash report (0.1.0)")
    }
}

final class CrashReportsTests: XCTestCase {
    private let since = Date(timeIntervalSince1970: 1_000)
    private func entry(_ name: String, _ t: TimeInterval) -> CrashReports.Entry {
        .init(name: name, modified: Date(timeIntervalSince1970: t))
    }

    func testFindsOnlyOurNewReportsNewestFirst() {
        let entries = [
            entry("KeyOpen-2026-10-25-155150.ips", 2_000),
            entry("KeyOpen-2026-10-26-090000.ips", 3_000),
            entry("KeyOpen-2026-10-01-120000.ips", 500),   // already seen
            entry("KeyOpenHelper-2026-10-25-1.ips", 2_000), // another process
            entry("probe-sbx-2026-10-25-155150.ips", 2_000), // real name from this Mac
            entry("KeyOpen-2026-10-25-155150.diag", 2_000), // not a crash report
            entry("Retired", 2_000),
        ]
        XCTAssertEqual(CrashReports.new(in: entries, processName: "KeyOpen", since: since).map(\.name),
                       ["KeyOpen-2026-10-26-090000.ips", "KeyOpen-2026-10-25-155150.ips"])
    }
}
