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
    private let runningBundleIDs: Set<String>
    private let home: URL

    public init(runningBundleIDs: Set<String>,
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.runningBundleIDs = runningBundleIDs
        self.home = home
    }

    public func collect() -> [Binding] {
        // Like other global hotkeys, these are only live while their app runs.
        guard runningBundleIDs.contains(WisprFlowConfig.bundleID) else { return [] }
        let url = home.appending(path: WisprFlowConfig.relativeConfigPath)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return WisprFlowConfig.decode(data)
    }
}

/// Reads Wispr Flow's `config.json`.
///
/// Shortcuts live under `prefs.user.shortcuts` as `"32+55+56": "popo"` — the key
/// is a `+`-joined list of macOS virtual key codes with the modifiers included as
/// codes of their own (55 = Command, 56 = Shift, 32 = U, so that entry is ⇧⌘U),
/// and the value is Wispr Flow's internal action id.
public enum WisprFlowConfig {
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
                           action: "\(appName) · \(label(for: action))",
                           source: .globalHotkey)
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
