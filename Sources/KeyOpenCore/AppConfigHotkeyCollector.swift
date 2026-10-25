import Foundation

/// Global hotkeys that never touch macOS preferences.
///
/// macOS offers no way to enumerate the hotkeys apps have registered, so KeyOpen
/// recovers them from wherever each app happens to keep them. `GlobalHotkeyCollector`
/// covers Swift apps using the `KeyboardShortcuts` library; this covers apps that
/// store their own config file — Electron apps in particular, which register
/// through Electron's `globalShortcut` and persist to JSON.
///
/// Every such app needs its own reader: there is no shared format. That's tedious,
/// but missing one is not a cosmetic gap — an unseen hotkey gets recommended as a
/// *free slot*, which is the one answer KeyOpen must not get wrong.
public struct AppConfigHotkeyCollector: ShortcutCollector {
    /// One entry per app whose format we've confirmed against a real file.
    static let configs: [any AppHotkeyConfig.Type] = [
        WisprFlowConfig.self,
        KeyboardMaestroConfig.self,
        AlfredConfig.self,
    ]

    /// The apps we have a reader for, for the About window.
    public static var readerNames: [String] { configs.map { $0.appName } }

    private let runningBundleIDs: Set<String>
    private let home: URL

    public init(runningBundleIDs: Set<String>,
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.runningBundleIDs = runningBundleIDs
        self.home = home
    }

    public func collect() -> [Binding] {
        // Like other global hotkeys, these are only live while their app runs.
        Self.configs
            .filter { runningBundleIDs.contains($0.bundleID) }
            .flatMap { $0.hotkeys(home: home) }
    }
}

/// One app's hotkey config. Reading it is the whole job; where it lives and how
/// it's encoded is the reader's business, since no two of these agree.
public protocol AppHotkeyConfig {
    /// The bundle id of the process that *registers* the hotkeys — not always
    /// the app you'd name (Keyboard Maestro registers from its engine agent).
    static var bundleID: String { get }
    static var appName: String { get }
    static func hotkeys(home: URL) -> [Binding]
}

/// The usual case: everything in one file at a fixed path.
public protocol SingleFileHotkeyConfig: AppHotkeyConfig {
    static var relativeConfigPath: String { get }
    static func decode(_ data: Data) -> [Binding]
}

extension SingleFileHotkeyConfig {
    public static func hotkeys(home: URL) -> [Binding] {
        guard let data = try? Data(contentsOf: home.appending(path: relativeConfigPath)) else { return [] }
        return decode(data)
    }
}

/// Reads Wispr Flow's `config.json`.
///
/// Shortcuts live under `prefs.user.shortcuts` as `"32+55+56": "popo"` — the key
/// is a `+`-joined list of macOS virtual key codes with the modifiers included as
/// codes of their own (55 = Command, 56 = Shift, 32 = U, so that entry is ⇧⌘U),
/// and the value is Wispr Flow's internal action id.
public enum WisprFlowConfig: SingleFileHotkeyConfig {
    public static let bundleID = "com.electron.wispr-flow"
    public static let appName = "Wispr Flow"
    public static let relativeConfigPath = "Library/Application Support/Wispr Flow/config.json"

    public static func decode(_ data: Data) -> [Binding] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let prefs = root["prefs"] as? [String: Any],
            let user = prefs["user"] as? [String: Any],
            let shortcuts = user["shortcuts"] as? [String: Any]
        else { return [] }

        return shortcuts.compactMap { encoded, action in
            let codes = encoded.split(separator: "+").compactMap { Int($0) }
            guard codes.count == encoded.split(separator: "+").count,
                  let combo = combo(fromKeyCodes: codes),
                  let action = action as? String
            else { return nil }
            return Binding(combo: combo,
                           action: label(for: action),
                           source: .globalHotkey,
                           owner: Owner(bundleID: bundleID, name: appName))
        }
        .sorted { $0.combo.displayString < $1.combo.displayString }
    }

    /// Modifiers arrive as key codes rather than a mask, so they're separated by
    /// value. A chord of modifiers alone is legitimate here — Wispr Flow's "lens"
    /// is a held ⌃⌥⌘ — and keeps its empty key.
    ///
    /// Returns nil for anything we can't name confidently: a bare key with no
    /// modifier (plain Escape), more than one non-modifier key, or a code outside
    /// the standard set (the config also holds synthetic ids like `4098` for
    /// things such as double-tapped modifiers).
    static func combo(fromKeyCodes codes: [Int]) -> KeyCombo? {
        var modifiers: Set<Modifier> = []
        var keys: [String] = []
        for code in codes {
            switch code {
            case 54, 55: modifiers.insert(.command)
            case 56, 60: modifiers.insert(.shift)
            case 58, 61: modifiers.insert(.option)
            case 59, 62: modifiers.insert(.control)
            default:
                guard let name = CarbonKey.name(forCarbonKeyCode: code) else { return nil }
                keys.append(name)
            }
        }
        guard keys.count <= 1, !modifiers.isEmpty else { return nil }
        return KeyCombo(modifiers: modifiers, key: keys.first ?? "")
    }

    /// Wispr Flow's action ids are internal shorthand; name the ones we know and
    /// fall back to un-snake-casing the rest.
    static func label(for action: String) -> String {
        let known = [
            "popo": "Toggle dictation (hands-free)",
            "ptt": "Push to talk",
            "lens": "Lens",
            "dismiss": "Dismiss",
            "undo": "Undo",
            "paste_event": "Paste",
            "paste_last_text": "Paste last text",
            "copy_last_text": "Copy last text",
            "open_scratchpad": "Open scratchpad",
        ]
        if let name = known[action] { return name }
        let words = action.split(separator: "_").joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

/// Reads Keyboard Maestro's macro library.
///
/// Hot key triggers sit at `MacroGroups[].Macros[].Triggers[]` where
/// `MacroTriggerType` is `"HotKey"`, encoded as a Carbon key code plus a Carbon
/// modifier mask: `{"KeyCode": 18, "Modifiers": 6400}` is ⌃⌥⌘1.
///
/// Confirmed against this Mac's library by diffing the decode against what the
/// engine itself reports (`tell application "Keyboard Maestro Engine" to
/// getmacros with asstring` renders each trigger as "The Hot Key ⌃⌥⌘1 is
/// pressed") — all 13 hot keys matched, including the ⌥⇧⌘C and ⌥V ones that
/// exercise the mask separately from the key.
///
/// Hotkeys in an app-specific macro group are kept rather than filtered out: a
/// slot that's taken whenever that app is frontmost is not a free slot.
public enum KeyboardMaestroConfig: SingleFileHotkeyConfig {
    /// The engine, not the editor. The engine is a background agent that
    /// registers the hotkeys and normally runs with the editor closed.
    public static let bundleID = "com.stairways.keyboardmaestro.engine"
    public static let appName = "Keyboard Maestro"
    public static let relativeConfigPath =
        "Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist"

    public static func decode(_ data: Data) -> [Binding] {
        guard
            let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let groups = root["MacroGroups"] as? [[String: Any]]
        else { return [] }

        var out: [Binding] = []
        for group in groups where isActive(group) {
            for macro in (group["Macros"] as? [[String: Any]]) ?? [] where isActive(macro) {
                guard let name = macro["Name"] as? String else { continue }
                for trigger in (macro["Triggers"] as? [[String: Any]]) ?? [] {
                    guard trigger["MacroTriggerType"] as? String == "HotKey",
                          let combo = combo(from: trigger)
                    else { continue }
                    out.append(Binding(combo: combo,
                                       action: name,
                                       source: .globalHotkey,
                                       owner: Owner(bundleID: bundleID, name: appName)))
                }
            }
        }
        return out.sorted { $0.combo.displayString < $1.combo.displayString }
    }

    /// `IsActive` is written only when a group or macro is switched off, and a
    /// switched-off macro's hotkey isn't registered. Absent means on.
    static func isActive(_ item: [String: Any]) -> Bool {
        (item["IsActive"] as? Bool) ?? true
    }

    /// Returns nil for a trigger with no key we can name — including Keyboard
    /// Maestro's 32767 sentinel for "no key set", which is what a modifier-only
    /// or unassigned trigger stores.
    static func combo(from trigger: [String: Any]) -> KeyCombo? {
        guard let code = (trigger["KeyCode"] as? NSNumber)?.intValue,
              let key = CarbonKey.name(forCarbonKeyCode: code)
        else { return nil }
        let mask = (trigger["Modifiers"] as? NSNumber)?.intValue ?? 0
        return KeyCombo(modifiers: CarbonKey.modifiers(fromCarbonMask: mask), key: key)
    }
}

/// Reads Alfred's hotkeys.
///
/// Alfred keeps hotkeys per-machine: `prefs.json` holds a `localhash`, and this
/// Mac's prefs live under `Alfred.alfredpreferences/preferences/local/<hash>/`.
/// Each hotkey is a plist entry of `{"key": <Carbon key code>, "mod": <Cocoa
/// modifier mask>, "string": "V"}` — note `mod` is the `NSEvent` mask macOS
/// itself uses in `com.apple.symbolichotkeys`, not the Carbon one.
///
/// Confirmed against this Mac: the main hotkey decodes to ⌘Space, and
/// `com.apple.symbolichotkeys` shows Spotlight's ⌘Space (id 64) switched off —
/// which is the trade you make to give Alfred that key. The `string` field
/// independently names the key, so a decode can be checked against the file.
///
/// Unlike the others this needs several files: which hotkey a file holds is
/// only knowable from its path, so the paths carry the labels.
public enum AlfredConfig: AppHotkeyConfig {
    public static let bundleID = "com.runningwithcrayons.Alfred"
    public static let appName = "Alfred"
    static let relativeSupportPath = "Library/Application Support/Alfred"

    /// Hotkey files under the preferences folder, and what each one triggers.
    static let files: [(path: String, action: String)] = [
        ("hotkey/prefs.plist", "Show Alfred"),
        ("features/clipboard/prefs.plist", "Clipboard history"),
    ]

    public static func hotkeys(home: URL) -> [Binding] {
        let support = home.appending(path: relativeSupportPath)
        let prefs = support.appending(path: "Alfred.alfredpreferences/preferences")
        // The machine-local folder wins; the top-level one is where hotkeys
        // land when Alfred is syncing them between Macs.
        var roots = [prefs]
        if let hash = localHash(support: support) {
            roots.insert(prefs.appending(path: "local/\(hash)"), at: 0)
        }

        var out: [Binding] = []
        var seen: Set<KeyCombo> = []
        for root in roots {
            for file in files {
                guard let data = try? Data(contentsOf: root.appending(path: file.path)) else { continue }
                for binding in decode(data, action: file.action) where seen.insert(binding.combo).inserted {
                    out.append(binding)
                }
            }
        }
        return out.sorted { $0.combo.displayString < $1.combo.displayString }
    }

    static func localHash(support: URL) -> String? {
        guard
            let data = try? Data(contentsOf: support.appending(path: "prefs.json")),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["localhash"] as? String
    }

    /// A hotkey prefs file holds its hotkey under a slot name that varies by
    /// feature (`default` for the main one, `hotkey` for the clipboard viewer),
    /// so the values are read rather than any particular key. Entries without
    /// both `key` and `mod` aren't hotkeys — Alfred simply omits the entry for
    /// a feature whose hotkey is unset.
    static func decode(_ data: Data, action: String) -> [Binding] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }

        return root.values.compactMap { slot in
            guard
                let slot = slot as? [String: Any],
                let code = (slot["key"] as? NSNumber)?.intValue,
                let mask = (slot["mod"] as? NSNumber)?.intValue,
                let key = CarbonKey.name(forCarbonKeyCode: code)
            else { return nil }
            // Same encoding as macOS's own symbolic hotkeys, hence the reuse.
            let combo = KeyCombo(modifiers: SymbolicHotkeyParser.modifiers(fromCocoaMask: mask), key: key)
            return Binding(combo: combo,
                           action: action,
                           source: .globalHotkey,
                           owner: Owner(bundleID: bundleID, name: appName))
        }
    }
}

/// Presents several collectors as one, so a scan can merge sources without
/// `ScanEngine` growing a parameter per source.
public struct MergedCollector: ShortcutCollector {
    private let collectors: [ShortcutCollector]

    public init(_ collectors: [ShortcutCollector]) {
        self.collectors = collectors
    }

    public func collect() -> [Binding] {
        collectors.flatMap { $0.collect() }
    }
}
