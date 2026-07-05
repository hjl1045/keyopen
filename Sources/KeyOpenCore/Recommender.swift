import Foundation

public enum CandidateSpace {
    /// Ordered best → worst by ergonomics. Single-⌘ is intentionally absent
    /// (all single-⌘ combos are treated as reserved by omission).
    public static let modifierSets: [Set<Modifier>] = [
        [.command, .shift],
        [.command, .option],
        [.command, .control],
        [.control, .option],
        [.command, .option, .shift],
        [.command, .control, .shift],
        [.control, .option, .command],
    ]

    public static let keys: [String] = {
        let letters = (65...90).compactMap { UnicodeScalar($0).map { String($0) } } // A–Z
        let digits = (0...9).map(String.init)
        return letters + digits
    }()

    public static let all: [KeyCombo] = {
        var combos: [KeyCombo] = []
        for mods in modifierSets {
            for key in keys {
                combos.append(KeyCombo(modifiers: mods, key: key))
            }
        }
        return combos
    }()
}

public enum ReservedCombos {
    /// Conventional multi-modifier combos that are near-universal even when a
    /// given app's menu doesn't list them. Tunable by feel.
    public static let all: Set<KeyCombo> = [
        KeyCombo(modifiers: [.command, .shift], key: "Z"), // Redo
        KeyCombo(modifiers: [.command, .shift], key: "N"), // New window / folder
        KeyCombo(modifiers: [.command, .shift], key: "T"), // Reopen closed tab
        KeyCombo(modifiers: [.command, .shift], key: "P"), // Private / print variants
        KeyCombo(modifiers: [.command, .shift], key: "G"), // Find previous
        KeyCombo(modifiers: [.command, .shift], key: "A"), // Deselect all
        KeyCombo(modifiers: [.command, .option], key: "W"), // Close all
        KeyCombo(modifiers: [.command, .option], key: "M"), // Minimize all
        KeyCombo(modifiers: [.command, .option], key: "D"), // Toggle Dock
    ]
}

public enum Scoring {
    private static let easyKeys: Set<String> = ["A", "S", "D", "F", "J", "K", "L", "E", "R", "W", "Q"]

    public static func score(_ combo: KeyCombo) -> Double {
        let count = CandidateSpace.modifierSets.count
        let rank = CandidateSpace.modifierSets.firstIndex(of: combo.modifiers) ?? count
        let modifierScore = Double((count - rank) * 10)

        let isLetter = combo.key.count == 1 && combo.key >= "A" && combo.key <= "Z"
        let keyScore: Double = easyKeys.contains(combo.key) ? 5 : (isLetter ? 2 : 0)

        return modifierScore + keyScore
    }
}

/// A recommended combo, plus any simpler shortcuts already bound on the same key.
public struct Recommendation: Sendable, Hashable {
    public let combo: KeyCombo
    /// Combos already in use on the same key with a strict-subset of this combo's
    /// modifiers (e.g. `⌘D` for a `⇧⌘D` suggestion). Non-empty = "usable, but it
    /// stacks a modifier onto a key that already means something."
    public let overlaps: [KeyCombo]

    public init(combo: KeyCombo, overlaps: [KeyCombo]) {
        self.combo = combo
        self.overlaps = overlaps
    }
}

public struct Recommender {
    private let candidates: [KeyCombo]
    private let reserved: Set<KeyCombo>

    public init(candidates: [KeyCombo] = CandidateSpace.all,
                reserved: Set<KeyCombo> = ReservedCombos.all) {
        self.candidates = candidates
        self.reserved = reserved
    }

    public func recommend(from map: ShortcutMap, limit: Int = 8) -> [Recommendation] {
        let inUse = map.takenCombos()             // real bindings (system + app)
        let blocked = inUse.union(reserved)       // never suggest these exact combos

        let free = candidates.enumerated().filter { !blocked.contains($0.element) }
        let scored = free.map { pair -> (offset: Int, rec: Recommendation, score: Double) in
            let overlaps = simplerFormsInUse(of: pair.element, among: inUse)
            // Down-rank (not exclude) combos whose simpler form on the same key is used.
            let penalty: Double = overlaps.isEmpty ? 0 : 1000
            let score = Scoring.score(pair.element) - penalty
            return (pair.offset, Recommendation(combo: pair.element, overlaps: overlaps), score)
        }

        let ranked = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.offset < b.offset // stable: preserve ergonomic candidate order on ties
        }
        return ranked.prefix(limit).map(\.rec)
    }

    private func simplerFormsInUse(of combo: KeyCombo, among inUse: Set<KeyCombo>) -> [KeyCombo] {
        inUse
            .filter { $0.key == combo.key && $0.modifiers.isStrictSubset(of: combo.modifiers) }
            .sorted { $0.displayString < $1.displayString }
    }
}
