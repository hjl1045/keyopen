import SwiftUI
import Combine
import ApplicationServices
import KeyOpenCore

struct MenuContentView: View {
    @EnvironmentObject private var tracker: FrontmostTracker
    @EnvironmentObject private var actions: AppActions
    @EnvironmentObject private var updates: UpdateChecker
    @EnvironmentObject private var libraryAccess: LibraryAccess
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if libraryAccess.library == nil {
                libraryBanner
            }

            // Sandboxed, Accessibility can be granted but still can't read
            // another app's menus (AX error -25204), so don't ask for it.
            if !viewModel.accessibilityGranted && !LibraryAccess.isSandboxed {
                permissionBanner
            }

            if let result = viewModel.result {
                // Only the list scrolls: ↻ stays reachable at the top and the
                // caveat stays readable at the bottom, no matter how long the
                // app's menu list is.
                //
                // The height is computed, not left to the ScrollView: a
                // ScrollView's *ideal* height is zero, so `maxHeight` alone
                // collapses it to nothing when the hosting view asks how tall
                // it wants to be. Measuring the rows we're about to draw keeps
                // a short list compact and a long one scrolling.
                ScrollView {
                    // Open slots first: it's the answer the app exists to give,
                    // and under a 50-command menu list nobody ever scrolled to it.
                    VStack(alignment: .leading, spacing: 10) {
                        // Without the Library, system shortcuts and other
                        // apps' hotkeys are invisible, so "free" would be a guess.
                        if libraryAccess.library != nil {
                            openSlotsSection(result)
                        }
                        inUseSection(result)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: listHeight(result))
            } else {
                Text("Scanning…").foregroundStyle(.secondary)
            }

            Divider()
            Text(LibraryAccess.isSandboxed
                 ? "Free among what we can see — system shortcuts and global hotkeys read from other running apps' settings and config files. This edition can't read the current app's menus, so a combo may still clash with one of them."
                 : "Free among what we can see — system shortcuts, this app's menus, and global hotkeys read from other running apps' settings and config files. macOS can't list registered hotkeys, so an app storing them somewhere we don't know may still be missed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Only when there's news: an up-to-date app shows nothing here.
            if let release = updates.availableRelease {
                HStack(alignment: .top, spacing: 8) {
                    Capsule().fill(Tint.free.opacity(Palette.railOpacity)).frame(width: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(release.headline)
                        Button("What's new ›") { NSWorkspace.shared.open(release.url) }
                            .buttonStyle(.plain)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tint.free)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { rescan() }
        // The moment access is granted, show what it unlocked.
        .onChange(of: libraryAccess.library) { _ in rescan() }
        // While access is missing, re-check so the banner clears itself the
        // moment you grant it — no manual refresh or relaunch needed.
        // The publisher is shared, not rebuilt per `body`: a fresh timer each
        // time would restart its countdown and might never fire.
        .onReceive(Self.permissionRecheck) { _ in
            if !viewModel.accessibilityGranted && !LibraryAccess.isSandboxed {
                rescan()
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
                rescan()
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

            moreMenu
        }
    }

    /// Version, updates, feedback and Quit — the panel had no way to quit at all.
    private var moreMenu: some View {
        Menu {
            Button("About KeyOpen") { actions.showAbout() }
            // The About window is where the answer shows, so that's where this goes.
            if !LibraryAccess.isSandboxed {
                Button("Check for Updates…") { actions.showAbout() }
            }
            Button("Send Feedback…") { actions.showFeedback() }
            Divider()
            Toggle("Launch at Login", isOn: SwiftUI.Binding(get: { actions.launchAtLogin },
                                                    set: { actions.setLaunchAtLogin($0) }))
            Divider()
            Button("Quit KeyOpen") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        // Same 28pt target as ↻ beside it.
        .frame(width: 28, height: 28)
        .help("About, updates and feedback")
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

    private func rescan() {
        viewModel.scan(target: tracker.lastActiveApp, store: libraryAccess.store)
    }

    private func shownRecommendations(_ result: ScanResult) -> [Recommendation] {
        libraryAccess.library == nil ? [] : result.recommendations
    }

    /// App Store build only: the sandbox hides ~/Library until it's granted once.
    private var libraryBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Grant access to your Library folder so KeyOpen can see system shortcuts and other apps' hotkeys. Free combos appear after that.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if let problem = libraryAccess.problem {
                Text(problem).font(.caption).foregroundStyle(Palette.warning)
            }
            Button("Grant Library Access…") { libraryAccess.requestAccess() }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Grant Accessibility to see this app's shortcuts.")
                .font(.callout)
            Button("Open Accessibility Settings") {
                // Asking with the prompt option is what puts KeyOpen in the
                // list. Opening the pane alone shows a list with no KeyOpen in
                // it and nothing to switch on: found when a fresh (sandboxed)
                // install wasn't listed.
                let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Hue carries meaning: what can you actually do with this key? Sage you may
    /// take, slate macOS owns, plum another app claims (and could be talked out
    /// of), grey only matters while you're in this app. Amber is reserved for
    /// trouble. Values live in `Palette`.
    private typealias Tint = Palette

    /// The sections as drawn, in order — shared by the renderer and the height
    /// calculation so the two can't disagree about what's on screen.
    /// `namingOwner` is true where rows mix apps and must name theirs.
    private func sections(_ result: ScanResult)
        -> [(title: String, bindings: [KeyOpenCore.Binding], namingOwner: Bool, tint: Color)] {
        var out: [(String, [KeyOpenCore.Binding], Bool, Color)] = [
            ("System", result.systemBindings, false, Tint.system)
        ]
        if !result.appBindings.isEmpty {
            // Includes this app's own global hotkeys, so the rows stay
            // unqualified — the section header already names the app.
            out.append((viewModel.appName ?? "App", result.appBindings, false, Tint.thisApp))
        }
        if !result.globalBindings.isEmpty {
            out.append(("Global hotkeys (other apps)", result.globalBindings, true, Tint.otherApps))
        }
        return out.map { (title: $0.0, bindings: $0.1, namingOwner: $0.2, tint: $0.3) }
    }

    private func inUseSection(_ result: ScanResult) -> some View {
        let conflicts = Dictionary(result.conflicts.map { ($0.combo, $0.bindings) },
                                   uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 6) {
            Text("In use").font(.headline)
            ForEach(sections(result), id: \.title) { section in
                bindingRows(section.title, section.bindings, conflicts: conflicts,
                            namingOwner: section.namingOwner, tint: section.tint)
            }
        }
    }

    private func listHeight(_ result: ScanResult) -> CGFloat {
        let conflictCombos = Set(result.conflicts.map(\.combo))
        let metrics = sections(result).map { section in
            PanelLayout.SectionMetrics(
                rows: section.bindings.count,
                expanded: isExpanded(section.title, count: section.bindings.count),
                conflicts: section.bindings.filter { conflictCombos.contains($0.combo) }.count
            )
        }
        return PanelLayout.listHeight(
            sections: metrics,
            recommendations: shownRecommendations(result).count,
            caveatedRecommendations: shownRecommendations(result).filter { !$0.overlaps.isEmpty }.count)
    }

    private func bindingRows(_ title: String,
                             _ bindings: [KeyOpenCore.Binding],
                             conflicts: [KeyCombo: [KeyOpenCore.Binding]],
                             namingOwner: Bool = false,
                             tint: Color = .secondary) -> some View {
        let rows = bindings.enumerated().map { Row(id: $0.offset, binding: $0.element) }
        let flagged = bindings.filter { binding in
            (conflicts[binding.combo] ?? []).contains { $0 != binding }
        }.count
        let open = isExpanded(title, count: bindings.count)
        return VStack(alignment: .leading, spacing: 3) {
            sectionHeader(title, count: bindings.count, conflicts: flagged,
                          isOpen: open, tint: tint)
            if open {
                // A hairline rail rather than a filled card — the color marks
                // the group without boxing it in or eating vertical space.
                HStack(alignment: .top, spacing: 8) {
                    Capsule().fill(tint.opacity(Palette.railOpacity)).frame(width: 2)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(rows) { row in
                            let rivals = (conflicts[row.binding.combo] ?? [])
                                .filter { $0 != row.binding }
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 8) {
                                    Text(row.binding.combo.displayString)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 94, alignment: .leading)
                                    Text(namingOwner ? row.binding.qualifiedAction : row.binding.action)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    if !rivals.isEmpty {
                                        Spacer(minLength: 0)
                                        Text("⚠︎").foregroundStyle(Palette.warning)
                                    }
                                }
                                // Spelled out rather than hidden in a tooltip: a
                                // hover hint is unreachable in a menu-bar window,
                                // and "conflicts with another shortcut" never said
                                // which one, or which wins.
                                if let note = ConflictNote.text(for: row.binding, rivals: rivals,
                                                                appName: viewModel.appName) {
                                    Text(note)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Palette.warning)
                                        .padding(.leading, 102)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// A tappable section header. Collapsed sections still report their size and
    /// any conflicts inside them — folding a section away must never fold away
    /// the fact that something in it needs attention.
    private func sectionHeader(_ title: String, count: Int, conflicts: Int,
                               isOpen: Bool, tint: Color) -> some View {
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
                        .foregroundStyle(Palette.warning)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
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
            HStack(spacing: 6) {
                Text("Open slots").font(.headline).foregroundStyle(Tint.free)
                Text("best first")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                Capsule().fill(Tint.free.opacity(Palette.railOpacity)).frame(width: 2)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(result.recommendations, id: \.combo) { rec in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 8) {
                                Text(rec.combo.displayString)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Tint.free)
                                    .frame(width: 94, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            // Same reasoning as the conflict notes: inline, not
                            // on hover, or the caveat is never read.
                            if !rec.overlaps.isEmpty {
                                Text("\(rec.overlaps.map(\.displayString).joined(separator: ", ")) already bound — stacks a modifier on a busy key")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
