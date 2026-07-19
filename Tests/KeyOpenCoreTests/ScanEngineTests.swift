import XCTest
@testable import KeyOpenCore

private struct FakeCollector: ShortcutCollector {
    let bindings: [Binding]
    func collect() -> [Binding] { bindings }
}

final class ScanEngineTests: XCTestCase {
    private let cmdSpace = KeyCombo(modifiers: [.command], key: "Space")

    func testMergesAndFindsCrossSourceConflict() {
        let system = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Spotlight", source: .system)
        ])
        let app = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Command Palette", source: .appMenu),
            Binding(combo: KeyCombo(modifiers: [.command], key: "S"), action: "Save", source: .appMenu),
        ])

        let result = ScanEngine.run(system: system, app: app)

        XCTAssertEqual(result.systemBindings.count, 1)
        XCTAssertEqual(result.appBindings.count, 2)
        XCTAssertEqual(result.conflicts.count, 1)
        XCTAssertEqual(result.conflicts.first?.combo, cmdSpace)
        XCTAssertFalse(result.recommendations.isEmpty)
        XCTAssertFalse(result.recommendations.contains { $0.combo == cmdSpace })
    }

    func testNilAppCollectorYieldsSystemOnly() {
        let system = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Spotlight", source: .system)
        ])
        let result = ScanEngine.run(system: system, app: nil)
        XCTAssertEqual(result.appBindings.count, 0)
        XCTAssertEqual(result.systemBindings.count, 1)
    }

    /// Wispr Flow lists ⌘W twice — "Close window" and "Close Window" — which
    /// showed up as two rows that flagged each other as conflicting (THE-152).
    func testCaseOnlyDuplicateMenuItemsCollapseToOneRow() {
        let cmdW = KeyCombo(modifiers: [.command], key: "W")
        let app = FakeCollector(bindings: [
            Binding(combo: cmdW, action: "Close window", source: .appMenu),
            Binding(combo: cmdW, action: "Close Window", source: .appMenu),
        ])

        let result = ScanEngine.run(system: FakeCollector(bindings: []), app: app)

        XCTAssertEqual(result.appBindings.map(\.action), ["Close window"])
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    func testEllipsisAndSpacingVariantsAreTheSameCommand() {
        let cmdComma = KeyCombo(modifiers: [.command], key: ",")
        let deduped = ScanEngine.deduplicated([
            Binding(combo: cmdComma, action: "Settings…", source: .appMenu),
            Binding(combo: cmdComma, action: "Settings...", source: .appMenu),
            Binding(combo: cmdComma, action: "  Settings ", source: .appMenu),
        ])
        XCTAssertEqual(deduped.count, 1)
    }

    func testDistinctActionsOnTheSameComboStillConflict() {
        let cmdSpace = self.cmdSpace
        let system = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Spotlight", source: .system)
        ])
        let app = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Command Palette", source: .appMenu)
        ])
        let result = ScanEngine.run(system: system, app: app)
        XCTAssertEqual(result.conflicts.count, 1)
    }

    /// Wispr Flow's own ⇧⌘U was listed under "Global hotkeys (other apps)" while
    /// Wispr Flow *was* the app being inspected (THE-152).
    func testTheInspectedAppsOwnGlobalHotkeysAreNotFiledUnderOtherApps() {
        let wispr = Owner(bundleID: "com.electron.wispr-flow", name: "Wispr Flow")
        let localFlow = Owner(bundleID: "com.hjl1045.LocalFlow", name: "LocalFlow")
        let globals = FakeCollector(bindings: [
            Binding(combo: KeyCombo(modifiers: [.shift, .command], key: "U"),
                    action: "Toggle dictation (hands-free)", source: .globalHotkey, owner: wispr),
            Binding(combo: KeyCombo(modifiers: [.shift, .command], key: "K"),
                    action: "Toggle Dictation", source: .globalHotkey, owner: localFlow),
        ])

        let result = ScanEngine.run(system: FakeCollector(bindings: []),
                                    app: FakeCollector(bindings: []),
                                    globals: globals,
                                    appBundleID: wispr.bundleID)

        XCTAssertEqual(result.appBindings.map(\.action), ["Toggle dictation (hands-free)"])
        XCTAssertEqual(result.globalBindings.map(\.owner?.name), ["LocalFlow"])
        // In its own section the app's name is the header, not every row.
        XCTAssertEqual(result.appBindings.first?.qualifiedAction,
                       "Wispr Flow · Toggle dictation (hands-free)")
    }

    func testGlobalHotkeysStayUnderOtherAppsWhenInspectingSomethingElse() {
        let globals = FakeCollector(bindings: [
            Binding(combo: KeyCombo(modifiers: [.shift, .command], key: "U"),
                    action: "Toggle dictation", source: .globalHotkey,
                    owner: Owner(bundleID: "com.electron.wispr-flow", name: "Wispr Flow")),
        ])
        let result = ScanEngine.run(system: FakeCollector(bindings: []), app: nil,
                                    globals: globals, appBundleID: "com.apple.finder")
        XCTAssertTrue(result.appBindings.isEmpty)
        XCTAssertEqual(result.globalBindings.count, 1)
    }

    func testGlobalHotkeysAreTakenAndExcludedFromRecommendations() {
        let shiftCmdK = KeyCombo(modifiers: [.shift, .command], key: "K")
        let system = FakeCollector(bindings: [])
        let globals = FakeCollector(bindings: [
            Binding(combo: shiftCmdK, action: "LocalFlow · Toggle Dictation", source: .globalHotkey)
        ])
        let result = ScanEngine.run(system: system, app: nil, globals: globals)
        XCTAssertEqual(result.globalBindings.count, 1)
        XCTAssertFalse(result.recommendations.contains { $0.combo == shiftCmdK })
    }
}
