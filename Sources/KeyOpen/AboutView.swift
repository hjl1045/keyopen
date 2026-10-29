import AppKit
import KeyOpenCore
import SwiftUI

/// Version, update status and a way to reach us.
struct AboutView: View {
    @EnvironmentObject private var updates: UpdateChecker
    let onFeedback: () -> Void
    let onCoffee: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("KeyOpen")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 10)
            Text("Version \(AppInfo.version) (\(AppInfo.build)) · macOS \(AppInfo.osVersion)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 3)

            // App Store builds are updated by the App Store.
            if !LibraryAccess.isSandboxed {
                status
                    .font(.system(size: 12))
                    .padding(.top, 12)
            }

            VStack(spacing: 7) {
                if !LibraryAccess.isSandboxed {
                    Button { updates.check() } label: {
                        Text("Check for Updates").frame(maxWidth: .infinity)
                    }
                    .disabled(updates.state == .checking)
                }
                Button(action: onFeedback) {
                    Text("Send Feedback…").frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .padding(.top, 14)

            // No email address here: Send Feedback already writes to it, and the
            // address was what got truncated. The coffee link opens KeyOpen's
            // page (download edition) or the tip jar (App Store edition), never
            // straight to a payment page.
            HStack(spacing: 4) {
                Link("Release notes", destination: UpdateCheck.homePage)
                Text("·").foregroundStyle(.secondary)
                Button("Buy me a coffee ☕", action: onCoffee)
                    .buttonStyle(.link)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 11.5))
            .tint(Palette.system)
            .padding(.top, 12)

        }
        .padding(.horizontal, 26)
        .padding(.bottom, 22)
        .frame(width: 360)
    }

    @ViewBuilder private var status: some View {
        switch updates.state {
        case .idle, .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…").foregroundStyle(.secondary)
            }
        case .upToDate:
            // Re-rendered each minute so "checked 2 min ago" doesn't freeze.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 4) {
                    Text("● You're up to date").foregroundStyle(Palette.free)
                    if let checked = updates.lastChecked {
                        Text("· checked \(Self.ago(checked, now: context.date))")
                    }
                }
            }
        case .available(let release):
            HStack(spacing: 4) {
                Text("KeyOpen \(release.version.description) is available").foregroundStyle(Palette.free)
                Link("Download ›", destination: release.url)
                    .fontWeight(.semibold)
                    .tint(Palette.free)
            }
        case .failed:
            Text("Couldn't check for updates — are you offline?").foregroundStyle(.secondary)
        }
    }

    private static func ago(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
