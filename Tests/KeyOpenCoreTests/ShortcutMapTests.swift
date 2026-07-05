import XCTest
@testable import KeyOpenCore

final class ShortcutMapTests: XCTestCase {
    private let cmdS = KeyCombo(modifiers: [.command], key: "S")
    private let cmdSpace = KeyCombo(modifiers: [.command], key: "Space")

    func testIsTakenAndTakenCombos() {
        var map = ShortcutMap()
        map.add(Binding(combo: cmdS, action: "Save", source: .appMenu))
        XCTAssertTrue(map.isTaken(cmdS))
        XCTAssertFalse(map.isTaken(cmdSpace))
        XCTAssertEqual(map.takenCombos(), [cmdS])
    }

    func testConflictNeedsTwoDistinctBindings() {
        var map = ShortcutMap()
        map.add(Binding(combo: cmdSpace, action: "Spotlight", source: .system))
        map.add(Binding(combo: cmdSpace, action: "Command Palette", source: .appMenu))
        let conflicts = map.conflicts()
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.combo, cmdSpace)
        XCTAssertEqual(conflicts.first?.bindings.count, 2)
    }

    func testIdenticalDuplicatesAreNotAConflict() {
        var map = ShortcutMap()
        let b = Binding(combo: cmdS, action: "Save", source: .appMenu)
        map.add(b)
        map.add(b)
        XCTAssertTrue(map.conflicts().isEmpty)
    }
}
