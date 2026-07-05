import XCTest
@testable import KeyOpenCore

final class SymbolicHotkeyParserTests: XCTestCase {
    // Cocoa modifier flags: command = 1<<20 (1048576), shift = 1<<17 (131072).

    func testParsesEnabledSpotlightHotkey() {
        let dict: [String: Any] = [
            "64": ["enabled": true,
                   "value": ["parameters": [32, 49, 1048576]]] // Cmd + Space
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings[0].combo, KeyCombo(modifiers: [.command], key: "Space"))
        XCTAssertEqual(bindings[0].action, "Spotlight – Show search field")
        XCTAssertEqual(bindings[0].source, .system)
    }

    func testSkipsDisabledEntries() {
        let dict: [String: Any] = [
            "64": ["enabled": false,
                   "value": ["parameters": [32, 49, 1048576]]]
        ]
        XCTAssertTrue(SymbolicHotkeyParser.parse(dict).isEmpty)
    }

    func testUnknownIdFallsBackToGenericName() {
        let dict: [String: Any] = [
            "9999": ["enabled": true,
                     "value": ["parameters": [65, 0, 1048576 + 131072]]] // Cmd+Shift+A
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings[0].combo, KeyCombo(modifiers: [.command, .shift], key: "A"))
        XCTAssertEqual(bindings[0].action, "System hotkey #9999")
    }

    func testCollectorForwardsInjectedHotkeys() {
        let dict: [String: Any] = [
            "64": ["enabled": true, "value": ["parameters": [32, 49, 1048576]]]
        ]
        let collector = SystemShortcutCollector(rawHotkeys: dict)
        XCTAssertEqual(collector.collect().count, 1)
    }
}
