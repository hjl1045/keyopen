import Foundation

/// Where other apps' preferences are read from.
///
/// The direct build asks `cfprefsd` through `UserDefaults`, which always has
/// the current values. A sandboxed (App Store) build can't: `UserDefaults`
/// only sees its own container. It reads the plist files instead, from the
/// Library folder the user granted access to.
public enum PreferenceStore: Sendable {
    case userDefaults
    /// The user's real `~/Library`, already opened for reading.
    case files(library: URL)

    /// One app's preference domain, e.g. `com.apple.symbolichotkeys`.
    public func domain(_ id: String) -> [String: Any]? {
        switch self {
        case .userDefaults:
            return UserDefaults.standard.persistentDomain(forName: id)
        case .files(let library):
            let url = library.appending(path: "Preferences/\(id).plist")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        }
    }

    /// The home folder that relative paths like `Library/Application Support/…`
    /// hang off. In the sandbox `~` is the container, so it comes from the
    /// granted Library rather than from `FileManager`.
    public var home: URL {
        switch self {
        case .userDefaults: return FileManager.default.homeDirectoryForCurrentUser
        case .files(let library): return library.deletingLastPathComponent()
        }
    }
}
