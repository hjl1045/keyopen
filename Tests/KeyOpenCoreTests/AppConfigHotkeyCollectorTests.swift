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
        XCTAssertEqual(handsFree?.action, "Toggle dictation (hands-free)")
        XCTAssertEqual(handsFree?.source, .globalHotkey)
        XCTAssertEqual(handsFree?.owner, Owner(bundleID: WisprFlowConfig.bundleID, name: "Wispr Flow"))
        XCTAssertEqual(handsFree?.qualifiedAction, "Wispr Flow · Toggle dictation (hands-free)")
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

    func testCollectorStaysQuietWhenNoKnownAppIsRunning() {
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

final class KeyboardMaestroConfigTests: XCTestCase {
    /// Shaped exactly like `Keyboard Maestro Macros.plist`, trimmed to the
    /// triggers. The hot keys are real ones from that file; the two `IsActive`
    /// flags are how Keyboard Maestro records a switched-off group or macro.
    private let sample = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>MacroGroups</key>
      <array>
        <dict>
          <key>Name</key><string>Learn OmniFocus</string>
          <key>Macros</key>
          <array>
            <dict>
              <key>Name</key><string>Jump to Inbox</string>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>HotKey</string>
                <key>FireType</key><string>Pressed</string>
                <key>KeyCode</key><integer>18</integer>
                <key>Modifiers</key><integer>6400</integer>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Quick Entry</string>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>HotKey</string>
                <key>KeyCode</key><integer>49</integer>
                <key>Modifiers</key><integer>6144</integer>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Retired macro</string>
              <key>IsActive</key><false/>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>HotKey</string>
                <key>KeyCode</key><integer>17</integer>
                <key>Modifiers</key><integer>6400</integer>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Insert TOC</string>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>TypedString</string>
                <key>TypedString</key><string>;toc</string>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Nothing bound yet</string>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>HotKey</string>
                <key>KeyCode</key><integer>32767</integer>
                <key>Modifiers</key><integer>0</integer>
              </dict></array>
            </dict>
          </array>
        </dict>
        <dict>
          <key>Name</key><string>Clipboards</string>
          <key>IsActive</key><false/>
          <key>Macros</key>
          <array>
            <dict>
              <key>Name</key><string>Macro in a switched-off group</string>
              <key>Triggers</key><array><dict>
                <key>MacroTriggerType</key><string>HotKey</string>
                <key>KeyCode</key><integer>8</integer>
                <key>Modifiers</key><integer>2816</integer>
              </dict></array>
            </dict>
          </array>
        </dict>
      </array>
    </dict></plist>
    """.utf8)

    func testDecodesCarbonCodeAndMaskAsKeyboardMaestroRendersThem() {
        let bindings = KeyboardMaestroConfig.decode(sample)
        let inbox = bindings.first { $0.action == "Jump to Inbox" }
        // Keyboard Maestro's engine renders this trigger as "The Hot Key ⌃⌥⌘1".
        XCTAssertEqual(inbox?.combo, KeyCombo(modifiers: [.control, .option, .command], key: "1"))
        XCTAssertEqual(inbox?.combo.displayString, "⌃⌥⌘1")
        XCTAssertEqual(inbox?.source, .globalHotkey)
        XCTAssertEqual(inbox?.owner, Owner(bundleID: KeyboardMaestroConfig.bundleID, name: "Keyboard Maestro"))
        XCTAssertEqual(inbox?.qualifiedAction, "Keyboard Maestro · Jump to Inbox")

        let quickEntry = bindings.first { $0.action == "Quick Entry" }
        XCTAssertEqual(quickEntry?.combo, KeyCombo(modifiers: [.control, .option], key: "Space"))
    }

    func testSkipsSwitchedOffMacrosAndGroupsAndNonHotkeyTriggers() {
        let actions = Set(KeyboardMaestroConfig.decode(sample).map(\.action))
        XCTAssertEqual(actions, ["Jump to Inbox", "Quick Entry"])
        // A switched-off macro or group has no hotkey registered, so its slot
        // really is free — but "absent" has to keep meaning "on".
        XCTAssertFalse(KeyboardMaestroConfig.isActive(["IsActive": false]))
        XCTAssertTrue(KeyboardMaestroConfig.isActive(["Name": "anything"]))
    }

    func testSkipsTheNoKeySentinel() {
        XCTAssertNil(KeyboardMaestroConfig.combo(from: ["KeyCode": 32767, "Modifiers": 0]))
        XCTAssertNil(KeyboardMaestroConfig.combo(from: ["Modifiers": 6400]))
    }

    func testIgnoresMalformedConfig() {
        XCTAssertTrue(KeyboardMaestroConfig.decode(Data("not a plist".utf8)).isEmpty)
        XCTAssertTrue(KeyboardMaestroConfig.decode(Data("<plist version=\"1.0\"><dict/></plist>".utf8)).isEmpty)
    }

    /// Proves the reader works against the file as it actually exists. Skips
    /// where Keyboard Maestro isn't installed.
    func testReadsTheRealMacroLibraryWhenPresent() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appending(path: KeyboardMaestroConfig.relativeConfigPath)
        try XCTSkipUnless(FileManager.default.isReadableFile(atPath: url.path),
                          "Keyboard Maestro macros not present/readable on this machine")

        let bindings = KeyboardMaestroConfig.decode(try Data(contentsOf: url))
        try XCTSkipIf(bindings.isEmpty, "Keyboard Maestro is installed but no macro uses a hot key trigger")
        for binding in bindings {
            XCTAssertFalse(binding.action.isEmpty)
            XCTAssertFalse(binding.combo.key.isEmpty, "\(binding.action) decoded to modifiers alone")
        }
    }
}

final class AlfredConfigTests: XCTestCase {
    /// Shaped exactly like `hotkey/prefs.plist`. `string` is Alfred's own name
    /// for the key, which makes the file self-checking.
    private let sample = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>default</key>
      <dict>
        <key>key</key><integer>49</integer>
        <key>mod</key><integer>1048576</integer>
        <key>string</key><string> </string>
      </dict>
    </dict></plist>
    """.utf8)

    /// `features/clipboard/prefs.plist` — a different slot name, same shape.
    private let clipboardSample = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>hotkey</key>
      <dict>
        <key>key</key><integer>9</integer>
        <key>mod</key><integer>1572864</integer>
        <key>string</key><string>V</string>
      </dict>
    </dict></plist>
    """.utf8)

    func testDecodesTheCocoaModifierMaskNotTheCarbonOne() {
        let showAlfred = AlfredConfig.decode(sample, action: "Show Alfred").first
        XCTAssertEqual(showAlfred?.combo, KeyCombo(modifiers: [.command], key: "Space"))
        XCTAssertEqual(showAlfred?.action, "Show Alfred")
        XCTAssertEqual(showAlfred?.owner, Owner(bundleID: AlfredConfig.bundleID, name: "Alfred"))

        // 1572864 is ⌥⌘ as an NSEvent mask; read as a Carbon mask it would be
        // nothing at all, which is exactly the false negative to avoid.
        let clipboard = AlfredConfig.decode(clipboardSample, action: "Clipboard history").first
        XCTAssertEqual(clipboard?.combo.displayString, "⌥⌘V")
        XCTAssertTrue(CarbonKey.modifiers(fromCarbonMask: 1_572_864).isEmpty)
    }

    func testIgnoresEntriesThatArentHotkeys() {
        let notHotkeys = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>showDocuments</key><true/>
          <key>forcequitKeyword</key><string>kill</string>
        </dict></plist>
        """.utf8)
        XCTAssertTrue(AlfredConfig.decode(notHotkeys, action: "Show Alfred").isEmpty)
        XCTAssertTrue(AlfredConfig.decode(Data("not a plist".utf8), action: "Show Alfred").isEmpty)
    }

    func testFindsNothingWhereAlfredIsntInstalled() {
        let empty = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "no-alfred-here")
        XCTAssertTrue(AlfredConfig.hotkeys(home: empty).isEmpty)
    }

    /// Proves the reader works against the files as they actually exist, and
    /// checks each decoded key against the `string` Alfred wrote beside it.
    /// Skips where Alfred isn't installed.
    func testReadsTheRealHotkeysWhenPresent() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = home.appending(path: AlfredConfig.relativeSupportPath)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: support.path),
                          "Alfred not present on this machine")

        let bindings = AlfredConfig.hotkeys(home: home)
        try XCTSkipIf(bindings.isEmpty, "Alfred is installed but has no hotkey set")

        // Alfred names the key itself, so the decode can be checked against the
        // file rather than against our own reading of it.
        let prefs = support.appending(path: "Alfred.alfredpreferences/preferences")
        var roots = [prefs]
        if let hash = AlfredConfig.localHash(support: support) {
            roots.insert(prefs.appending(path: "local/\(hash)"), at: 0)
        }
        var checked = 0
        for root in roots {
            for file in AlfredConfig.files {
                guard
                    let data = try? Data(contentsOf: root.appending(path: file.path)),
                    let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                for slot in plist.values.compactMap({ $0 as? [String: Any] }) {
                    guard let string = slot["string"] as? String,
                          let decoded = AlfredConfig.decode(data, action: file.action).first
                    else { continue }
                    // `KeyCombo` upper-cases what it's given, so compare in kind.
                    let expected = (string == " " ? "Space" : string).uppercased()
                    XCTAssertEqual(decoded.combo.key, expected,
                                   "decoded \(decoded.combo.key) but Alfred calls it \(expected)")
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "found Alfred hotkeys but none carried a key name to check against")
    }
}
