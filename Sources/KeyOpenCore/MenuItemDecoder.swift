public enum MenuItemDecoder {
    public static func decode(cmdChar: String?, cmdModifiers: Int, cmdGlyph: Int?) -> KeyCombo? {
        guard let cmdChar, !cmdChar.isEmpty else { return nil }

        var mods: Set<Modifier> = []
        if cmdModifiers & 1 != 0 { mods.insert(.shift) }
        if cmdModifiers & 2 != 0 { mods.insert(.option) }
        if cmdModifiers & 4 != 0 { mods.insert(.control) }
        if cmdModifiers & 8 == 0 { mods.insert(.command) } // Command implied unless bit3 set.

        return KeyCombo(modifiers: mods, key: cmdChar.uppercased())
    }
}
