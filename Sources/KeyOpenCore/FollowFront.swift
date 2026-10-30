/// When the panel should re-read for the app in front without waiting for ↻.
/// The hotkey panel floats, so it stays on screen while you switch apps, and
/// it kept showing the app you summoned it over.
public enum FollowFront {
    /// Rescan only while the panel is on screen (a hidden one would read every
    /// app you switch to for nobody) and only for a different app than the one
    /// shown (re-reading the same app is what ↻ is for).
    public static func shouldRescan(panelVisible: Bool, front: Int32?, shown: Int32?) -> Bool {
        panelVisible && front != nil && front != shown
    }
}
