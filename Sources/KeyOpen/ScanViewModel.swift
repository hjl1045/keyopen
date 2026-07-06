import AppKit
import ApplicationServices
import KeyOpenCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var appName: String?
    @Published var accessibilityGranted = true
    @Published var isScanning = false

    func scan(target: NSRunningApplication?) {
        isScanning = true
        let granted = AXIsProcessTrusted()
        accessibilityGranted = granted
        appName = target?.localizedName
        let pid = target?.processIdentifier
        let runningApps = collectRunningApps()

        Task.detached {
            let system = SystemShortcutCollector()
            let app: ShortcutCollector? = (granted && pid != nil) ? AppMenuCollector(pid: pid!) : nil
            let globals = GlobalHotkeyCollector(apps: runningApps)
            let scan = ScanEngine.run(system: system, app: app, globals: globals)
            await MainActor.run {
                self.result = scan
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
