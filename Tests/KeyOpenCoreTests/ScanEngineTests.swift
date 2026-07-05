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
        XCTAssertFalse(result.recommendations.contains(cmdSpace))
    }

    func testNilAppCollectorYieldsSystemOnly() {
        let system = FakeCollector(bindings: [
            Binding(combo: cmdSpace, action: "Spotlight", source: .system)
        ])
        let result = ScanEngine.run(system: system, app: nil)
        XCTAssertEqual(result.appBindings.count, 0)
        XCTAssertEqual(result.systemBindings.count, 1)
    }
}
