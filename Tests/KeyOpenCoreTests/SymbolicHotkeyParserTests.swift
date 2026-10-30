import XCTest
@testable import KeyOpenCore

final class SymbolicHotkeyParserTests: XCTestCase {
    // Cocoa modifier flags: command = 1<<20 (1048576), shift = 1<<17 (131072).

    private func combos(_ bindings: [Binding]) -> Set<String> {
        Set(bindings.map(\.combo.displayString))
    }

    private func action(for display: String, in bindings: [Binding]) -> String? {
        bindings.first { $0.combo.displayString == display }?.action
    }

    func testParsesEnabledSpotlightHotkey() {
        let dict: [String: Any] = [
            "64": ["enabled": true,
                   "value": ["parameters": [32, 49, 1048576]]] // Cmd + Space
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(action(for: "⌘SPACE", in: bindings), "Spotlight – Show search field")
        XCTAssertTrue(bindings.allSatisfy { $0.source == .system })
    }

    func testSkipsDisabledEntries() {
        let dict: [String: Any] = [
            "64": ["enabled": false,
                   "value": ["parameters": [32, 49, 1048576]]]
        ]
        XCTAssertNil(action(for: "⌘SPACE", in: SymbolicHotkeyParser.parse(dict)))
    }

    func testUnknownIdFallsBackToGenericName() {
        let dict: [String: Any] = [
            "9999": ["enabled": true,
                     "value": ["parameters": [65, 0, 1048576 + 131072]]] // Cmd+Shift+A
        ]
        XCTAssertEqual(action(for: "⇧⌘A", in: SymbolicHotkeyParser.parse(dict)), "System hotkey #9999")
    }

    func testCollectorForwardsInjectedHotkeys() {
        let dict: [String: Any] = [
            "9999": ["enabled": true, "value": ["parameters": [65, 0, 1048576 + 131072]]]
        ]
        let collector = SystemShortcutCollector(rawHotkeys: dict)
        XCTAssertTrue(combos(collector.collect()).contains("⇧⌘A"))
    }

    // MARK: macOS defaults

    func testUntouchedDefaultsCountAsTaken() {
        // macOS writes an entry only once you change a shortcut. An empty plist
        // offered the screenshot keys as free.
        let bindings = SymbolicHotkeyParser.parse([:])
        for taken in ["⇧⌘3", "⇧⌘4", "⇧⌘5", "⌃⇧⌘3", "⌃⇧⌘4", "⌥⌘D"] {
            XCTAssertTrue(combos(bindings).contains(taken), taken)
        }
        XCTAssertEqual(action(for: "⇧⌘3", in: bindings), "Save picture of screen as a file")
        XCTAssertEqual(action(for: "⌥⌘D", in: bindings), "Turn Dock hiding on or off")
    }

    func testATurnedOffDefaultIsFree() {
        let dict: [String: Any] = ["28": ["enabled": false]]
        XCTAssertFalse(combos(SymbolicHotkeyParser.parse(dict)).contains("⇧⌘3"))
    }

    func testAChangedDefaultUsesTheNewKeys() {
        let dict: [String: Any] = [
            "28": ["enabled": true, "value": ["parameters": [54, 22, 1048576 + 131072]]] // ⇧⌘6
        ]
        let found = combos(SymbolicHotkeyParser.parse(dict))
        XCTAssertTrue(found.contains("⇧⌘6"))
        XCTAssertFalse(found.contains("⇧⌘3"))
    }

    func testEnabledWithNoKeysStoredMeansTheDefaultKeys() {
        let dict: [String: Any] = ["28": ["enabled": true]]
        XCTAssertTrue(combos(SymbolicHotkeyParser.parse(dict)).contains("⇧⌘3"))
    }

    func testGlobeKeyIsRead() {
        // Quick Note is Globe-Q. Dropping the fn bit showed a bare "Q" as taken.
        let dict: [String: Any] = [
            "190": ["enabled": true, "value": ["parameters": [113, 12, 8388608]]]
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(action(for: "🌐Q", in: bindings), "Quick Note")
        XCTAssertNil(action(for: "Q", in: bindings))
    }

    func testAModifierOnlyGestureIsNotReadAsAKeyCombo() {
        // Siri's newer shortcut: key code 55 is ⌘ itself, so the stored Space
        // character must not turn it into ⌘Space.
        let dict: [String: Any] = [
            "64": ["enabled": false],
            "176": ["enabled": true, "value": ["type": "SAE1.0", "parameters": [32, 55, 1048600]]]
        ]
        XCTAssertNil(action(for: "⌘SPACE", in: SymbolicHotkeyParser.parse(dict)))
    }

    func testScreenshotKeysAreNotOfferedAsFreeOnThisMac() throws {
        // Reads this Mac's real settings. Skip if someone turned the screenshot
        // shortcuts off, since then they are free.
        let raw = (UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")?["AppleSymbolicHotKeys"] as? [String: Any]) ?? [:]
        let turnedOff = ["28", "30", "184"].contains { ((raw[$0] as? [String: Any])?["enabled"] as? Bool) == false }
        try XCTSkipIf(turnedOff, "screenshot shortcuts are turned off on this Mac")
        let scan = ScanEngine.run(system: SystemShortcutCollector(store: .userDefaults), app: nil,
                                  globals: MergedCollector([]), appBundleID: nil)
        let free = Set(scan.recommendations.map(\.combo.displayString))
        XCTAssertTrue(free.isDisjoint(with: ["⇧⌘3", "⇧⌘4", "⇧⌘5"]), "offered: \(free.intersection(["⇧⌘3", "⇧⌘4", "⇧⌘5"]))")
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
