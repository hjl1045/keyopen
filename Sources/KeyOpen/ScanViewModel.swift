import AppKit
import ApplicationServices
import KeyOpenCore
import os

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var appName: String?
    @Published var accessibilityGranted = true
    @Published var isScanning = false
    /// When the displayed result was produced. A rescan of an unchanged app
    /// looks identical, so this is what tells you the refresh actually ran.
    @Published var lastScanned: Date?
    /// The app the panel shows, so switching to another one can trigger a rescan.
    private(set) var shownPID: pid_t?

    /// Identifies the newest scan, so a slow earlier one can't overwrite it.
    /// Clicks are never dropped while a scan is in flight — that would look
    /// exactly like the button doing nothing.
    private var generation = 0

    nonisolated private static let log = Logger(subsystem: "com.hjl1045.KeyOpen", category: "scan")

    /// `store` is nil while a sandboxed build has no Library access yet: then
    /// only the frontmost app's menus can be read.
    func scan(target: NSRunningApplication?, store: PreferenceStore?) {
        generation += 1
        let generation = self.generation
        isScanning = true
        // Sandboxed, a granted Accessibility still can't read other apps' menus.
        let granted = AXIsProcessTrusted() && !LibraryAccess.isSandboxed
        accessibilityGranted = granted
        appName = target?.localizedName
        shownPID = target?.processIdentifier
        let pid = target?.processIdentifier
        let bundleID = target?.bundleIdentifier
        let runningApps = collectRunningApps()

        Task.detached {
            let system = store.map { SystemShortcutCollector(store: $0) }
                ?? SystemShortcutCollector(rawHotkeys: [:])
            let app: ShortcutCollector? = (granted && pid != nil) ? AppMenuCollector(pid: pid!) : nil
            let globals = MergedCollector(store.map { store in [
                GlobalHotkeyCollector(apps: runningApps, store: store),
                // Apps that keep hotkeys in their own config rather than in
                // macOS preferences — otherwise they'd be offered as free slots.
                AppConfigHotkeyCollector(runningBundleIDs: Set(runningApps.map(\.bundleID)), home: store.home),
            ] } ?? [])
            let scan = ScanEngine.run(system: system, app: app, globals: globals, appBundleID: bundleID)
            // Counts only, no shortcut or app names beyond the target's id —
            // enough to compare a sandboxed build with the direct one.
            if granted, let pid, scan.appBindings.isEmpty {
                // An app with no menu shortcuts is rare; an empty read with
                // Accessibility granted usually means the read itself failed.
                var ref: CFTypeRef?
                let error = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid),
                                                          "AXMenuBar" as CFString, &ref)
                Self.log.notice("menu read empty for \(bundleID ?? "-", privacy: .public): AXMenuBar error \(error.rawValue, privacy: .public)")
            }
            Self.log.notice("scan \(bundleID ?? "-", privacy: .public) sandboxed=\(LibraryAccess.isSandboxed, privacy: .public) library=\(store != nil, privacy: .public) ax=\(granted, privacy: .public) system=\(scan.systemBindings.count, privacy: .public) app=\(scan.appBindings.count, privacy: .public) globals=\(scan.globalBindings.count, privacy: .public) free=\(scan.recommendations.count, privacy: .public)")
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
