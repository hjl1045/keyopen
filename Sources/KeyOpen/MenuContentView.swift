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

    /// Sections the reader has explicitly opened or closed, by title. Absent
    /// means "use the default", which depends on how long the section is —
    /// see `isExpanded(_:count:)`.
    @State private var overrides: [String: Bool] = [:]

    /// Ceiling for the scrolling middle. Header and footer sit outside it, so
    /// the panel can't outgrow its window however many sections are open.
    private static let listMaxHeight: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !viewModel.accessibilityGranted {
                permissionBanner
            }

            if let result = viewModel.result {
                // Only the list scrolls: ↻ stays reachable at the top and the
                // caveat stays readable at the bottom, no matter how long the
                // app's menu list is.
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        inUseSection(result)
                        openSlotsSection(result)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: Self.listMaxHeight)
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
        let conflicts = Dictionary(result.conflicts.map { ($0.combo, $0.bindings) },
                                   uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 6) {
            Text("In use").font(.headline)
            bindingRows("System", result.systemBindings, conflicts: conflicts)
            if !result.appBindings.isEmpty {
                // Includes this app's own global hotkeys, so the rows stay
                // unqualified — the section header already names the app.
                bindingRows(viewModel.appName ?? "App", result.appBindings, conflicts: conflicts)
            }
            if !result.globalBindings.isEmpty {
                bindingRows("Global hotkeys (other apps)", result.globalBindings,
                            conflicts: conflicts, namingOwner: true)
            }
        }
    }

    private func bindingRows(_ title: String,
                             _ bindings: [KeyOpenCore.Binding],
                             conflicts: [KeyCombo: [KeyOpenCore.Binding]],
                             namingOwner: Bool = false) -> some View {
        let rows = bindings.enumerated().map { Row(id: $0.offset, binding: $0.element) }
        let flagged = bindings.filter { binding in
            (conflicts[binding.combo] ?? []).contains { $0 != binding }
        }.count
        let open = isExpanded(title, count: bindings.count)
        return VStack(alignment: .leading, spacing: 3) {
            sectionHeader(title, count: bindings.count, conflicts: flagged, isOpen: open)
            if open {
                ForEach(rows) { row in
                    let rivals = (conflicts[row.binding.combo] ?? []).filter { $0 != row.binding }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 8) {
                            Text(row.binding.combo.displayString)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 96, alignment: .leading)
                            Text(namingOwner ? row.binding.qualifiedAction : row.binding.action)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            if !rivals.isEmpty {
                                Spacer(minLength: 0)
                                Text("⚠︎").foregroundStyle(.orange)
                            }
                        }
                        // Spelled out rather than hidden in a tooltip: a hover
                        // hint is unreachable in a menu-bar window, and
                        // "conflicts with another shortcut" never said which
                        // one, or which wins.
                        if let note = ConflictNote.text(for: row.binding, rivals: rivals,
                                                        appName: viewModel.appName) {
                            Text(note)
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .padding(.leading, 104)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// A tappable section header. Collapsed sections still report their size and
    /// any conflicts inside them — folding a section away must never fold away
    /// the fact that something in it needs attention.
    private func sectionHeader(_ title: String, count: Int,
                               conflicts: Int, isOpen: Bool) -> some View {
        Button {
            overrides[title] = !isOpen
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 10))
                    .opacity(0.6)
                if conflicts > 0 {
                    Text("⚠︎\(conflicts)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Long sections start folded, short ones don't — an app's 50-command menu
    /// is a wall, its 3 system shortcuts aren't. An explicit tap always wins.
    private func isExpanded(_ title: String, count: Int) -> Bool {
        overrides[title] ?? (count <= 12)
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
