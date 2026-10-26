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
    /// The shape of theautonomes.ai/keyopen/releases.json: newest first.
    private func feed(_ entries: [(String, String?)]) -> Data {
        let items = entries.map { version, title in
            let titleField = title.map { #", "title": "\#($0)""# } ?? ""
            return #"{"version": "\#(version)", "date": "2026-10-26"\#(titleField), "notes": ["x"], "download": "https://www.theautonomes.ai/downloads/KeyOpen-\#(version).zip"}"#
        }
        return Data("[\(items.joined(separator: ","))]".utf8)
    }

    private let current = AppVersion("0.1.0")!

    func testNewerReleaseIsOffered() {
        let outcome = UpdateCheck.evaluate(statusCode: 200,
                                           body: feed([("0.2.0", "Adds a Raycast reader"), ("0.1.0", nil)]),
                                           current: current)
        guard case .available(let release) = outcome else { return XCTFail("\(String(describing: outcome))") }
        XCTAssertEqual(release.version, AppVersion("0.2.0"))
        XCTAssertEqual(release.url, UpdateCheck.homePage)
        XCTAssertEqual(release.headline, "KeyOpen 0.2.0 is out — Adds a Raycast reader")
    }

    func testSameOrOlderReleaseMeansUpToDate() {
        XCTAssertEqual(UpdateCheck.evaluate(statusCode: 200, body: feed([("0.1.0", nil)]), current: current),
                       .upToDate)
        XCTAssertEqual(UpdateCheck.evaluate(statusCode: 200, body: feed([("0.0.9", nil)]), current: current),
                       .upToDate)
    }

    func testHighestVersionWinsWhateverTheOrder() {
        let release = UpdateCheck.decodeLatest(feed([("0.1.0", nil), ("0.10.0", "Later"), ("0.9.0", nil)]))
        XCTAssertEqual(release?.version, AppVersion("0.10.0"))
        XCTAssertEqual(release?.title, "Later")
    }

    func testFailuresAreUnknownNotUpToDate() {
        // A missing feed is a broken site, not proof the user is current.
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 404, body: Data(), current: current))
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 500, body: Data(), current: current))
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 200, body: Data("{}".utf8), current: current))
        // Vercel answers unknown paths with the SPA's index.html, status 200.
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 200, body: Data("<!doctype html>".utf8), current: current))
        XCTAssertNil(UpdateCheck.evaluate(statusCode: 200, body: feed([("nightly", nil)]), current: current))
    }

    func testUntitledReleaseGetsTheShortHeadline() {
        XCTAssertEqual(UpdateCheck.decodeLatest(feed([("0.2.0", nil)]))?.headline, "KeyOpen 0.2.0 is out.")
        XCTAssertEqual(UpdateCheck.decodeLatest(feed([("0.2.0", "  ")]))?.headline, "KeyOpen 0.2.0 is out.")
    }
}
