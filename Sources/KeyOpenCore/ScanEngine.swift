public struct ScanResult: Sendable {
    public let systemBindings: [Binding]
    public let appBindings: [Binding]
    public let globalBindings: [Binding]
    public let conflicts: [(combo: KeyCombo, bindings: [Binding])]
    public let recommendations: [Recommendation]
}

public enum ScanEngine {
    /// The Apple menu's shortcuts, live in every app (Apple's "Mac keyboard
    /// shortcuts", support.apple.com/102650). The direct edition reads them from
    /// the menu bar; the sandboxed one can't, and offered ⇧⌘Q (Log Out) as free.
    static let appleMenu: [Binding] = [
        Binding(combo: KeyCombo(modifiers: [.shift, .command], key: "Q"), action: "Log Out", source: .system),
        Binding(combo: KeyCombo(modifiers: [.option, .shift, .command], key: "Q"), action: "Log Out without confirming", source: .system),
        Binding(combo: KeyCombo(modifiers: [.control, .command], key: "Q"), action: "Lock Screen", source: .system),
    ]

    /// - Parameter appBundleID: bundle id of the app being inspected. Its *own*
    ///   global hotkeys are listed with its menu commands rather than under
    ///   "other apps" — from where you're sitting, Wispr Flow's ⇧⌘U is Wispr
    ///   Flow's, not some other app's.
    public static func run(system: ShortcutCollector,
                           app: ShortcutCollector?,
                           globals: ShortcutCollector? = nil,
                           appBundleID: String? = nil,
                           recommender: Recommender = Recommender()) -> ScanResult {
        // Without the menu bar, the Apple menu's shortcuts come from our list.
        let systemBindings = deduplicated(system.collect() + (app == nil ? appleMenu : []))
        let allGlobals = deduplicated(globals?.collect() ?? [])
        let (ownGlobals, globalBindings) = allGlobals.partitioned {
            appBundleID != nil && $0.owner?.bundleID == appBundleID
        }
        let appBindings = deduplicated(app?.collect() ?? []) + ownGlobals

        var map = ShortcutMap()
        for b in systemBindings { map.add(b) }
        for b in appBindings { map.add(b) }
        for b in globalBindings { map.add(b) }

        let sortByCombo: (Binding, Binding) -> Bool = { $0.combo.displayString < $1.combo.displayString }
        return ScanResult(
            systemBindings: systemBindings.sorted(by: sortByCombo),
            appBindings: appBindings.sorted(by: sortByCombo),
            globalBindings: globalBindings.sorted(by: sortByCombo),
            conflicts: map.conflicts(),
            recommendations: recommender.recommend(from: map)
        )
    }

    /// One command often surfaces twice in a menu bar — a File-menu "Close window"
    /// and a Window-menu "Close Window" are the same ⌘W, spelled differently. Left
    /// alone they render as two rows that flag each other as a conflict. Collapse
    /// bindings whose combo and action match apart from case, spacing, and a
    /// trailing ellipsis, keeping the first spelling we saw.
    static func deduplicated(_ bindings: [Binding]) -> [Binding] {
        var seen = Set<Identity>()
        return bindings.filter { seen.insert(Identity($0)).inserted }
    }

    private struct Identity: Hashable {
        let combo: KeyCombo
        let action: String
        let source: Source
        let owner: Owner?

        init(_ binding: Binding) {
            combo = binding.combo
            source = binding.source
            owner = binding.owner
            action = binding.action
                .replacingOccurrences(of: "…", with: "")
                .replacingOccurrences(of: "...", with: "")
                .lowercased()
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }
    }
}

private extension Array {
    /// Splits into (matching, rest), preserving order.
    func partitioned(by matches: (Element) -> Bool) -> ([Element], [Element]) {
        var yes: [Element] = []
        var no: [Element] = []
        for element in self {
            if matches(element) { yes.append(element) } else { no.append(element) }
        }
        return (yes, no)
    }
}
