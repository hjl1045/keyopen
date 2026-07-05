import Foundation

public enum SymbolicHotkeyParser {
    /// A small curated map of well-known hotkey ids. Unknown ids fall back
    /// to a generic name — the parsing logic is what matters, not exhaustiveness.
    static let names: [Int: String] = [
        32: "Mission Control",
        34: "Mission Control – Application windows",
        64: "Spotlight – Show search field",
        65: "Spotlight – Show Finder search window",
        79: "Move left a space",
        81: "Move right a space",
    ]

    public static func parse(_ dict: [String: Any]) -> [Binding] {
        var out: [Binding] = []
        for (idString, raw) in dict {
            guard
                let id = Int(idString),
                let entry = raw as? [String: Any],
                (entry["enabled"] as? Bool) == true,
                let value = entry["value"] as? [String: Any],
                let rawParams = value["parameters"] as? [Any]
            else { continue }

            let params = rawParams.compactMap { ($0 as? NSNumber)?.intValue }
            guard params.count >= 3, let key = keyString(fromASCII: params[0]) else { continue }

            let combo = KeyCombo(modifiers: modifiers(fromCocoaMask: params[2]), key: key)
            let name = names[id] ?? "System hotkey #\(id)"
            out.append(Binding(combo: combo, action: name, source: .system))
        }
        return out.sorted { $0.action < $1.action }
    }

    static func keyString(fromASCII ascii: Int) -> String? {
        if ascii == 32 { return "Space" }
        guard ascii >= 33, ascii <= 126, let scalar = UnicodeScalar(ascii) else { return nil }
        return String(scalar).uppercased()
    }

    static func modifiers(fromCocoaMask mask: Int) -> Set<Modifier> {
        var mods: Set<Modifier> = []
        if mask & (1 << 17) != 0 { mods.insert(.shift) }
        if mask & (1 << 18) != 0 { mods.insert(.control) }
        if mask & (1 << 19) != 0 { mods.insert(.option) }
        if mask & (1 << 20) != 0 { mods.insert(.command) }
        return mods
    }
}

public struct SystemShortcutCollector: ShortcutCollector {
    // Parse at init so the stored state is Sendable-clean ([Binding], not [String: Any]).
    private let bindings: [Binding]

    public init(rawHotkeys: [String: Any]) {
        self.bindings = SymbolicHotkeyParser.parse(rawHotkeys)
    }

    public init() {
        let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")
        let raw = (domain?["AppleSymbolicHotKeys"] as? [String: Any]) ?? [:]
        self.bindings = SymbolicHotkeyParser.parse(raw)
    }

    public func collect() -> [Binding] {
        bindings
    }
}
