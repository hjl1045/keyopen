import XCTest
@testable import KeyOpenCore

final class AppVersionTests: XCTestCase {
    func testParsesTagsWithAndWithoutPrefix() {
        XCTAssertEqual(AppVersion("v0.2.0")?.components, [0, 2, 0])
        XCTAssertEqual(AppVersion("3.1.0")?.components, [3, 1, 0])
        XCTAssertEqual(AppVersion("1.2.0-beta")?.components, [1, 2, 0])
    }

    func testRejectsNonVersions() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("dev"))
        XCTAssertNil(AppVersion("1..2"))
        XCTAssertNil(AppVersion("KeyOpen 0.2"))
    }

    func testComparesNumericallyNotAsText() {
        XCTAssertLessThan(AppVersion("0.9.0")!, AppVersion("0.10.0")!)
        XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.1.1")!)
        XCTAssertEqual(AppVersion("1.0")!, AppVersion("1.0.0")!)
        XCTAssertFalse(AppVersion("1.0")! < AppVersion("1.0.0")!)
    }
}

final class UpdateCheckTests: XCTestCase {
    /// Trimmed from a real `releases/latest` response
    /// (sindresorhus/KeyboardShortcuts, 2026-10-25): an untitled release
    /// comes back with `"name": ""` and a tag without a "v".
    private func payload(tag: String, name: String) -> Data {
        """
        {"html_url": "https://github.com/hjl1045/keyopen/releases/tag/\(tag)",
         "tag_name": "\(tag)", "name": "\(name)", "draft": false, "prerelease": false,
         "body": "- Improve macOS 27 compatibility\\r\\n"}
        """.data(using: .utf8)!
    }

    private let current = AppVersion("0.1.0")!

    func testNewerReleaseIsOffered() {
        let outcome = UpdateCheck.evaluate(statusCode: 200,
                                           body: payload(tag: "v0.2.0", name: "Adds a Raycast reader"),
                                           current: current)
        guard case .available(let release) = outcome else { return XCTFail("\(String(describing: outcome))") }
        XCTAssertEqual(release.version, AppVersion("0.2.0"))
        XCTAssertEqual(release.url.absoluteString, "https://github.com/hjl1045/keyopen/releases/tag/v0.2.0")
        XCTAssertEqual(release.headline, "KeyOpen 0.2.0 is out — Adds a Raycast reader")
    }

    func testSameOrOlderReleaseMeansUpToDate() {
        XCTAssertEqual(UpdateCheck.evaluate(statusCode: 200, body: payload(tag: "v0.1.0", name: ""),
                                            current: current), .upToDate)
        XCTAssertEqual(UpdateCheck.evaluate(statusCode: 200, body: payload(tag: "0.0.9", name: ""),
                                            current: current), .upToDate)
    }

    func testNoReleaseYetIsUpToDate() {
        // What GitHub answers today for hjl1045/keyopen, which has no releases.
        XCTAssertEqual(UpdateCheck.evaluate(statusCode: 404, body: Data(), current: current), .upToDate)
    }

    func testFailuresAreUnknownNotUpToDate() {
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 403, body: Data(), current: current))
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 200, body: Data("{}".utf8), current: current))
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 200, body: payload(tag: "nightly", name: ""),
                                          current: current))
    }

    func testTitleThatOnlyRepeatsTheVersionIsDropped() {
        for name in ["", "v0.2.0", "0.2.0", "KeyOpen 0.2.0"] {
            let release = UpdateCheck.decodeLatest(payload(tag: "v0.2.0", name: name))
            XCTAssertNil(release?.title, name)
            XCTAssertEqual(release?.headline, "KeyOpen 0.2.0 is out.", name)
        }
    }
}
