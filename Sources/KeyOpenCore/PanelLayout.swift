import Foundation

/// Height arithmetic for the scrolling list.
///
/// This lives here, away from the view, because it once got this wrong in a way
/// tests could have caught: a `ScrollView`'s *ideal* height is zero, so giving it
/// only a `maxHeight` collapsed it to nothing and clipped every section out of
/// existence. The list's height must therefore be computed from the rows about
/// to be drawn — and must never, for any input, come out near zero.
public enum PanelLayout {
    public static let rowHeight: CGFloat = 19
    public static let sectionHeaderHeight: CGFloat = 20
    /// A conflict adds an explanatory line under its row.
    public static let conflictNoteHeight: CGFloat = 26
    /// "In use" / "Open slots" titles.
    public static let titleHeight: CGFloat = 24

    /// Never let the list collapse, however little there is to show.
    public static let minListHeight: CGFloat = 60
    /// Beyond this the list scrolls instead of growing.
    public static let maxListHeight: CGFloat = 420

    public struct SectionMetrics: Sendable {
        public let rows: Int
        public let expanded: Bool
        public let conflicts: Int

        public init(rows: Int, expanded: Bool, conflicts: Int) {
            self.rows = rows
            self.expanded = expanded
            self.conflicts = conflicts
        }
    }

    /// Deliberately approximate: whatever this under-counts simply scrolls,
    /// which is what the ScrollView is there for. Over-counting is capped.
    /// - Parameter caveatedRecommendations: open slots carrying an inline
    ///   "already bound" note, which costs an extra line each.
    public static func listHeight(sections: [SectionMetrics],
                                  recommendations: Int,
                                  caveatedRecommendations: Int = 0) -> CGFloat {
        var height = titleHeight // "In use"
        for section in sections {
            height += sectionHeaderHeight
            guard section.expanded else { continue } // a folded section costs only its header
            height += CGFloat(section.rows) * rowHeight
            height += CGFloat(section.conflicts) * conflictNoteHeight
        }
        height += titleHeight + CGFloat(recommendations) * rowHeight // "Open slots"
        height += CGFloat(caveatedRecommendations) * conflictNoteHeight
        return min(max(height, minListHeight), maxListHeight)
    }
}
