# KeyOpen (macOS Shortcut Helper) — MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a macOS menu-bar app that, on click, shows the keyboard shortcuts in use for the frontmost app (system + that app's menus, conflicts flagged) and recommends a ranked list of free, ergonomic combos — suggest-only.

**Architecture:** One Swift Package. A pure, dependency-light `KeyOpenCore` library holds the data model (`ShortcutMap`), the ingestion collectors, and the `Recommender` — all unit-tested. A thin `KeyOpen` executable target holds the SwiftUI `MenuBarExtra` UI and OS wiring, validated by dogfooding. The OS-touching seams (Accessibility menu read, symbolic-hotkeys read) are split so their *pure* logic (decoding/parsing) is tested and only the raw I/O is left for manual verification.

**Tech Stack:** Swift 5.9, SwiftUI (`MenuBarExtra`, macOS 13+), Accessibility API (`AXUIElement` via ApplicationServices), `UserDefaults` persistent-domain read for `com.apple.symbolichotkeys`. No third-party dependencies. Build/test via SwiftPM (`swift build`, `swift test`, `swift run`).

## Global Constraints

Every task's requirements implicitly include these:

- **Platform floor:** macOS 13.0. `Package.swift` declares `platforms: [.macOS(.v13)]`.
- **Language:** Swift 5.9 (`// swift-tools-version: 5.9`).
- **No external dependencies** — SwiftPM + Apple system frameworks only.
- **Suggest-only** — the app NEVER writes a binding, edits a plist, or changes system state. Read-only everywhere.
- **No onboarding flow** — a missing Accessibility permission is a graceful inline empty-state, not a wizard.
- **Honesty footnote (exact copy, shown in the UI footer):** `Free among what we can see — system shortcuts + this app's menus. Third-party global hotkeys (e.g. Raycast, Rectangle) are hidden by macOS.`
- **Permission empty-state (exact copy):** `Grant Accessibility to see this app's shortcuts.` with a button `Open Accessibility Settings` that opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- **Distribution:** open-source repo, run locally for MVP. NOT Mac App Store (Accessibility API rules it out). Packaging a notarized `.app`/DMG is out of scope for this plan.
- **Frequent commits** — one commit per task, message prefix `feat:` / `test:` / `chore:`.

---

### Task 1: Scaffold the Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/KeyOpenCore/Placeholder.swift`
- Create: `Tests/KeyOpenCoreTests/SmokeTests.swift`
- Create: `Sources/KeyOpen/KeyOpenApp.swift` (temporary stub, replaced in Task 9)

**Interfaces:**
- Consumes: nothing.
- Produces: a compiling package with a green `swift test` and a runnable (stub) executable.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyOpen",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KeyOpenCore"),
        .testTarget(name: "KeyOpenCoreTests", dependencies: ["KeyOpenCore"]),
        .executableTarget(name: "KeyOpen", dependencies: ["KeyOpenCore"]),
    ]
)
```

- [ ] **Step 2: Create a placeholder so the library target compiles**

`Sources/KeyOpenCore/Placeholder.swift`:

```swift
// Replaced by real types in later tasks. Keeps the target non-empty for Task 1.
enum KeyOpenCorePlaceholder {}
```

- [ ] **Step 3: Create a temporary executable stub**

`Sources/KeyOpen/KeyOpenApp.swift`:

```swift
// Temporary stub — replaced by the real MenuBarExtra app in Task 9.
@main
struct KeyOpenApp {
    static func main() {
        print("KeyOpen stub — replaced in Task 9")
    }
}
```

- [ ] **Step 4: Write the smoke test**

`Tests/KeyOpenCoreTests/SmokeTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class SmokeTests: XCTestCase {
    func testPackageCompilesAndRuns() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 5: Run build and tests**

Run: `swift build && swift test`
Expected: build succeeds; `SmokeTests.testPackageCompilesAndRuns` PASSES.

- [ ] **Step 6: Add a `.gitignore` for SwiftPM build artifacts**

Append to `.gitignore` (the file already exists with `.DS_Store` from the design commit):

```
.build/
*.xcodeproj
.swiftpm/
```

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests .gitignore
git commit -m "chore: scaffold KeyOpen Swift package"
```

---

### Task 2: Core value types — `Modifier`, `KeyCombo`, `Source`, `Binding`

**Files:**
- Create: `Sources/KeyOpenCore/Models.swift`
- Delete: `Sources/KeyOpenCore/Placeholder.swift`
- Test: `Tests/KeyOpenCoreTests/ModelsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum Modifier: String, Hashable, CaseIterable, Sendable { case control, option, shift, command }` with `var glyph: String`.
  - `struct KeyCombo: Hashable, Sendable { let modifiers: Set<Modifier>; let key: String; init(modifiers:key:); var displayString: String }` — `key` is stored uppercased.
  - `enum Source: Hashable, Sendable { case system; case appMenu }`
  - `struct Binding: Hashable, Sendable { let combo: KeyCombo; let action: String; let source: Source; init(combo:action:source:) }`

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/ModelsTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class ModelsTests: XCTestCase {
    func testDisplayStringUsesCanonicalGlyphOrder() {
        // Canonical macOS order is Control, Option, Shift, Command.
        let combo = KeyCombo(modifiers: [.command, .shift], key: "s")
        XCTAssertEqual(combo.displayString, "⇧⌘S")
    }

    func testKeyIsNormalizedToUppercase() {
        XCTAssertEqual(KeyCombo(modifiers: [.command], key: "d").key, "D")
    }

    func testHyperOrderingAndAllGlyphs() {
        let combo = KeyCombo(modifiers: [.control, .option, .command, .shift], key: "K")
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘K")
    }

    func testEqualityIgnoresModifierInsertionOrder() {
        let a = KeyCombo(modifiers: [.command, .shift], key: "S")
        let b = KeyCombo(modifiers: [.shift, .command], key: "s")
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ModelsTests`
Expected: FAIL — `KeyCombo` / `Modifier` undefined.

- [ ] **Step 3: Delete the placeholder and write the models**

Delete `Sources/KeyOpenCore/Placeholder.swift`. Create `Sources/KeyOpenCore/Models.swift`:

```swift
import Foundation

public enum Modifier: String, Hashable, CaseIterable, Sendable {
    case control, option, shift, command

    public var glyph: String {
        switch self {
        case .control: return "⌃"
        case .option:  return "⌥"
        case .shift:   return "⇧"
        case .command: return "⌘"
        }
    }

    /// Canonical macOS display order: Control, Option, Shift, Command.
    var order: Int {
        switch self {
        case .control: return 0
        case .option:  return 1
        case .shift:   return 2
        case .command: return 3
        }
    }
}

public struct KeyCombo: Hashable, Sendable {
    public let modifiers: Set<Modifier>
    public let key: String

    public init(modifiers: Set<Modifier>, key: String) {
        self.modifiers = modifiers
        self.key = key.uppercased()
    }

    public var displayString: String {
        let mods = modifiers.sorted { $0.order < $1.order }.map(\.glyph).joined()
        return mods + key
    }
}

public enum Source: Hashable, Sendable {
    case system
    case appMenu
}

public struct Binding: Hashable, Sendable {
    public let combo: KeyCombo
    public let action: String
    public let source: Source

    public init(combo: KeyCombo, action: String, source: Source) {
        self.combo = combo
        self.action = action
        self.source = source
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ModelsTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KeyOpenCore/Models.swift Tests/KeyOpenCoreTests/ModelsTests.swift
git rm Sources/KeyOpenCore/Placeholder.swift
git commit -m "feat: add core KeyCombo/Binding value types"
```

---

### Task 3: `ShortcutMap`

**Files:**
- Create: `Sources/KeyOpenCore/ShortcutMap.swift`
- Test: `Tests/KeyOpenCoreTests/ShortcutMapTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Binding` (Task 2).
- Produces:
  - `struct ShortcutMap: Sendable` with `init(_ bindings: [Binding] = [])`, `mutating func add(_ b: Binding)`, `func isTaken(_ combo: KeyCombo) -> Bool`, `func takenCombos() -> Set<KeyCombo>`, `func conflicts() -> [(combo: KeyCombo, bindings: [Binding])]`, and `var bindings: [Binding] { get }`.
  - Conflict = a combo held by **2+ distinct `Binding`s**; identical duplicate bindings do NOT count.

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/ShortcutMapTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class ShortcutMapTests: XCTestCase {
    private let cmdS = KeyCombo(modifiers: [.command], key: "S")
    private let cmdSpace = KeyCombo(modifiers: [.command], key: "Space")

    func testIsTakenAndTakenCombos() {
        var map = ShortcutMap()
        map.add(Binding(combo: cmdS, action: "Save", source: .appMenu))
        XCTAssertTrue(map.isTaken(cmdS))
        XCTAssertFalse(map.isTaken(cmdSpace))
        XCTAssertEqual(map.takenCombos(), [cmdS])
    }

    func testConflictNeedsTwoDistinctBindings() {
        var map = ShortcutMap()
        map.add(Binding(combo: cmdSpace, action: "Spotlight", source: .system))
        map.add(Binding(combo: cmdSpace, action: "Command Palette", source: .appMenu))
        let conflicts = map.conflicts()
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.combo, cmdSpace)
        XCTAssertEqual(conflicts.first?.bindings.count, 2)
    }

    func testIdenticalDuplicatesAreNotAConflict() {
        var map = ShortcutMap()
        let b = Binding(combo: cmdS, action: "Save", source: .appMenu)
        map.add(b)
        map.add(b)
        XCTAssertTrue(map.conflicts().isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ShortcutMapTests`
Expected: FAIL — `ShortcutMap` undefined.

- [ ] **Step 3: Write the implementation**

`Sources/KeyOpenCore/ShortcutMap.swift`:

```swift
import Foundation

public struct ShortcutMap: Sendable {
    public private(set) var bindings: [Binding]

    public init(_ bindings: [Binding] = []) {
        self.bindings = bindings
    }

    public mutating func add(_ b: Binding) {
        bindings.append(b)
    }

    public func isTaken(_ combo: KeyCombo) -> Bool {
        bindings.contains { $0.combo == combo }
    }

    public func takenCombos() -> Set<KeyCombo> {
        Set(bindings.map(\.combo))
    }

    public func conflicts() -> [(combo: KeyCombo, bindings: [Binding])] {
        var byCombo: [KeyCombo: [Binding]] = [:]
        for b in bindings {
            byCombo[b.combo, default: []].append(b)
        }
        return byCombo
            .compactMap { combo, list -> (combo: KeyCombo, bindings: [Binding])? in
                // Distinct bindings only — identical duplicates are not a conflict.
                let distinct = Array(Set(list))
                guard distinct.count > 1 else { return nil }
                return (combo: combo, bindings: list)
            }
            .sorted { $0.combo.displayString < $1.combo.displayString }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ShortcutMapTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KeyOpenCore/ShortcutMap.swift Tests/KeyOpenCoreTests/ShortcutMapTests.swift
git commit -m "feat: add ShortcutMap with conflict detection"
```

---

### Task 4: System shortcuts — `SymbolicHotkeyParser` + `SystemShortcutCollector`

**Files:**
- Create: `Sources/KeyOpenCore/Collector.swift` (the shared protocol)
- Create: `Sources/KeyOpenCore/SystemShortcutCollector.swift`
- Test: `Tests/KeyOpenCoreTests/SymbolicHotkeyParserTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Binding`, `Modifier`, `Source` (Task 2).
- Produces:
  - `public protocol ShortcutCollector: Sendable { func collect() -> [Binding] }`
  - `public enum SymbolicHotkeyParser { public static func parse(_ dict: [String: Any]) -> [Binding] }` — input is the `AppleSymbolicHotKeys` sub-dictionary.
  - `public struct SystemShortcutCollector: ShortcutCollector` with `init(rawHotkeys: [String: Any])` (testable) and `init()` (reads the real `com.apple.symbolichotkeys` domain).
- Parsing rules: skip entries where `enabled != true`; read `value.parameters` as `[Int]` (`[ascii, keycode, cocoaModifierMask]`); map ascii→key (`32`→`"Space"`, printable `33...126`→uppercased char, else skip); decode the Cocoa modifier mask; look up a human name by hotkey id, else `System hotkey #<id>`.

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/SymbolicHotkeyParserTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class SymbolicHotkeyParserTests: XCTestCase {
    // Cocoa modifier flags: command = 1<<20 (1048576), shift = 1<<17 (131072).

    func testParsesEnabledSpotlightHotkey() {
        let dict: [String: Any] = [
            "64": ["enabled": true,
                   "value": ["parameters": [32, 49, 1048576]]] // Cmd + Space
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings[0].combo, KeyCombo(modifiers: [.command], key: "Space"))
        XCTAssertEqual(bindings[0].action, "Spotlight – Show search field")
        XCTAssertEqual(bindings[0].source, .system)
    }

    func testSkipsDisabledEntries() {
        let dict: [String: Any] = [
            "64": ["enabled": false,
                   "value": ["parameters": [32, 49, 1048576]]]
        ]
        XCTAssertTrue(SymbolicHotkeyParser.parse(dict).isEmpty)
    }

    func testUnknownIdFallsBackToGenericName() {
        let dict: [String: Any] = [
            "9999": ["enabled": true,
                     "value": ["parameters": [65, 0, 1048576 + 131072]]] // Cmd+Shift+A
        ]
        let bindings = SymbolicHotkeyParser.parse(dict)
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings[0].combo, KeyCombo(modifiers: [.command, .shift], key: "A"))
        XCTAssertEqual(bindings[0].action, "System hotkey #9999")
    }

    func testCollectorForwardsInjectedHotkeys() {
        let dict: [String: Any] = [
            "64": ["enabled": true, "value": ["parameters": [32, 49, 1048576]]]
        ]
        let collector = SystemShortcutCollector(rawHotkeys: dict)
        XCTAssertEqual(collector.collect().count, 1)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SymbolicHotkeyParserTests`
Expected: FAIL — `SymbolicHotkeyParser` / `SystemShortcutCollector` undefined.

- [ ] **Step 3: Write the protocol**

`Sources/KeyOpenCore/Collector.swift`:

```swift
public protocol ShortcutCollector: Sendable {
    func collect() -> [Binding]
}
```

- [ ] **Step 4: Write the parser and collector**

`Sources/KeyOpenCore/SystemShortcutCollector.swift`:

```swift
import Foundation

public enum SymbolicHotkeyParser {
    /// A small curated map of well-known hotkey ids. Unknown ids fall back
    /// to a generic name — the parsing logic is what matters, not exhaustiveness.
    static let names: [Int: String] = [
        32: "Mission Control",
        34: "Mission Control – Application windows",
        64: "Spotlight – Show search field",
        65: "Spotlight – Show Finder search window",
        79: "Move left a space",
        81: "Move right a space",
    ]

    public static func parse(_ dict: [String: Any]) -> [Binding] {
        var out: [Binding] = []
        for (idString, raw) in dict {
            guard
                let id = Int(idString),
                let entry = raw as? [String: Any],
                (entry["enabled"] as? Bool) == true,
                let value = entry["value"] as? [String: Any],
                let rawParams = value["parameters"] as? [Any]
            else { continue }

            let params = rawParams.compactMap { ($0 as? NSNumber)?.intValue }
            guard params.count >= 3, let key = keyString(fromASCII: params[0]) else { continue }

            let combo = KeyCombo(modifiers: modifiers(fromCocoaMask: params[2]), key: key)
            let name = names[id] ?? "System hotkey #\(id)"
            out.append(Binding(combo: combo, action: name, source: .system))
        }
        return out.sorted { $0.action < $1.action }
    }

    static func keyString(fromASCII ascii: Int) -> String? {
        if ascii == 32 { return "Space" }
        guard ascii >= 33, ascii <= 126, let scalar = UnicodeScalar(ascii) else { return nil }
        return String(scalar).uppercased()
    }

    static func modifiers(fromCocoaMask mask: Int) -> Set<Modifier> {
        var mods: Set<Modifier> = []
        if mask & (1 << 17) != 0 { mods.insert(.shift) }
        if mask & (1 << 18) != 0 { mods.insert(.control) }
        if mask & (1 << 19) != 0 { mods.insert(.option) }
        if mask & (1 << 20) != 0 { mods.insert(.command) }
        return mods
    }
}

public struct SystemShortcutCollector: ShortcutCollector {
    private let rawHotkeys: [String: Any]

    public init(rawHotkeys: [String: Any]) {
        self.rawHotkeys = rawHotkeys
    }

    public init() {
        let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")
        self.rawHotkeys = (domain?["AppleSymbolicHotKeys"] as? [String: Any]) ?? [:]
    }

    public func collect() -> [Binding] {
        SymbolicHotkeyParser.parse(rawHotkeys)
    }
}
```

Note: `[String: Any]` is not `Sendable`. Mark the collector's conformance pragmatically — the stored dictionary is never mutated. If the compiler flags `Sendable`, change `public struct SystemShortcutCollector: ShortcutCollector` to hold the already-parsed `[Binding]` instead: parse in the initializers (`self.bindings = SymbolicHotkeyParser.parse(rawHotkeys)`) and return `bindings` from `collect()`. Prefer this parsed-at-init form if you hit a `Sendable` error.

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter SymbolicHotkeyParserTests`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/KeyOpenCore/Collector.swift Sources/KeyOpenCore/SystemShortcutCollector.swift Tests/KeyOpenCoreTests/SymbolicHotkeyParserTests.swift
git commit -m "feat: add symbolic-hotkey parser and system collector"
```

---

### Task 5: `MenuItemDecoder` (pure AX menu-item decoding)

**Files:**
- Create: `Sources/KeyOpenCore/MenuItemDecoder.swift`
- Test: `Tests/KeyOpenCoreTests/MenuItemDecoderTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Modifier` (Task 2).
- Produces: `public enum MenuItemDecoder { public static func decode(cmdChar: String?, cmdModifiers: Int, cmdGlyph: Int?) -> KeyCombo? }`
- Decoding rules (Carbon menu-modifier bitmask): bit0 (1)=Shift, bit1 (2)=Option, bit2 (4)=Control, bit3 (8)=**suppress Command** (Command is implied UNLESS this bit is set). A `nil`/empty `cmdChar` → `nil` (MVP skips glyph-only items).

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/MenuItemDecoderTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class MenuItemDecoderTests: XCTestCase {
    func testPlainCommandLetter() {
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "s", cmdModifiers: 0, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command], key: "S"))
    }

    func testShiftCommand() {
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "s", cmdModifiers: 1, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command, .shift], key: "S"))
    }

    func testOptionControlCommand() {
        // 2 (option) | 4 (control) = 6, command implied.
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "l", cmdModifiers: 6, cmdGlyph: nil),
                       KeyCombo(modifiers: [.command, .option, .control], key: "L"))
    }

    func testNoCommandBitSuppressesCommand() {
        // bit3 (8) set → command suppressed; only shift remains (1).
        XCTAssertEqual(MenuItemDecoder.decode(cmdChar: "x", cmdModifiers: 9, cmdGlyph: nil),
                       KeyCombo(modifiers: [.shift], key: "X"))
    }

    func testNilCharReturnsNil() {
        XCTAssertNil(MenuItemDecoder.decode(cmdChar: nil, cmdModifiers: 0, cmdGlyph: 100))
        XCTAssertNil(MenuItemDecoder.decode(cmdChar: "", cmdModifiers: 0, cmdGlyph: nil))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MenuItemDecoderTests`
Expected: FAIL — `MenuItemDecoder` undefined.

- [ ] **Step 3: Write the decoder**

`Sources/KeyOpenCore/MenuItemDecoder.swift`:

```swift
public enum MenuItemDecoder {
    public static func decode(cmdChar: String?, cmdModifiers: Int, cmdGlyph: Int?) -> KeyCombo? {
        guard let cmdChar, !cmdChar.isEmpty else { return nil }

        var mods: Set<Modifier> = []
        if cmdModifiers & 1 != 0 { mods.insert(.shift) }
        if cmdModifiers & 2 != 0 { mods.insert(.option) }
        if cmdModifiers & 4 != 0 { mods.insert(.control) }
        if cmdModifiers & 8 == 0 { mods.insert(.command) } // Command implied unless bit3 set.

        return KeyCombo(modifiers: mods, key: cmdChar.uppercased())
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter MenuItemDecoderTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KeyOpenCore/MenuItemDecoder.swift Tests/KeyOpenCoreTests/MenuItemDecoderTests.swift
git commit -m "feat: add pure AX menu-item decoder"
```

---

### Task 6: `AppMenuCollector` (Accessibility menu traversal)

**Files:**
- Create: `Sources/KeyOpenCore/AppMenuCollector.swift`

**Interfaces:**
- Consumes: `ShortcutCollector` (Task 4), `MenuItemDecoder` (Task 5), `Binding`, `Source` (Task 2).
- Produces: `public struct AppMenuCollector: ShortcutCollector { public init(pid: pid_t); public func collect() -> [Binding] }` — emits `.appMenu` bindings for every menu item with a command-key equivalent.

**Verification note:** This task touches the live Accessibility API, so it has no unit test (per spec §9 — Accessibility collectors are validated by dogfooding). Its deliverable is: **it compiles and is correctly wired.** Behavioral verification happens in Task 12's dogfood pass, where the target app's real shortcuts appear in the "In use" list.

- [ ] **Step 1: Write the collector**

`Sources/KeyOpenCore/AppMenuCollector.swift`:

```swift
import ApplicationServices

public struct AppMenuCollector: ShortcutCollector {
    private let pid: pid_t

    public init(pid: pid_t) {
        self.pid = pid
    }

    public func collect() -> [Binding] {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = copyElement(app, "AXMenuBar") else { return [] }
        var out: [Binding] = []
        traverse(menuBar, depth: 0, into: &out)
        return out
    }

    private func traverse(_ element: AXUIElement, depth: Int, into out: inout [Binding]) {
        guard depth < 12 else { return } // guard against pathological menu trees
        guard let children = copyChildren(element) else { return }
        for child in children {
            let cmdChar = copyString(child, "AXMenuItemCmdChar")
            let cmdMods = copyInt(child, "AXMenuItemCmdModifiers") ?? 0
            let cmdGlyph = copyInt(child, "AXMenuItemCmdGlyph")
            if let combo = MenuItemDecoder.decode(cmdChar: cmdChar, cmdModifiers: cmdMods, cmdGlyph: cmdGlyph) {
                let title = copyString(child, "AXTitle") ?? cmdChar ?? "?"
                out.append(Binding(combo: combo, action: title, source: .appMenu))
            }
            traverse(child, depth: depth + 1, into: &out)
        }
    }

    // MARK: - AX helpers

    private func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func copyChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &ref) == .success
        else { return nil }
        return ref as? [AXUIElement]
    }

    private func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success
        else { return nil }
        return ref as? String
    }

    private func copyInt(_ element: AXUIElement, _ attribute: String) -> Int? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let number = ref as? NSNumber
        else { return nil }
        return number.intValue
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/KeyOpenCore/AppMenuCollector.swift
git commit -m "feat: add Accessibility-based app menu collector"
```

---

### Task 7: The Recommender — `CandidateSpace`, `ReservedCombos`, `Scoring`, `Recommender`

**Files:**
- Create: `Sources/KeyOpenCore/Recommender.swift`
- Test: `Tests/KeyOpenCoreTests/RecommenderTests.swift`

**Interfaces:**
- Consumes: `KeyCombo`, `Modifier` (Task 2), `ShortcutMap` (Task 3).
- Produces:
  - `public enum CandidateSpace { public static let modifierSets: [Set<Modifier>]; public static let keys: [String]; public static let all: [KeyCombo] }`
  - `public enum ReservedCombos { public static let all: Set<KeyCombo> }`
  - `public enum Scoring { public static func score(_ combo: KeyCombo) -> Double }`
  - `public struct Recommender { public init(candidates: [KeyCombo] = CandidateSpace.all, reserved: Set<KeyCombo> = ReservedCombos.all); public func recommend(from map: ShortcutMap, limit: Int = 8) -> [KeyCombo] }`
- Ranking: exclude `map.takenCombos() ∪ reserved`; sort the rest by `Scoring.score` descending, ties broken by candidate order (stable). Return the first `limit`. Single-`⌘` combos are intentionally NOT candidates (all treated as reserved by omission).

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/RecommenderTests.swift`:

```swift
import XCTest
@testable import KeyOpenCore

final class RecommenderTests: XCTestCase {
    func testTopSuggestionsAreDeterministicForEmptyMap() {
        // Best modifier set is ⇧⌘; best keys are the "easy" set; A is reserved (⇧⌘A),
        // so the first three by candidate order are D, E, F.
        let recs = Recommender().recommend(from: ShortcutMap(), limit: 3)
        XCTAssertEqual(recs.map(\.displayString), ["⇧⌘D", "⇧⌘E", "⇧⌘F"])
    }

    func testExcludesTakenCombos() {
        var map = ShortcutMap()
        map.add(Binding(combo: KeyCombo(modifiers: [.command, .shift], key: "D"),
                        action: "Duplicate", source: .appMenu))
        let recs = Recommender().recommend(from: map, limit: 3)
        XCTAssertEqual(recs.map(\.displayString), ["⇧⌘E", "⇧⌘F", "⇧⌘J"])
    }

    func testNeverSuggestsReservedCombos() {
        let all = Recommender().recommend(from: ShortcutMap(), limit: 500)
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "A"))) // Redo/Deselect-ish
        XCTAssertFalse(all.contains(KeyCombo(modifiers: [.command, .shift], key: "Z"))) // Redo
    }

    func testRespectsLimit() {
        XCTAssertEqual(Recommender().recommend(from: ShortcutMap(), limit: 5).count, 5)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter RecommenderTests`
Expected: FAIL — `Recommender` undefined.

- [ ] **Step 3: Write the recommender**

`Sources/KeyOpenCore/Recommender.swift`:

```swift
import Foundation

public enum CandidateSpace {
    /// Ordered best → worst by ergonomics. Single-⌘ is intentionally absent
    /// (all single-⌘ combos are treated as reserved by omission).
    public static let modifierSets: [Set<Modifier>] = [
        [.command, .shift],
        [.command, .option],
        [.command, .control],
        [.control, .option],
        [.command, .option, .shift],
        [.command, .control, .shift],
        [.control, .option, .command],
    ]

    public static let keys: [String] = {
        let letters = (65...90).compactMap { UnicodeScalar($0).map { String($0) } } // A–Z
        let digits = (0...9).map(String.init)
        return letters + digits
    }()

    public static let all: [KeyCombo] = {
        var combos: [KeyCombo] = []
        for mods in modifierSets {
            for key in keys {
                combos.append(KeyCombo(modifiers: mods, key: key))
            }
        }
        return combos
    }()
}

public enum ReservedCombos {
    /// Conventional multi-modifier combos that are near-universal even when a
    /// given app's menu doesn't list them. Tunable by feel.
    public static let all: Set<KeyCombo> = [
        KeyCombo(modifiers: [.command, .shift], key: "Z"), // Redo
        KeyCombo(modifiers: [.command, .shift], key: "N"), // New window / folder
        KeyCombo(modifiers: [.command, .shift], key: "T"), // Reopen closed tab
        KeyCombo(modifiers: [.command, .shift], key: "P"), // Private / print variants
        KeyCombo(modifiers: [.command, .shift], key: "G"), // Find previous
        KeyCombo(modifiers: [.command, .shift], key: "A"), // Deselect all
        KeyCombo(modifiers: [.command, .option], key: "W"), // Close all
        KeyCombo(modifiers: [.command, .option], key: "M"), // Minimize all
        KeyCombo(modifiers: [.command, .option], key: "D"), // Toggle Dock
    ]
}

public enum Scoring {
    private static let easyKeys: Set<String> = ["A","S","D","F","J","K","L","E","R","W","Q"]

    public static func score(_ combo: KeyCombo) -> Double {
        let count = CandidateSpace.modifierSets.count
        let rank = CandidateSpace.modifierSets.firstIndex(of: combo.modifiers) ?? count
        let modifierScore = Double((count - rank) * 10)

        let isLetter = combo.key.count == 1 && combo.key >= "A" && combo.key <= "Z"
        let keyScore: Double = easyKeys.contains(combo.key) ? 5 : (isLetter ? 2 : 0)

        return modifierScore + keyScore
    }
}

public struct Recommender {
    private let candidates: [KeyCombo]
    private let reserved: Set<KeyCombo>

    public init(candidates: [KeyCombo] = CandidateSpace.all,
                reserved: Set<KeyCombo> = ReservedCombos.all) {
        self.candidates = candidates
        self.reserved = reserved
    }

    public func recommend(from map: ShortcutMap, limit: Int = 8) -> [KeyCombo] {
        let taken = map.takenCombos().union(reserved)
        let free = candidates.enumerated().filter { !taken.contains($0.element) }
        let ranked = free.sorted { a, b in
            let sa = Scoring.score(a.element), sb = Scoring.score(b.element)
            if sa != sb { return sa > sb }
            return a.offset < b.offset // stable: preserve ergonomic candidate order on ties
        }
        return ranked.prefix(limit).map(\.element)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter RecommenderTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KeyOpenCore/Recommender.swift Tests/KeyOpenCoreTests/RecommenderTests.swift
git commit -m "feat: add free-combo recommender with scoring"
```

---

### Task 8: `ScanEngine` — pure assembly of collectors + recommender

**Files:**
- Create: `Sources/KeyOpenCore/ScanEngine.swift`
- Test: `Tests/KeyOpenCoreTests/ScanEngineTests.swift`

**Interfaces:**
- Consumes: `ShortcutCollector` (Task 4), `ShortcutMap` (Task 3), `Recommender` (Task 7).
- Produces:
  - `public struct ScanResult: Sendable { public let systemBindings: [Binding]; public let appBindings: [Binding]; public let conflicts: [(combo: KeyCombo, bindings: [Binding])]; public let recommendations: [KeyCombo] }`
  - `public enum ScanEngine { public static func run(system: ShortcutCollector, app: ShortcutCollector?, recommender: Recommender = Recommender()) -> ScanResult }`
- Behavior: collect system + app bindings, merge into a `ShortcutMap`, compute conflicts across the merged map, and recommend from it. `systemBindings`/`appBindings` are returned sorted by `combo.displayString`.

- [ ] **Step 1: Write the failing test**

`Tests/KeyOpenCoreTests/ScanEngineTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ScanEngineTests`
Expected: FAIL — `ScanEngine` / `ScanResult` undefined.

- [ ] **Step 3: Write the engine**

`Sources/KeyOpenCore/ScanEngine.swift`:

```swift
public struct ScanResult: Sendable {
    public let systemBindings: [Binding]
    public let appBindings: [Binding]
    public let conflicts: [(combo: KeyCombo, bindings: [Binding])]
    public let recommendations: [KeyCombo]
}

public enum ScanEngine {
    public static func run(system: ShortcutCollector,
                           app: ShortcutCollector?,
                           recommender: Recommender = Recommender()) -> ScanResult {
        let systemBindings = system.collect()
        let appBindings = app?.collect() ?? []

        var map = ShortcutMap()
        for b in systemBindings { map.add(b) }
        for b in appBindings { map.add(b) }

        return ScanResult(
            systemBindings: systemBindings.sorted { $0.combo.displayString < $1.combo.displayString },
            appBindings: appBindings.sorted { $0.combo.displayString < $1.combo.displayString },
            conflicts: map.conflicts(),
            recommendations: recommender.recommend(from: map)
        )
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ScanEngineTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the full suite to confirm nothing regressed**

Run: `swift test`
Expected: ALL tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/KeyOpenCore/ScanEngine.swift Tests/KeyOpenCoreTests/ScanEngineTests.swift
git commit -m "feat: add ScanEngine assembling collectors and recommender"
```

---

### Task 9: App shell — `MenuBarExtra` app, activation policy, frontmost-app tracking

**Files:**
- Replace: `Sources/KeyOpen/KeyOpenApp.swift` (removes the Task 1 stub)
- Create: `Sources/KeyOpen/AppDelegate.swift`
- Create: `Sources/KeyOpen/FrontmostTracker.swift`

**Interfaces:**
- Consumes: nothing from Core yet (UI wired in Tasks 10–11).
- Produces:
  - `AppDelegate: NSObject, NSApplicationDelegate` that sets `NSApp.setActivationPolicy(.accessory)` on launch (menu-bar-only, no Dock icon).
  - `@MainActor final class FrontmostTracker: ObservableObject { @Published var lastActiveApp: NSRunningApplication? }` observing `NSWorkspace.didActivateApplicationNotification`, ignoring our own bundle.
  - `@main struct KeyOpenApp: App` presenting a `MenuBarExtra` (placeholder body until Task 11).

**Verification note:** UI/OS wiring — validated by running the app, not by unit tests.

- [ ] **Step 1: Write the app delegate**

`Sources/KeyOpen/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 2: Write the frontmost tracker**

`Sources/KeyOpen/FrontmostTracker.swift`:

```swift
import AppKit
import Combine

@MainActor
final class FrontmostTracker: ObservableObject {
    @Published var lastActiveApp: NSRunningApplication?

    init() {
        lastActiveApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        // Ignore ourselves so opening the menu doesn't overwrite the real target.
        if app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = app
        }
    }
}
```

- [ ] **Step 3: Replace the app stub with a real MenuBarExtra scene**

`Sources/KeyOpen/KeyOpenApp.swift`:

```swift
import SwiftUI

@main
struct KeyOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var tracker = FrontmostTracker()

    var body: some Scene {
        MenuBarExtra("KeyOpen", systemImage: "keyboard") {
            // Placeholder until Task 11 wires MenuContentView.
            Text("KeyOpen")
                .environmentObject(tracker)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 4: Build and run; verify the menu-bar item appears**

Run: `swift run KeyOpen`
Expected: no Dock icon appears; a keyboard icon appears in the menu bar; clicking it shows a small window reading "KeyOpen". Quit with `Ctrl-C` in the terminal (or `killall KeyOpen`).

- [ ] **Step 5: Commit**

```bash
git add Sources/KeyOpen/AppDelegate.swift Sources/KeyOpen/FrontmostTracker.swift Sources/KeyOpen/KeyOpenApp.swift
git commit -m "feat: add menu-bar app shell and frontmost tracker"
```

---

### Task 10: `ScanViewModel` — OS-aware bridge to `ScanEngine`

**Files:**
- Create: `Sources/KeyOpen/ScanViewModel.swift`

**Interfaces:**
- Consumes: `SystemShortcutCollector`, `AppMenuCollector`, `ScanEngine`, `ScanResult` (Core); `NSRunningApplication` (AppKit); `AXIsProcessTrusted()` (ApplicationServices).
- Produces:
  - `@MainActor final class ScanViewModel: ObservableObject` with `@Published var result: ScanResult?`, `@Published var appName: String?`, `@Published var accessibilityGranted: Bool`, `@Published var isScanning: Bool`, and `func scan(target: NSRunningApplication?)`.
- Behavior: read `AXIsProcessTrusted()`; capture target's `localizedName` + `processIdentifier`; run `ScanEngine.run` off the main actor with a real `SystemShortcutCollector` and (only if trusted and a pid exists) an `AppMenuCollector`; publish the result on the main actor.

**Verification note:** OS bridge — validated in Task 12's dogfood pass.

- [ ] **Step 1: Write the view model**

`Sources/KeyOpen/ScanViewModel.swift`:

```swift
import AppKit
import ApplicationServices
import KeyOpenCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var appName: String?
    @Published var accessibilityGranted = true
    @Published var isScanning = false

    func scan(target: NSRunningApplication?) {
        isScanning = true
        let granted = AXIsProcessTrusted()
        accessibilityGranted = granted
        appName = target?.localizedName
        let pid = target?.processIdentifier

        Task.detached {
            let system = SystemShortcutCollector()
            let app: ShortcutCollector? = (granted && pid != nil) ? AppMenuCollector(pid: pid!) : nil
            let scan = ScanEngine.run(system: system, app: app)
            await MainActor.run {
                self.result = scan
                self.isScanning = false
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/KeyOpen/ScanViewModel.swift
git commit -m "feat: add ScanViewModel bridging OS collectors to ScanEngine"
```

---

### Task 11: `MenuContentView` — the panel UI

**Files:**
- Create: `Sources/KeyOpen/MenuContentView.swift`
- Modify: `Sources/KeyOpen/KeyOpenApp.swift` (swap the placeholder `Text` for `MenuContentView`)

**Interfaces:**
- Consumes: `ScanViewModel` (Task 10), `FrontmostTracker` (Task 9), `ScanResult`/`Binding`/`KeyCombo` (Core).
- Produces: `struct MenuContentView: View`. On appear it calls `viewModel.scan(target: tracker.lastActiveApp)`. Renders: header (app name); permission banner when `!accessibilityGranted`; an **In use** section (System group, then the app group, each row `combo.displayString` + action, conflicts marked with `⚠︎`); an **Open slots** section listing `recommendations` as `displayString`; and the honesty footnote.

**Verification note:** Rendering — validated in Task 12's dogfood pass.

- [ ] **Step 1: Write the view**

`Sources/KeyOpen/MenuContentView.swift`:

```swift
import SwiftUI
import KeyOpenCore

struct MenuContentView: View {
    @EnvironmentObject private var tracker: FrontmostTracker
    @StateObject private var viewModel = ScanViewModel()

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

    private func bindingRows(_ title: String, _ bindings: [Binding], conflicts: Set<KeyCombo>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(Array(bindings.enumerated()), id: \.offset) { _, b in
                HStack {
                    Text(b.combo.displayString).monospaced().frame(width: 80, alignment: .leading)
                    Text(b.action).lineLimit(1)
                    if conflicts.contains(b.combo) {
                        Spacer(); Text("⚠︎").help("Conflicts with another shortcut")
                    }
                }
                .font(.caption)
            }
        }
    }

    private func openSlotsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open slots").font(.subheadline).bold()
            ForEach(Array(result.recommendations.enumerated()), id: \.offset) { _, combo in
                Text(combo.displayString).monospaced().font(.caption)
            }
        }
    }
}
```

- [ ] **Step 2: Wire `MenuContentView` into the scene**

In `Sources/KeyOpen/KeyOpenApp.swift`, replace the placeholder body of the `MenuBarExtra`:

```swift
        MenuBarExtra("KeyOpen", systemImage: "keyboard") {
            MenuContentView()
                .environmentObject(tracker)
        }
        .menuBarExtraStyle(.window)
```

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/KeyOpen/MenuContentView.swift Sources/KeyOpen/KeyOpenApp.swift
git commit -m "feat: render In-use and Open-slots panel"
```

---

### Task 12: End-to-end dogfood pass + README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the whole app.
- Produces: a verified, documented, runnable MVP.

This is the acceptance gate. Per spec §3, validation is dogfooding: you run it and confirm it helps.

- [ ] **Step 1: Build a stable binary and launch it**

Run: `swift build -c release && .build/release/KeyOpen`
(Running the built binary directly gives TCC a stable identity to attach the Accessibility grant to, unlike ephemeral `swift run` builds.)
Expected: keyboard icon in the menu bar, no Dock icon.

- [ ] **Step 2: Grant Accessibility and confirm the permission flow**

Open the menu → you should first see the yellow **"Grant Accessibility to see this app's shortcuts."** banner and only System shortcuts listed. Click **Open Accessibility Settings**, enable `KeyOpen` (the `.build/release/KeyOpen` binary), then reopen the menu and hit the refresh button.
Expected: the banner disappears; an app section now appears.

- [ ] **Step 3: Verify against a known app**

Switch to **TextEdit** (or Safari), then open the KeyOpen menu.
Expected: the **In use** list shows TextEdit's real menu shortcuts (e.g. `⌘S Save`, `⌘B Bold`) under the app group, plus System shortcuts; **Open slots** shows ~8 combos, none of which appear in the In-use list, none single-`⌘`, and none of the reserved combos (`⇧⌘Z`, `⇧⌘A`, …). Confirm the honesty footnote is visible.

- [ ] **Step 4: Sanity-check a conflict (optional but recommended)**

If any combo is claimed by both System and the app, confirm it shows the `⚠︎` marker. (If none naturally conflict, this is informational only — do not fabricate one.)

- [ ] **Step 5: Write the README**

`README.md`:

```markdown
# KeyOpen

A macOS menu-bar helper that shows the keyboard shortcuts in use for the app
you're currently in (system shortcuts + that app's menus, conflicts flagged)
and recommends free, ergonomic key combinations you could still grab.

**Suggest-only** — it never changes any binding or system setting.

## Requirements
- macOS 13+
- Accessibility permission (to read other apps' menu shortcuts)

## Build & run
```sh
swift build -c release
.build/release/KeyOpen
```
A keyboard icon appears in the menu bar (no Dock icon). Click it to scan the
frontmost app.

## Permissions
On first run, grant Accessibility: **System Settings → Privacy & Security →
Accessibility**, and enable the `KeyOpen` binary. Without it, only system
shortcuts are shown.

## Scope & honesty
KeyOpen reports combos that are free *among what it can see*: system shortcuts
and the current app's menus. macOS does not expose third-party global hotkeys
(e.g. Raycast, Rectangle) to other apps, so those are not accounted for.

## Tests
```sh
swift test
```

## Design
See `docs/superpowers/specs/2026-07-05-macos-shortcut-helper-design.md`.
```

- [ ] **Step 6: Run the full test suite one last time**

Run: `swift test`
Expected: ALL tests PASS.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: add README and complete MVP dogfood pass"
```

- [ ] **Step 8: Update the Linear project**

Set the Linear project (`MacOS shortcut combo recommendation`, id `7e5e3db8-11b6-41ee-9d1e-537b1668418c`) status to reflect that the MVP is built, and add a short status update noting the working app + how to run it.

---

## Self-Review

**Spec coverage** (spec → task):
- §1/§3 menu-bar app, "In use" + "Open slots", suggest-only → Tasks 9, 11; non-goals enforced by Global Constraints.
- §4 `ShortcutMap` → Task 3; Collectors → Tasks 4 (system) + 6 (app menu); `Recommender` → Task 7; `MenuBarUI` → Tasks 9–11.
- §5 data flow (capture frontmost → collect → merge → render → recommend) → Tasks 8 (`ScanEngine`) + 9 (`FrontmostTracker`) + 10 (`ScanViewModel`).
- §6 recommender (taken ∪ reserved, candidate space, ranking, top ~8) → Task 7.
- §7 honesty footnote → Global Constraints + Task 11.
- §8 edge cases (no permission empty-state; system-only fallback; graceful degradation) → Tasks 10 (`granted` gate, nil app collector) + 11 (banner) + 8 (nil-app path tested).
- §9 testing (Recommender unit-tested; symbolic-hotkey parser golden-ish test; AX collectors dogfood) → Tasks 7, 4, and the Verification notes on 6/9/10/11 + Task 12.
- §10 stack/distribution → Global Constraints + Task 1.
- §11 phase-2 items → intentionally excluded.

**Placeholder scan:** no "TBD"/"handle edge cases"/"similar to Task N" — every code and test step carries full source. ✔

**Type consistency:** `ShortcutCollector.collect() -> [Binding]` used identically in Tasks 4/6/8/10; `KeyCombo(modifiers:key:)`, `Binding(combo:action:source:)`, `Source.system`/`.appMenu`, `ScanEngine.run(system:app:recommender:)`, and `Recommender.recommend(from:limit:)` signatures match across all consumers. ✔
