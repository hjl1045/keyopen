import SwiftUI
import KeyOpenCore

struct MenuContentView: View {
    @EnvironmentObject private var tracker: FrontmostTracker
    @StateObject private var viewModel = ScanViewModel()

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
            Text("Free among what we can see — system shortcuts + this app's menus. Third-party global hotkeys (e.g. Raycast, Rectangle) are hidden by macOS.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { viewModel.scan(target: tracker.lastActiveApp) }
    }

    private var header: some View {
        HStack {
            Text(viewModel.appName ?? "No app").font(.headline)
            Spacer()
            Button {
                viewModel.scan(target: tracker.lastActiveApp)
            } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
        }
    }

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
        return VStack(alignment: .leading, spacing: 4) {
            Text("In use").font(.subheadline).bold()
            bindingRows("System", result.systemBindings, conflicts: conflictCombos)
            if !result.appBindings.isEmpty {
                bindingRows(viewModel.appName ?? "App", result.appBindings, conflicts: conflictCombos)
            }
        }
    }

    private func bindingRows(_ title: String,
                             _ bindings: [KeyOpenCore.Binding],
                             conflicts: Set<KeyCombo>) -> some View {
        let rows = bindings.enumerated().map { Row(id: $0.offset, binding: $0.element) }
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(rows) { row in
                HStack {
                    Text(row.binding.combo.displayString)
                        .monospaced()
                        .frame(width: 80, alignment: .leading)
                    Text(row.binding.action).lineLimit(1)
                    if conflicts.contains(row.binding.combo) {
                        Spacer()
                        Text("⚠︎").help("Conflicts with another shortcut")
                    }
                }
                .font(.caption)
            }
        }
    }

    private func openSlotsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open slots").font(.subheadline).bold()
            ForEach(result.recommendations, id: \.self) { combo in
                Text(combo.displayString).monospaced().font(.caption)
            }
        }
    }
}
