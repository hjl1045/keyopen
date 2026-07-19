import AppKit
import SwiftUI

/// Shows KeyOpen's panel as a floating window in response to the global hotkey,
/// so it can be summoned from within any app. Rebuilds the content on each show
/// so it re-scans the app you were just using.
@MainActor
final class PanelController {
    private let tracker: FrontmostTracker
    private var panel: NSPanel?

    init(tracker: FrontmostTracker) {
        self.tracker = tracker
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    private func show() {
        // No ScrollView here: the content scrolls its own list and caps its
        // height, so wrapping it would nest two scrollers and let the header
        // scroll away with everything else.
        let root = MenuContentView().environmentObject(tracker)
        let hosting = NSHostingView(rootView: root)

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        // Size to the content so a short list gets a short panel, but clamp:
        // a ScrollView is happy to report almost any height, and neither a
        // sliver nor a full-screen panel is a sane answer.
        let fitted = hosting.fittingSize.height
        panel.setContentSize(NSSize(width: 340, height: min(max(fitted, 220), 620)))
        positionOnActiveScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    /// Center on whichever screen the pointer is on, so multi-display users see it.
    private func positionOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { panel.center(); return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                     y: visible.midY - size.height / 2))
    }

    private func makePanel() -> NSPanel {
        // Deliberately *not* `.fullSizeContentView`: that draws the content
        // under the titlebar, and the titlebar keeps taking the mouse — so the
        // refresh button in the top-right of the header sat in a dead zone and
        // dragged the window instead of firing. Keeping content below the
        // titlebar makes the whole header clickable.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Appear on the current Space, including over fullscreen apps — otherwise
        // the panel can be created "visible" but stranded on another Space.
        // (.canJoinAllSpaces and .moveToActiveSpace are mutually exclusive.)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}
