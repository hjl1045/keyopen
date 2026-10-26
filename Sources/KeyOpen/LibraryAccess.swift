import AppKit
import KeyOpenCore

/// Read access to the user's `~/Library`, where system shortcuts and other
/// apps' hotkeys live.
///
/// The direct build simply has it. The App Store build runs sandboxed, where
/// `~` is its own container, so it asks once: an open panel on Library, and the
/// user's choice is kept as a security-scoped bookmark that reopens on every
/// launch without asking again (confirmed with a sandboxed probe, 2026-10-25).
@MainActor
final class LibraryAccess: ObservableObject {
    nonisolated static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// The real home. Inside the sandbox `NSHomeDirectory()` and
    /// `FileManager.homeDirectoryForCurrentUser` both answer with the
    /// container, so this asks the user database instead.
    nonisolated static let realLibrary: URL = {
        let home = getpwuid(getuid()).flatMap { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true).appending(path: "Library")
    }()

    /// Set when the Library can be read.
    @Published private(set) var library: URL?
    /// Why the last grant didn't take, for the banner.
    @Published private(set) var problem: String?

    private static let bookmarkKey = "libraryBookmark"

    init() {
        if Self.isSandboxed {
            restore()
        } else {
            library = Self.realLibrary
        }
    }

    /// How the collectors should read preferences, or nil until access exists.
    var store: PreferenceStore? {
        guard let library else { return nil }
        return Self.isSandboxed ? .files(library: library) : .userDefaults
    }

    func requestAccess() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = Self.realLibrary
        panel.message = "KeyOpen reads system shortcuts and other apps' hotkeys from your Library folder. It only reads; it never changes anything."
        panel.prompt = "Grant Access"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Anything narrower misses sources; anything else isn't where they live.
        guard url.standardizedFileURL.path == Self.realLibrary.standardizedFileURL.path else {
            problem = "That was \(url.lastPathComponent). Choose the Library folder itself."
            return
        }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        } catch {
            NSLog("KeyOpen: couldn't save Library bookmark: \(error)")
        }
        open(url)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 bookmarkDataIsStale: &stale) else { return }
        if stale, let fresh = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        open(url)
    }

    /// Held for the app's lifetime: scans read from it at any moment.
    private func open(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            problem = "macOS didn't allow reading the Library folder. Try granting it again."
            return
        }
        problem = nil
        library = url
    }
}
