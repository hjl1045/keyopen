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
        let systemBindings = system.collect()
        let appBindings = app?.collect() ?? []
        let globalBindings = globals?.collect() ?? []

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
}
