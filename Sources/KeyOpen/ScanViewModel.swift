import AppKit
import ApplicationServices
import KeyOpenCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var appName: String?
    @Published var accessibilityGranted = true
    @Published var isScanning = false
    /// When the displayed result was produced. A rescan of an unchanged app
    /// looks identical, so this is what tells you the refresh actually ran.
    @Published var lastScanned: Date?

    /// Identifies the newest scan, so a slow earlier one can't overwrite it.
    /// Clicks are never dropped while a scan is in flight — that would look
    /// exactly like the button doing nothing.
    private var generation = 0

    func scan(target: NSRunningApplication?) {
        generation += 1
        let generation = self.generation
        isScanning = true
        let granted = AXIsProcessTrusted()
        accessibilityGranted = granted
        appName = target?.localizedName
        let pid = target?.processIdentifier
        let runningApps = collectRunningApps()

        Task.detached {
            let system = SystemShortcutCollector()
            let app: ShortcutCollector? = (granted && pid != nil) ? AppMenuCollector(pid: pid!) : nil
            let globals = MergedCollector([
                GlobalHotkeyCollector(apps: runningApps),
                // Apps that keep hotkeys in their own config rather than in
                // macOS preferences — otherwise they'd be offered as free slots.
                AppConfigHotkeyCollector(runningBundleIDs: Set(runningApps.map(\.bundleID))),
            ])
            let scan = ScanEngine.run(system: system, app: app, globals: globals)
            await MainActor.run {
                guard generation == self.generation else { return } // superseded
                self.result = scan
                self.lastScanned = Date()
                self.isScanning = false
            }
        }
    }

    /// Every distinct running app (except us) — global hotkeys are only live
    /// while their owning app is running.
    private func collectRunningApps() -> [GlobalHotkeyCollector.App] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bid = app.bundleIdentifier,
                  bid != Bundle.main.bundleIdentifier,
                  let name = app.localizedName,
                  !seen.contains(bid)
            else { return nil }
            seen.insert(bid)
            return GlobalHotkeyCollector.App(bundleID: bid, name: name)
        }
    }
}
