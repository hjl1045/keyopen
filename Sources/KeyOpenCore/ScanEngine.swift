public struct ScanResult: Sendable {
    public let systemBindings: [Binding]
    public let appBindings: [Binding]
    public let conflicts: [(combo: KeyCombo, bindings: [Binding])]
    public let recommendations: [Recommendation]
}

public enum ScanEngine {
    public static func run(system: ShortcutCollector,
                           app: ShortcutCollector?,
                           recommender: Recommender = Recommender()) -> ScanResult {
        let systemBindings = system.collect()
        let appBindings = app?.collect() ?? []

        var map = ShortcutMap()
        for b in systemBindings { map.add(b) }
        for b in appBindings { map.add(b) }

        return ScanResult(
            systemBindings: systemBindings.sorted { $0.combo.displayString < $1.combo.displayString },
            appBindings: appBindings.sorted { $0.combo.displayString < $1.combo.displayString },
            conflicts: map.conflicts(),
            recommendations: recommender.recommend(from: map)
        )
    }
}
