import XCTest
@testable import KeyOpenCore

final class ConflictNoteTests: XCTestCase {
    private let shiftCmdK = KeyCombo(modifiers: [.shift, .command], key: "K")
    private let localFlow = Owner(bundleID: "com.hjl1045.LocalFlow", name: "LocalFlow")

    private func menuItem(_ action: String) -> Binding {
        Binding(combo: shiftCmdK, action: action, source: .appMenu)
    }

    private func global(_ action: String) -> Binding {
        Binding(combo: shiftCmdK, action: action, source: .globalHotkey, owner: localFlow)
    }

    /// Finder's ⇧⌘K "Network" never fires while LocalFlow holds ⇧⌘K globally.
    /// Naming the winner is the whole point of the note.
    func testMenuCommandLosingToAGlobalHotkeySaysSoAndNamesIt() {
        let note = ConflictNote.text(for: menuItem("Network"),
                                     rivals: [global("Toggle Dictation")],
                                     appName: "Finder")
        XCTAssertEqual(note, "Blocked by LocalFlow · Toggle Dictation — a global hotkey fires first")
    }

    func testTheGlobalHotkeySideSaysWhatItBlocks() {
        let note = ConflictNote.text(for: global("Toggle Dictation"),
                                     rivals: [menuItem("Network")],
                                     appName: "Finder")
        XCTAssertEqual(note, "Blocks Finder's Network")
    }

    func testSystemShortcutsAreNamedAsMacOS() {
        let system = Binding(combo: shiftCmdK, action: "Show Launchpad", source: .system)
        let note = ConflictNote.text(for: menuItem("Network"), rivals: [system], appName: "Finder")
        XCTAssertEqual(note, "macOS uses this for Show Launchpad")
    }

    func testExtraRivalsAreCounted() {
        let note = ConflictNote.text(for: menuItem("Network"),
                                     rivals: [global("Toggle Dictation"), global("Push To Talk")],
                                     appName: "Finder")
        XCTAssertEqual(note, "Blocked by LocalFlow · Toggle Dictation — a global hotkey fires first (+1 more)")
    }

    func testNoRivalsMeansNoNote() {
        XCTAssertNil(ConflictNote.text(for: menuItem("Network"), rivals: [], appName: "Finder"))
    }
}
