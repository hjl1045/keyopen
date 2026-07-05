import SwiftUI

@main
struct KeyOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("KeyOpen", systemImage: "keyboard") {
            MenuContentView()
                .environmentObject(appDelegate.tracker)
        }
        .menuBarExtraStyle(.window)
    }
}
