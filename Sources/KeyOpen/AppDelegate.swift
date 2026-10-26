import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// One shared tracker feeds both the menu-bar panel and the global-hotkey panel.
    let tracker = FrontmostTracker()
    let actions = AppActions()
    private var panelController: PanelController?
    private var hotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)

        let controller = PanelController(tracker: tracker, actions: actions)
        self.panelController = controller
        actions.dismissPanel = { [weak controller] in controller?.hide() }
        if !LibraryAccess.isSandboxed { actions.updates.start() }
        actions.offerCrashReportIfAny()

        // Global hotkey: ⌃⌥⌘K. Includes ⌘+⌃, so it avoids macOS Sequoia's
        // restriction on Option-only / Option+Shift-only global hotkeys.
        self.hotkey = GlobalHotkey(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        ) { [weak controller] in
            controller?.toggle()
        }
    }
}
