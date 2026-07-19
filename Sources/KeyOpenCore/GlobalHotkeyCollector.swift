import Foundation

/// Recovers global hotkeys that other running apps registered, by reading the
/// values stored by the popular `KeyboardShortcuts` library in each app's
/// preferences. This does NOT cover every app — only those using that library
/// and storing prefs in the standard (non-sandboxed) location — but it recaptures
/// the biggest blind spot, since macOS won't enumerate global hotkeys directly.
public enum KeyboardShortcutsDecoder {
    /// Decodes a `KeyboardShortcuts` value string,
    /// e.g. `{"carbonKeyCode":40,"carbonModifiers":768}` → ⇧⌘K.
    public static func decode(_ jsonString: String) -> KeyCombo? {
        guard
            let data = jsonString.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = (obj["carbonKeyCode"] as? NSNumber)?.intValue,
            let mask = (obj["carbonModifiers"] as? NSNumber)?.intValue,
            let key = CarbonKey.name(forCarbonKeyCode: code)
        else { return nil }
        return KeyCombo(modifiers: CarbonKey.modifiers(fromCarbonMask: mask), key: key)
    }
}

public struct GlobalHotkeyCollector: ShortcutCollector {
    public struct App: Sendable, Hashable {
        public let bundleID: String
        public let name: String
        public init(bundleID: String, name: String) {
            self.bundleID = bundleID
            self.name = name
        }
    }

    private let apps: [App]

    public init(apps: [App]) {
        self.apps = apps
    }

    public func collect() -> [Binding] {
        var out: [Binding] = []
        for app in apps {
            guard let domain = UserDefaults.standard.persistentDomain(forName: app.bundleID) else { continue }
            for (key, value) in domain where key.hasPrefix("KeyboardShortcuts_") {
                guard let str = value as? String, let combo = KeyboardShortcutsDecoder.decode(str) else { continue }
                let name = key.replacingOccurrences(of: "KeyboardShortcuts_", with: "")
                out.append(Binding(combo: combo,
                                   action: humanize(name),
                                   source: .globalHotkey,
                                   owner: Owner(bundleID: app.bundleID, name: app.name)))
            }
        }
        return out
    }

    /// "toggleDictation" -> "Toggle Dictation"
    private func humanize(_ camel: String) -> String {
        var spaced = ""
        for ch in camel {
            if ch.isUppercase && !spaced.isEmpty { spaced.append(" ") }
            spaced.append(ch)
        }
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
