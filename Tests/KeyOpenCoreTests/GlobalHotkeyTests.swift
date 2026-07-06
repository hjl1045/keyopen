import XCTest
@testable import KeyOpenCore

final class GlobalHotkeyTests: XCTestCase {
    func testCarbonKeyNames() {
        XCTAssertEqual(CarbonKey.name(forCarbonKeyCode: 40), "K")
        XCTAssertEqual(CarbonKey.name(forCarbonKeyCode: 46), "M")
        XCTAssertEqual(CarbonKey.name(forCarbonKeyCode: 38), "J")
        XCTAssertEqual(CarbonKey.name(forCarbonKeyCode: 0), "A")
        XCTAssertNil(CarbonKey.name(forCarbonKeyCode: 9999))
    }

    func testCarbonModifiers() {
        XCTAssertEqual(CarbonKey.modifiers(fromCarbonMask: 768), [.shift, .command])   // ⇧⌘
        XCTAssertEqual(CarbonKey.modifiers(fromCarbonMask: 4352), [.control, .command]) // ⌃⌘
        XCTAssertEqual(CarbonKey.modifiers(fromCarbonMask: 0), [])
    }

    func testDecodesRealLocalFlowValues() {
        // Exactly the strings found in LocalFlow's preferences.
        XCTAssertEqual(KeyboardShortcutsDecoder.decode(#"{"carbonKeyCode":40,"carbonModifiers":768}"#),
                       KeyCombo(modifiers: [.shift, .command], key: "K"))
        XCTAssertEqual(KeyboardShortcutsDecoder.decode(#"{"carbonKeyCode":46,"carbonModifiers":4352}"#),
                       KeyCombo(modifiers: [.control, .command], key: "M"))
    }

    func testDecodeRejectsGarbage() {
        XCTAssertNil(KeyboardShortcutsDecoder.decode("not json"))
        XCTAssertNil(KeyboardShortcutsDecoder.decode(#"{"carbonKeyCode":9999,"carbonModifiers":768}"#))
    }
}
