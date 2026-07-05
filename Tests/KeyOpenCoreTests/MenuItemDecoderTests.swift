import XCTest
@testable import KeyOpenCore

final class MenuItemDecoderTests: XCTestCase {
    func testPlainCommandLetter() {
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "s", cmdModifiers: 0, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command], key: "S"))
    }

    func testShiftCommand() {
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "s", cmdModifiers: 1, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command, .shift], key: "S"))
    }

    func testOptionControlCommand() {
        // 2 (option) | 4 (control) = 6, command implied.
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "l", cmdModifiers: 6, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command, .option, .control], key: "L"))
    }

    func testNoCommandBitSuppressesCommand() {
        // bit3 (8) set → command suppressed; only shift remains (1).
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "x", cmdModifiers: 9, cmdGlyph: nil),
                       KeyCombo(modifiers: [.shift], key: "X"))
    }

    func testNilCharReturnsNil() {
        XCTAssertNil(MenuItemDecoder.decode(cmdChar: nil, cmdModifiers: 0, cmdGlyph: 100))
        XCTAssertNil(MenuItemDecoder.decode(cmdChar: "", cmdModifiers: 0, cmdGlyph: nil))
    }
}
