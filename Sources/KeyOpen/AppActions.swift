import AppKit
import KeyOpenCore
import ServiceManagement
import SwiftUI

/// Everything the panel's ⋯ menu can do, plus the crash check at launch.
@MainActor
final class AppActions: ObservableObject {
    let updates = UpdateChecker()
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Hides the hotkey panel before a window opens: it floats, and would sit
    /// on top of the window the user just asked for.
    var dismissPanel: () -> Void = {}

    private var windows: [String: NSWindow] = [:]

    func showAbout() {
        updates.check()
        present("about", AboutView(onFeedback: { [weak self] in self?.showFeedback() })
            .environmentObject(updates))
    }

    func showFeedback() {
        present("feedback", FeedbackView(onDone: { [weak self] in self?.close("feedback") }))
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("KeyOpen: launch at login \(on ? "register" : "unregister") failed: \(error)")
        }
        // macOS may hold the item for approval rather than enable it outright.
        if on && SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Crash reports

    private static let lastCrashCheckKey = "lastCrashReportCheck"

    /// Offers to send the newest crash report macOS wrote since the last launch.
    func offerCrashReportIfAny() {
        let defaults = UserDefaults.standard
        let now = Date()
        defer { defaults.set(now, forKey: Self.lastCrashCheckKey) }
        // First launch: crashes from before this feature existed aren't news.
        guard let since = defaults.object(forKey: Self.lastCrashCheckKey) as? Date else { return }

        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: CrashReports.relativeDirectory)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let entries = urls.compactMap { url -> CrashReports.Entry? in
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { return nil }
            return CrashReports.Entry(name: url.lastPathComponent, modified: modified)
        }
        let process = ProcessInfo.processInfo.processName
        guard let newest = CrashReports.new(in: entries, processName: process, since: since).first
        else { return }
        let report = directory.appending(path: newest.name)
        present("crash", CrashReportView(report: report, onDone: { [weak self] in self?.close("crash") }))
    }

    // MARK: Windows

    private func present<Content: View>(_ key: String, _ view: Content) {
        dismissPanel()
        let window = windows[key] ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.styleMask = [.titled, .closable]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            windows[key] = window
            return window
        }()
        // A menu-bar app isn't active by default; without this the window
        // opens behind whatever the user was in.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close(_ key: String) {
        windows[key]?.close()
        // Rebuilt next time, so a sent message doesn't reappear.
        windows[key] = nil
    }
}
