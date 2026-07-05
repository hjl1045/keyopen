import SwiftUI

@main
struct KeyOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var tracker = FrontmostTracker()

    var body: some Scene {
        MenuBarExtra("KeyOpen", systemImage: "keyboard") {
            MenuContentView()
                .environmentObject(tracker)
        }
        .menuBarExtraStyle(.window)
    }
}
