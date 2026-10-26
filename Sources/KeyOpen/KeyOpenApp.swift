import SwiftUI

@main
struct KeyOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("KeyOpen", systemImage: "keyboard") {
            MenuContentView()
                .environmentObject(appDelegate.tracker)
                .environmentObject(appDelegate.actions)
                .environmentObject(appDelegate.actions.updates)
                .environmentObject(appDelegate.actions.library)
                // The menu-bar window is translucent glass: over a full-screen
                // app it turned mid-grey and the muted hues washed out. The
                // hotkey panel, an ordinary window, has a solid background and
                // reads crisply, so give this one the same.
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .menuBarExtraStyle(.window)
    }
}
