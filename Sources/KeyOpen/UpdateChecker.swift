import Foundation
import KeyOpenCore

/// The running build's identity, read from its own Info.plist.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.patchVersion == 0 ? "\(v.majorVersion).\(v.minorVersion)"
            : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static var diagnostics: DiagnosticInfo {
        DiagnosticInfo(appVersion: version, build: build, osVersion: osVersion)
    }
}

/// Checks the site's release feed at launch and once a day after.
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle, checking, upToDate, available(Release), failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?
    private var timer: Timer?

    /// Drives the panel's one-line notice, which shows only when this is set.
    var availableRelease: Release? {
        if case .available(let release) = state { return release }
        return nil
    }

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func check() {
        guard state != .checking else { return }
        // A `swift run` build has no Info.plist version to compare against.
        guard let current = AppVersion(AppInfo.version) else { state = .failed; return }
        state = .checking
        // Skip caches: a stale feed would hide a release for as long as it lives.
        let request = URLRequest(url: UpdateCheck.feed, cachePolicy: .reloadIgnoringLocalCacheData)
        Task {
            let outcome: UpdateCheck.Outcome?
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                outcome = UpdateCheck.evaluate(statusCode: status, body: data, current: current)
            } catch {
                outcome = nil
            }
            switch outcome {
            case .upToDate: state = .upToDate
            case .available(let release): state = .available(release)
            case nil: state = .failed
            }
            lastChecked = Date()
        }
    }
}
