public struct ScanResult: Sendable {
    public let systemBindings: [Binding]
    public let appBindings: [Binding]
    public let globalBindings: [Binding]
    public let conflicts: [(combo: KeyCombo, bindings: [Binding])]
    public let recommendations: [Recommendation]
}

public enum ScanEngine {
    public static func run(system: ShortcutCollector,
                           app: ShortcutCollector?,
                           globals: ShortcutCollector? = nil,
                           recommender: Recommender = Recommender()) -> ScanResult {
        let systemBindings = deduplicated(system.collect())
        let appBindings = deduplicated(app?.collect() ?? [])
        let globalBindings = deduplicated(globals?.collect() ?? [])

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

        init(_ binding: Binding) {
            combo = binding.combo
            source = binding.source
            action = binding.action
                .replacingOccurrences(of: "…", with: "")
                .replacingOccurrences(of: "...", with: "")
                .lowercased()
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }
    }
}
