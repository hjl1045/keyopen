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

public struct Recommender {
    private let candidates: [KeyCombo]
    private let reserved: Set<KeyCombo>

    public init(candidates: [KeyCombo] = CandidateSpace.all,
                reserved: Set<KeyCombo> = ReservedCombos.all) {
        self.candidates = candidates
        self.reserved = reserved
    }

    public func recommend(from map: ShortcutMap, limit: Int = 8) -> [KeyCombo] {
        let taken = map.takenCombos().union(reserved)
        let free = candidates.enumerated().filter { !taken.contains($0.element) }
        let ranked = free.sorted { a, b in
            let sa = Scoring.score(a.element), sb = Scoring.score(b.element)
            if sa != sb { return sa > sb }
            return a.offset < b.offset // stable: preserve ergonomic candidate order on ties
        }
        return ranked.prefix(limit).map(\.element)
    }
}
