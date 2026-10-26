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

/// The sandboxed build reads preference plists from disk instead of asking
/// `cfprefsd`. Both must decode the same shortcuts, or the App Store build
/// would recommend combos the direct build knows are taken.
final class PreferenceStoreTests: XCTestCase {
    func testFilesMatchUserDefaultsOnThisMac() throws {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
        let plist = library.appending(path: "Preferences/com.apple.symbolichotkeys.plist")
        try XCTSkipUnless(FileManager.default.isReadableFile(atPath: plist.path),
                          "no symbolic hotkeys plist on this machine")

        let fromDefaults = SystemShortcutCollector(store: .userDefaults).collect()
        let fromFiles = SystemShortcutCollector(store: .files(library: library)).collect()
        XCTAssertFalse(fromFiles.isEmpty)
        XCTAssertEqual(Set(fromFiles.map(\.combo)), Set(fromDefaults.map(\.combo)))
    }

    func testFilesReadFromTheGrantedLibrary() throws {
        let library = FileManager.default.temporaryDirectory
            .appending(path: "PreferenceStoreTests-\(UUID().uuidString)/Library")
        try FileManager.default.createDirectory(at: library.appending(path: "Preferences"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: library.deletingLastPathComponent()) }
        let prefs: [String: Any] = ["KeyboardShortcuts_toggle": #"{"carbonKeyCode":40,"carbonModifiers":768}"#]
        try PropertyListSerialization.data(fromPropertyList: prefs, format: .binary, options: 0)
            .write(to: library.appending(path: "Preferences/com.example.app.plist"))

        let store = PreferenceStore.files(library: library)
        XCTAssertEqual(store.home, library.deletingLastPathComponent())
        let found = GlobalHotkeyCollector(apps: [.init(bundleID: "com.example.app", name: "Example")],
                                          store: store).collect()
        XCTAssertEqual(found.map(\.combo.displayString), ["⇧⌘K"])
        XCTAssertEqual(found.first?.action, "Toggle")
    }
}
