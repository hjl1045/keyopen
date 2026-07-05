import XCTest
@testable import KeyOpenCore

final class RecommenderTests: XCTestCase {
    func testTopSuggestionsAreDeterministicForEmptyMap() {
        // Best modifier set is ⇧⌘; best keys are the "easy" set; A is reserved (⇧⌘A),
        // so the first three by candidate order are D, E, F.
        let recs = Recommender().recommend(from: ShortcutMap(), limit: 3)
        XCTAssertEqual(recs.map(\.displayString), ["⇧⌘D", "⇧⌘E", "⇧⌘F"])
    }

    func testExcludesTakenCombos() {
        var map = ShortcutMap()
        map.add(Binding(combo: KeyCombo(modifiers: [.command, .shift], key: "D"),
                        action: "Duplicate", source: .appMenu))
        let recs = Recommender().recommend(from: map, limit: 3)
        XCTAssertEqual(recs.map(\.displayString), ["⇧⌘E", "⇧⌘F", "⇧⌘J"])
    }

    func testNeverSuggestsReservedCombos() {
        let all = Recommender().recommend(from: ShortcutMap(), limit: 500)
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "A"))) // Redo/Deselect-ish
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "Z"))) // Redo
    }

    func testRespectsLimit() {
        XCTAssertEqual(Recommender().recommend(from: ShortcutMap(), limit: 5).count, 5)
    }
}
