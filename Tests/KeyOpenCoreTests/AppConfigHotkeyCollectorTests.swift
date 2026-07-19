import XCTest
@testable import KeyOpenCore

final class WisprFlowConfigTests: XCTestCase {
    /// Shaped exactly like the real `config.json`, trimmed to the shortcuts.
    private let sample = Data("""
    {"prefs": {"user": {"shortcuts": {
        "53": "dismiss",
        "4098": "popo",
        "55+58+59": "lens",
        "55+59+9": "paste_last_text",
        "44+59": "ptt",
        "1+58": "open_scratchpad",
        "32+55+56": "popo"
    }}}}
    """.utf8)

    func testDecodesHandsFreeToggleAsShiftCommandU() {
        let bindings = WisprFlowConfig.decode(sample)
        let handsFree = bindings.first { $0.action.contains("hands-free") }
        XCTAssertEqual(handsFree?.combo, KeyCombo(modifiers: [.shift, .command], key: "U"))
        XCTAssertEqual(handsFree?.action, "Wispr Flow · Toggle dictation (hands-free)")
        XCTAssertEqual(handsFree?.source, .globalHotkey)
    }

    func testDecodesModifierOnlyAndPunctuationCombos() {
        let bindings = WisprFlowConfig.decode(sample)
        let combos = Set(bindings.map(\.combo.displayString))
        XCTAssertTrue(combos.contains("⌃⌥⌘"), "modifier-only chord: \(combos)")
        XCTAssertTrue(combos.contains("⌃/"), "⌃/ push to talk: \(combos)")
        XCTAssertTrue(combos.contains("⌥S"), "⌥S scratchpad: \(combos)")
    }

    func testSkipsBareKeysAndSyntheticCodes() {
        let bindings = WisprFlowConfig.decode(sample)
        // "53" is a bare Escape (no modifier) and "4098" is a synthetic id —
        // neither is a combo we can present or recommend around.
        XCTAssertEqual(bindings.count, 5)
        XCTAssertNil(WisprFlowConfig.combo(fromKeyCodes: [53]))
        XCTAssertNil(WisprFlowConfig.combo(fromKeyCodes: [4098]))
    }

    func testIgnoresMalformedConfig() {
        XCTAssertTrue(WisprFlowConfig.decode(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(WisprFlowConfig.decode(Data(#"{"prefs":{}}"#.utf8)).isEmpty)
    }

    func testCollectorStaysQuietWhenTheAppIsNotRunning() {
        let collector = AppConfigHotkeyCollector(runningBundleIDs: ["com.apple.finder"])
        XCTAssertTrue(collector.collect().isEmpty)
    }

    /// Proves the reader works against the file as it actually exists — the decode
    /// tests above would happily pass on a format we invented. Skips where Wispr
    /// Flow isn't installed.
    func testReadsTheRealConfigWhenPresent() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appending(path: WisprFlowConfig.relativeConfigPath)
        try XCTSkipUnless(FileManager.default.isReadableFile(atPath: url.path),
                          "Wispr Flow config not present/readable on this machine")

        let bindings = WisprFlowConfig.decode(try Data(contentsOf: url))
        XCTAssertFalse(bindings.isEmpty, "read the real config but decoded nothing")
    }
}
