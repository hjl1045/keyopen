import XCTest
@testable import KeyOpenCore

final class FollowFrontTests: XCTestCase {
    func testSwitchingAppsWhileThePanelIsOpenRescans() {
        XCTAssertTrue(FollowFront.shouldRescan(panelVisible: true, front: 200, shown: 100))
    }

    func testAHiddenPanelDoesNotReadEveryAppYouSwitchTo() {
        XCTAssertFalse(FollowFront.shouldRescan(panelVisible: false, front: 200, shown: 100))
    }

    func testTheAppAlreadyShownIsNotReadAgain() {
        XCTAssertFalse(FollowFront.shouldRescan(panelVisible: true, front: 100, shown: 100))
    }

    func testNoFrontAppKeepsWhatIsShown() {
        XCTAssertFalse(FollowFront.shouldRescan(panelVisible: true, front: nil, shown: 100))
    }

    func testNothingShownYetScans() {
        XCTAssertTrue(FollowFront.shouldRescan(panelVisible: true, front: 100, shown: nil))
    }
}
