import Foundation

public struct ShortcutMap: Sendable {
    public private(set) var bindings: [Binding]

    public init(_ bindings: [Binding] = []) {
        self.bindings = bindings
    }

    public mutating func add(_ b: Binding) {
        bindings.append(b)
    }

    public func isTaken(_ combo: KeyCombo) -> Bool {
        bindings.contains { $0.combo == combo }
    }

    public func takenCombos() -> Set<KeyCombo> {
        Set(bindings.map(\.combo))
    }

    public func conflicts() -> [(combo: KeyCombo, bindings: [Binding])] {
        var byCombo: [KeyCombo: [Binding]] = [:]
        for b in bindings {
            byCombo[b.combo, default: []].append(b)
        }
        return byCombo
            .compactMap { combo, list -> (combo: KeyCombo, bindings: [Binding])? in
                // Distinct bindings only — identical duplicates are not a conflict.
                let distinct = Array(Set(list))
                guard distinct.count > 1 else { return nil }
                return (combo: combo, bindings: list)
            }
            .sorted { $0.combo.displayString < $1.combo.displayString }
    }
}
