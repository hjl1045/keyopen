import Foundation

public enum Modifier: String, Hashable, CaseIterable, Sendable {
    case control, option, shift, command

    public var glyph: String {
        switch self {
        case .control: return "⌃"
        case .option:  return "⌥"
        case .shift:   return "⇧"
        case .command: return "⌘"
        }
    }

    /// Canonical macOS display order: Control, Option, Shift, Command.
    var order: Int {
        switch self {
        case .control: return 0
        case .option:  return 1
        case .shift:   return 2
        case .command: return 3
        }
    }
}

public struct KeyCombo: Hashable, Sendable {
    public let modifiers: Set<Modifier>
    public let key: String

    public init(modifiers: Set<Modifier>, key: String) {
        self.modifiers = modifiers
        self.key = key.uppercased()
    }

    public var displayString: String {
        let mods = modifiers.sorted { $0.order < $1.order }.map(\.glyph).joined()
        return mods + key
    }
}

public enum Source: Hashable, Sendable {
    case system
    case appMenu
    /// A global hotkey another running app registered, recovered from its
    /// preferences (e.g. apps using the `KeyboardShortcuts` library).
    case globalHotkey
}

public struct Binding: Hashable, Sendable {
    public let combo: KeyCombo
    public let action: String
    public let source: Source

    public init(combo: KeyCombo, action: String, source: Source) {
        self.combo = combo
        self.action = action
        self.source = source
    }
}
