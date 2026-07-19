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
    /// The command alone, unqualified — "Toggle dictation", not "Wispr Flow ·
    /// Toggle dictation". Who owns it is `owner`, so the UI can name the app
    /// only where that's news to the reader.
    public let action: String
    public let source: Source
    /// The app that registered this, for global hotkeys. `nil` for system
    /// shortcuts and for the menu commands of the app being inspected.
    public let owner: Owner?

    public init(combo: KeyCombo, action: String, source: Source, owner: Owner? = nil) {
        self.combo = combo
        self.action = action
        self.source = source
        self.owner = owner
    }

    /// Prefixed with the owning app, for lists that mix apps together.
    public var qualifiedAction: String {
        guard let owner else { return action }
        return "\(owner.name) · \(action)"
    }
}

public struct Owner: Hashable, Sendable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}
