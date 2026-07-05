import XCTest
@testable import KeyOpenCore

final class RecommenderTests: XCTestCase {
    func testTopSuggestionsAreDeterministicForEmptyMap() {
        // Best modifier set is ⇧⌘; best keys are the "easy" set; A is reserved (⇧⌘A),
        // so the first three by candidate order are D, E, F.
        let recs = Recommender().recommend(from: ShortcutMap(), limit: 3)
        XCTAssertEqual(recs.map { $0.combo.displayString }, ["⇧⌘D", "⇧⌘E", "⇧⌘F"])
        XCTAssertTrue(recs.allSatisfy { $0.overlaps.isEmpty })
    }

    func testExcludesTakenCombos() {
        var map = ShortcutMap()
        map.add(Binding(combo: KeyCombo(modifiers: [.command, .shift], key: "D"),
                        action: "Duplicate", source: .appMenu))
        let recs = Recommender().recommend(from: map, limit: 3)
        XCTAssertEqual(recs.map { $0.combo.displayString }, ["⇧⌘E", "⇧⌘F", "⇧⌘J"])
    }

    func testNeverSuggestsReservedCombos() {
        let all = Recommender().recommend(from: ShortcutMap(), limit: 500).map(\.combo)
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "A"))) // Redo/Deselect-ish
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "Z"))) // Redo
    }

    func testRespectsLimit() {
        XCTAssertEqual(Recommender().recommend(from: ShortcutMap(), limit: 5).count, 5)
    }

    func testDownRanksAndAnnotatesWhenSimplerFormInUse() {
        // ⌘E is a strict-subset of ⇧⌘E on the same key, so ⇧⌘E is down-ranked...
        var map = ShortcutMap()
        map.add(Binding(combo: KeyCombo(modifiers: [.command], key: "E"),
                        action: "Edit", source: .appMenu))
        let top = Recommender().recommend(from: map, limit: 3)
        XCTAssertEqual(top.map { $0.combo.displayString }, ["⇧⌘D", "⇧⌘F", "⇧⌘J"])

        // ...but it's still offered, flagged with the overlapping simpler form.
        let all = Recommender().recommend(from: map, limit: 500)
        let e = all.first { $0.combo == KeyCombo(modifiers: [.command, .shift], key: "E") }
        XCTAssertEqual(e?.overlaps, [KeyCombo(modifiers: [.command], key: "E")])
    }
}
