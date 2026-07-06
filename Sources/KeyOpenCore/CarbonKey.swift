/// Maps Carbon virtual key codes / modifier masks (as stored by the
/// `KeyboardShortcuts` library) to KeyOpen's model.
public enum CarbonKey {
    private static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(forCarbonKeyCode code: Int) -> String? {
        names[code]
    }

    public static func modifiers(fromCarbonMask mask: Int) -> Set<Modifier> {
        var mods: Set<Modifier> = []
        if mask & 0x200  != 0 { mods.insert(.shift) }   // shiftKey   512
        if mask & 0x800  != 0 { mods.insert(.option) }  // optionKey  2048
        if mask & 0x1000 != 0 { mods.insert(.control) } // controlKey 4096
        if mask & 0x100  != 0 { mods.insert(.command) } // cmdKey     256
        return mods
    }
}
