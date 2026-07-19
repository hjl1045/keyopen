import AppKit
import SwiftUI

/// KeyOpen's hues.
///
/// Deliberately *not* the stock `.green` / `.blue` / `.purple`: those are the
/// system accent colors at full chroma, and against the panel's grey material
/// they read as default rather than chosen. These are the same hue families
/// pulled down in saturation — sage, slate, plum, amber — so the color still
/// classifies a row at a glance without shouting over the text.
///
/// Each is a dynamic `NSColor`, so light and dark each get a value tuned for
/// their own background rather than one compromise between them.
enum Palette {
    // Light values sit a step up from where they started: the first pass traded
    // saturation for darkness, which reads as heavy rather than restrained on a
    // pale panel. Green got the largest lift — deep greens go muddy fastest —
    // and the others follow far enough to keep the family even.
    //
    /// Free to take.
    static let free = adaptive(light: 0x4C8666, dark: 0x8CBFA3)
    /// macOS owns it.
    static let system = adaptive(light: 0x517A9C, dark: 0x93B4CE)
    /// Another app claims it.
    static let otherApps = adaptive(light: 0x7B6994, dark: 0xB2A2C7)
    /// Conflicts and caveats. Kept a touch warmer and stronger than the rest —
    /// it's the only hue that means "something is wrong here".
    static let warning = adaptive(light: 0xA96D3E, dark: 0xD8A87A)
    /// This app's own menu commands: the longest and least actionable list, so
    /// it stays neutral instead of competing with the rest.
    static let thisApp = Color.secondary

    /// Weight for the rail beside a group. Muted hues need slightly more
    /// presence than saturated ones to register at 2pt.
    static let railOpacity: Double = 0.5

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
