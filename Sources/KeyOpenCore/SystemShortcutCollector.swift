import Foundation

public enum SymbolicHotkeyParser {
    /// Names for the ids we can tie to a setting: Apple's "Mac keyboard
    /// shortcuts" (support.apple.com/102650) for the keys, a published id list
    /// (gist.github.com/mattrighetti/24b02c00c8a3a53966bc04f7305f99aa) for the
    /// ids, and real plists for the newer ids that list lacks (98, 184, 190).
    /// Unknown ids fall back to a generic name.
    static let names: [Int: String] = [
        7:   "Move focus to the menu bar",
        8:   "Move focus to the Dock",
        9:   "Move focus to the active or next window",
        10:  "Move focus to the window toolbar",
        11:  "Move focus to the floating window",
        12:  "Turn keyboard access on or off",
        13:  "Change the way Tab moves focus",
        15:  "Turn zoom on or off",
        17:  "Zoom in",
        19:  "Zoom out",
        27:  "Move focus to next window in application",
        28:  "Save picture of screen as a file",
        29:  "Copy picture of screen to the clipboard",
        30:  "Save picture of selected area as a file",
        31:  "Copy picture of selected area to the clipboard",
        32:  "Mission Control",
        33:  "Application windows",
        36:  "Show Desktop",
        52:  "Turn Dock hiding on or off",
        57:  "Move focus to the status menus",
        59:  "Turn VoiceOver on or off",
        60:  "Select the previous input source",
        61:  "Select the next source in the Input menu",
        64:  "Spotlight – Show search field",
        65:  "Spotlight – Show Finder search window",
        79:  "Move left a space",
        81:  "Move right a space",
        98:  "Show Help menu",
        118: "Switch to Desktop 1",
        119: "Switch to Desktop 2",
        120: "Switch to Desktop 3",
        121: "Switch to Desktop 4",
        163: "Show Notification Center",
        184: "Screenshot and recording options",
        190: "Quick Note",
        222: "Show Today / Notification Center",
    ]

    /// Shortcuts macOS turns on out of the box. It writes an entry to the plist
    /// only once you change that shortcut, so a Mac where nobody touched the
    /// screenshot keys has no entry for them, and reading the plist alone
    /// offered ⇧⌘3 as free. Keys per Apple's "Mac keyboard shortcuts".
    static let defaults: [Int: KeyCombo] = [
        27:  KeyCombo(modifiers: [.command], key: "`"),
        28:  KeyCombo(modifiers: [.shift, .command], key: "3"),
        29:  KeyCombo(modifiers: [.control, .shift, .command], key: "3"),
        30:  KeyCombo(modifiers: [.shift, .command], key: "4"),
        31:  KeyCombo(modifiers: [.control, .shift, .command], key: "4"),
        52:  KeyCombo(modifiers: [.option, .command], key: "D"),
        60:  KeyCombo(modifiers: [.control], key: "Space"),
        61:  KeyCombo(modifiers: [.control, .option], key: "Space"),
        64:  KeyCombo(modifiers: [.command], key: "Space"),
        65:  KeyCombo(modifiers: [.option, .command], key: "Space"),
        98:  KeyCombo(modifiers: [.shift, .command], key: "/"),
        184: KeyCombo(modifiers: [.shift, .command], key: "5"),
        190: KeyCombo(modifiers: [.function], key: "Q"),
    ]

    public static func parse(_ dict: [String: Any]) -> [Binding] {
        var combos: [Int: KeyCombo] = [:]
        for (id, combo) in defaults where dict[String(id)] == nil {
            combos[id] = combo
        }
        for (idString, raw) in dict {
            guard
                let id = Int(idString),
                let entry = raw as? [String: Any],
                (entry["enabled"] as? Bool) == true
            else { continue }

            // Enabled with no keys stored means the default keys.
            guard let value = entry["value"] as? [String: Any],
                  let rawParams = value["parameters"] as? [Any]
            else {
                combos[id] = defaults[id]
                continue
            }

            let params = rawParams.compactMap { ($0 as? NSNumber)?.intValue }
            guard params.count >= 3, let key = keyString(fromASCII: params[0]) else { continue }
            // Key codes 54–63 are modifier keys themselves (55 is ⌘). Siri's
            // newer shortcut is stored that way, with a Space character that
            // read as ⌘Space; the gesture isn't a key combo at all.
            guard !(54...63).contains(params[1]) else { continue }
            combos[id] = KeyCombo(modifiers: modifiers(fromCocoaMask: params[2]), key: key)
        }
        return combos
            .map { id, combo in Binding(combo: combo, action: names[id] ?? "System hotkey #\(id)", source: .system) }
            .sorted { $0.action < $1.action }
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
        if mask & (1 << 23) != 0 { mods.insert(.function) } // Globe (fn)
        return mods
    }
}

public struct SystemShortcutCollector: ShortcutCollector {
    // Parse at init so the stored state is Sendable-clean ([Binding], not [String: Any]).
    private let bindings: [Binding]

    public init(rawHotkeys: [String: Any]) {
        self.bindings = SymbolicHotkeyParser.parse(rawHotkeys)
    }

    public init(store: PreferenceStore = .userDefaults) {
        let domain = store.domain("com.apple.symbolichotkeys")
        let raw = (domain?["AppleSymbolicHotKeys"] as? [String: Any]) ?? [:]
        self.bindings = SymbolicHotkeyParser.parse(raw)
    }

    public func collect() -> [Binding] {
        bindings
    }
}
