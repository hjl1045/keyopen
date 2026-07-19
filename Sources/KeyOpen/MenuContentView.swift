import SwiftUI
import Combine
import KeyOpenCore

struct MenuContentView: View {
    @EnvironmentObject private var tracker: FrontmostTracker
    @StateObject private var viewModel = ScanViewModel()

    private static let permissionRecheck = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    // Wrapper so rows have a stable identity even when two bindings share a combo.
    private struct Row: Identifiable {
        let id: Int
        let binding: KeyOpenCore.Binding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !viewModel.accessibilityGranted {
                permissionBanner
            }

            if let result = viewModel.result {
                inUseSection(result)
                openSlotsSection(result)
            } else {
                Text("Scanning…").foregroundStyle(.secondary)
            }

            Divider()
            Text("Free among what we can see — system shortcuts, this app's menus, and global hotkeys read from other running apps' settings and config files. macOS can't list registered hotkeys, so an app storing them somewhere we don't know may still be missed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { viewModel.scan(target: tracker.lastActiveApp) }
        // While access is missing, re-check so the banner clears itself the
        // moment you grant it — no manual refresh or relaunch needed.
        // The publisher is shared, not rebuilt per `body`: a fresh timer each
        // time would restart its countdown and might never fire.
        .onReceive(Self.permissionRecheck) { _ in
            if !viewModel.accessibilityGranted {
                viewModel.scan(target: tracker.lastActiveApp)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.appName ?? "No app").font(.headline)
                Text(scanStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.scan(target: tracker.lastActiveApp)
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(viewModel.isScanning ? 0 : 1)
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }
                // The bare glyph is a ~13pt target tucked into the window
                // corner — easy to miss, and a miss looks like a dead button.
                // Pad it to a full 28pt square and make all of it clickable.
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Rescan \(viewModel.appName ?? "the frontmost app")")
        }
    }

    /// Rescanning an unchanged app produces identical rows, so the header
    /// carries the proof that something happened.
    private var scanStatus: String {
        if viewModel.isScanning { return "Scanning…" }
        guard let lastScanned = viewModel.lastScanned else { return " " }
        return "Updated \(Self.clock.string(from: lastScanned))"
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Grant Accessibility to see this app's shortcuts.")
                .font(.callout)
            Button("Open Accessibility Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func inUseSection(_ result: ScanResult) -> some View {
        let conflictCombos = Set(result.conflicts.map(\.combo))
        return VStack(alignment: .leading, spacing: 6) {
            Text("In use").font(.headline)
            bindingRows("System", result.systemBindings, conflicts: conflictCombos)
            if !result.appBindings.isEmpty {
                // Includes this app's own global hotkeys, so the rows stay
                // unqualified — the section header already names the app.
                bindingRows(viewModel.appName ?? "App", result.appBindings, conflicts: conflictCombos)
            }
            if !result.globalBindings.isEmpty {
                bindingRows("Global hotkeys (other apps)", result.globalBindings,
                            conflicts: conflictCombos, namingOwner: true)
            }
        }
    }

    private func bindingRows(_ title: String,
                             _ bindings: [KeyOpenCore.Binding],
                             conflicts: Set<KeyCombo>,
                             namingOwner: Bool = false) -> some View {
        let rows = bindings.enumerated().map { Row(id: $0.offset, binding: $0.element) }
        return VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.binding.combo.displayString)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 96, alignment: .leading)
                    Text(namingOwner ? row.binding.qualifiedAction : row.binding.action)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    if conflicts.contains(row.binding.combo) {
                        Spacer(minLength: 0)
                        Text("⚠︎")
                            .foregroundStyle(.orange)
                            .help("Conflicts with another shortcut")
                    }
                }
            }
        }
    }

    private func openSlotsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open slots").font(.headline)
            ForEach(result.recommendations, id: \.combo) { rec in
                HStack(spacing: 8) {
                    Text(rec.combo.displayString)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 96, alignment: .leading)
                    if !rec.overlaps.isEmpty {
                        Text("⚠︎ \(rec.overlaps.map(\.displayString).joined(separator: ", ")) in use")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Usable, but this key already has a simpler shortcut — may be confusing.")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
