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
        let root = ScrollView { MenuContentView().environmentObject(tracker) }
            .frame(width: 340, height: 520)
        let hosting = NSHostingView(rootView: root)

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 340, height: 520))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}
