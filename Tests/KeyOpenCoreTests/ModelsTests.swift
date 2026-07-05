import XCTest
@testable import KeyOpenCore

final class ModelsTests: XCTestCase {
    func testDisplayStringUsesCanonicalGlyphOrder() {
        // Canonical macOS order is Control, Option, Shift, Command.
        let combo = KeyCombo(modifiers: [.command, .shift], key: "s")
        XCTAssertEqual(combo.displayString, "⇧⌘S")
    }

    func testKeyIsNormalizedToUppercase() {
        XCTAssertEqual(KeyCombo(modifiers: [.command], key: "d").key, "D")
    }

    func testHyperOrderingAndAllGlyphs() {
        let combo = KeyCombo(modifiers: [.control, .option, .command, .shift], key: "K")
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘K")
    }

    func testEqualityIgnoresModifierInsertionOrder() {
        let a = KeyCombo(modifiers: [.command, .shift], key: "S")
        let b = KeyCombo(modifiers: [.shift, .command], key: "s")
        XCTAssertEqual(a, b)
    }
}
