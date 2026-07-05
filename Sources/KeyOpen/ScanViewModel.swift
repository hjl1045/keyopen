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

        Task.detached {
            let system = SystemShortcutCollector()
            let app: ShortcutCollector? = (granted && pid != nil) ? AppMenuCollector(pid: pid!) : nil
            let scan = ScanEngine.run(system: system, app: app)
            await MainActor.run {
                self.result = scan
                self.isScanning = false
            }
        }
    }
}
