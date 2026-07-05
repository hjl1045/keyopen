import AppKit
import Combine

@MainActor
final class FrontmostTracker: ObservableObject {
    @Published var lastActiveApp: NSRunningApplication?

    init() {
        lastActiveApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        // Ignore ourselves so opening the menu doesn't overwrite the real target.
        if app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = app
        }
    }
}
