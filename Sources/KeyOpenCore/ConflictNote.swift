/// Explains a conflict in the one line the panel has room for.
///
/// A ⚠︎ on its own tells you there's a problem but not what to do about it. Two
/// bindings on one combo are rarely equal partners — a global hotkey is dispatched
/// before the frontmost app sees the key, so the app's menu command simply never
/// fires. Which one loses is the actionable part.
public enum ConflictNote {
    /// - Parameters:
    ///   - binding: the row being drawn.
    ///   - rivals: other bindings claiming the same combo.
    ///   - appName: the inspected app's name, used to name its menu commands —
    ///     those carry no `owner`, since the section header normally says it.
    public static func text(for binding: Binding,
                            rivals: [Binding],
                            appName: String? = nil) -> String? {
        guard let rival = rivals.first else { return nil }
        let alsoMore = rivals.count > 1 ? " (+\(rivals.count - 1) more)" : ""
        let rivalName = name(of: rival, appName: appName)

        switch (binding.source, rival.source) {
        case (.appMenu, .globalHotkey):
            return "Blocked by \(rivalName) · \(rival.action) — a global hotkey fires first\(alsoMore)"
        case (.globalHotkey, .appMenu):
            return "Blocks \(rivalName)'s \(rival.action)\(alsoMore)"
        case (_, .system):
            return "macOS uses this for \(rival.action)\(alsoMore)"
        default:
            return "Also claimed by \(rivalName) · \(rival.action)\(alsoMore)"
        }
    }

    private static func name(of binding: Binding, appName: String?) -> String {
        if let owner = binding.owner { return owner.name }
        switch binding.source {
        case .system: return "macOS"
        case .appMenu: return appName ?? "this app"
        case .globalHotkey: return "another app"
        }
    }
}
