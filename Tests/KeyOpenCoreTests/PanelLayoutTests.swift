import XCTest
@testable import KeyOpenCore

final class PanelLayoutTests: XCTestCase {
    /// The regression that shipped: the list collapsed to nothing and clipped
    /// every section away, leaving a panel with a header and a scrollbar stub.
    func testTheListNeverCollapses() {
        XCTAssertGreaterThanOrEqual(
            PanelLayout.listHeight(sections: [], recommendations: 0),
            PanelLayout.minListHeight)

        let empty = PanelLayout.SectionMetrics(rows: 0, expanded: true, conflicts: 0)
        XCTAssertGreaterThanOrEqual(
            PanelLayout.listHeight(sections: [empty], recommendations: 0),
            PanelLayout.minListHeight)
    }

    /// Linear: ~50 menu commands plus 25 global hotkeys, which is what blew past
    /// the screen edge in the first place.
    func testALongAppCapsAndScrollsRatherThanGrowing() {
        let sections = [
            PanelLayout.SectionMetrics(rows: 1, expanded: true, conflicts: 0),
            PanelLayout.SectionMetrics(rows: 48, expanded: true, conflicts: 2),
            PanelLayout.SectionMetrics(rows: 25, expanded: true, conflicts: 2),
        ]
        XCTAssertEqual(PanelLayout.listHeight(sections: sections, recommendations: 9),
                       PanelLayout.maxListHeight)
    }

    func testFoldingASectionShrinksTheListToItsHeaderAlone() {
        // Small enough that neither case hits the cap, so the saving is exact.
        let open = PanelLayout.SectionMetrics(rows: 10, expanded: true, conflicts: 0)
        let shut = PanelLayout.SectionMetrics(rows: 10, expanded: false, conflicts: 0)
        let openHeight = PanelLayout.listHeight(sections: [open], recommendations: 3)
        let shutHeight = PanelLayout.listHeight(sections: [shut], recommendations: 3)

        XCTAssertLessThan(openHeight, PanelLayout.maxListHeight)
        // Only the header survives, so the saving is the rows themselves.
        XCTAssertEqual(openHeight - shutHeight, 10 * PanelLayout.rowHeight)
    }

    /// With a section long enough to be capped, folding it still has to bring
    /// the list back under the ceiling — otherwise collapsing would look inert.
    func testFoldingACappedSectionDropsBelowTheCeiling() {
        let open = PanelLayout.SectionMetrics(rows: 48, expanded: true, conflicts: 0)
        let shut = PanelLayout.SectionMetrics(rows: 48, expanded: false, conflicts: 0)
        XCTAssertEqual(PanelLayout.listHeight(sections: [open], recommendations: 3),
                       PanelLayout.maxListHeight)
        XCTAssertLessThan(PanelLayout.listHeight(sections: [shut], recommendations: 3),
                          PanelLayout.maxListHeight)
    }

    /// A short app should get a short panel, not 420pt of mostly blank space.
    func testAShortAppStaysCompact() {
        let sections = [
            PanelLayout.SectionMetrics(rows: 2, expanded: true, conflicts: 0),
            PanelLayout.SectionMetrics(rows: 6, expanded: true, conflicts: 0),
        ]
        let height = PanelLayout.listHeight(sections: sections, recommendations: 4)
        XCTAssertLessThan(height, PanelLayout.maxListHeight)
        XCTAssertGreaterThan(height, PanelLayout.minListHeight)
    }

    func testCaveatedOpenSlotsGetRoomForTheirNote() {
        let plain = PanelLayout.listHeight(sections: [], recommendations: 6)
        let caveated = PanelLayout.listHeight(sections: [], recommendations: 6,
                                              caveatedRecommendations: 2)
        XCTAssertEqual(caveated - plain, 2 * PanelLayout.conflictNoteHeight)
    }

    func testConflictNotesAreCountedSoTheirRowsAreNotClipped() {
        let clean = PanelLayout.SectionMetrics(rows: 10, expanded: true, conflicts: 0)
        let flagged = PanelLayout.SectionMetrics(rows: 10, expanded: true, conflicts: 3)
        XCTAssertEqual(
            PanelLayout.listHeight(sections: [flagged], recommendations: 0)
                - PanelLayout.listHeight(sections: [clean], recommendations: 0),
            3 * PanelLayout.conflictNoteHeight)
    }

    func testTheMenusNoteMakesRoomForItself() {
        let bare = PanelLayout.SectionMetrics(rows: 0, expanded: true, conflicts: 0)
        let noted = PanelLayout.SectionMetrics(rows: 0, expanded: true, conflicts: 0, hasNote: true)
        XCTAssertEqual(PanelLayout.listHeight(sections: [noted], recommendations: 8)
                       - PanelLayout.listHeight(sections: [bare], recommendations: 8),
                       PanelLayout.menusNoteHeight)
    }

    func testMenusNoteNamesTheApp() {
        XCTAssertEqual(MenusNote.text(appName: "Google Chrome"),
                       "Check Google Chrome’s menus for its existing shortcuts.")
        XCTAssertEqual(MenusNote.text(appName: "Messages"),
                       "Check Messages’ menus for its existing shortcuts.")
    }
}
