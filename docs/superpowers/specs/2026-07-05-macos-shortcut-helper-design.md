# macOS Shortcut Helper — Design Spec

**Working name:** KeyOpen
**Date:** 2026-07-05
**Status:** Approved design → ready for implementation planning

---

## 1. Summary

A macOS **menu-bar app** that, on click, shows the keyboard shortcuts currently in
play for the app you're using, and lists the best still-free combinations you could
grab. Two sections: **"In use"** (what's taken, with conflicts flagged) and **"Open
slots"** (ranked recommendations of free, ergonomic combos).

It is **suggest-only**: it never applies a binding for you. The menu bar is purely an
accessible activation point — more reachable for a normal user than a command line.

## 2. Why build it (competitive context)

Research into the existing landscape found:

- **Visualization** (per-app cheat sheets): mature and crowded — KeyCue, KeyClu,
  KeyMinder (open source), the discontinued CheatSheet.
- **Cross-app conflict detection**: **solved** as of ~2024 by **HotkeyClash** — a free,
  open-source (GPL-2.0) menu-bar app that scans running apps' menus (Accessibility API),
  `com.apple.symbolichotkeys`, and the config files of Karabiner / skhd / Keyboard Maestro
  / BetterTouchTool, then classifies conflicts. It **explicitly does not recommend
  alternatives.**
- **Recommendation** of optimal / non-conflicting bindings: **no tool does this.** Every
  remapper (Karabiner, Keyboard Maestro, BetterTouchTool, Hammerspoon, built-in App
  Shortcuts) leaves the choice of combo entirely to the user.

**Conclusion:** discovery + conflict detection is a near-solved, open-sourced problem.
The recommendation layer is the genuine gap and the reason to build. Because this project
is open-source, HotkeyClash's proven ingestion is a resource to borrow from later (see
Phase 2), not a competitor.

## 3. Goals, non-goals, and validation

**Primary goal:** recommend good, free key combinations — the "powerhouse." Everything
else (visualization, conflict flagging) falls out of the shared data model that
recommendation requires.

**Audience:** normal macOS users (not just power users / terminal users). This raises the
UX bar but the MVP stays deliberately minimal.

**In scope (MVP):**
- Menu-bar icon → panel with **"In use"** and **"Open slots"**
- Sources: **system shortcuts** + the **frontmost app's menu shortcuts**
- **Conflict flagging** inline in "In use" (same combo claimed more than once)
- **Ranked free-combo recommendations** for the current app — suggest-only

**Explicit non-goals (cut on purpose):**
- No one-click apply / binding
- No onboarding flow
- No background watcher, notifications, or proactive nudges
- No formal automated test suite as an acceptance gate (see Validation)
- No Karabiner / Keyboard Maestro / BetterTouchTool config parsing
- No scanning of installed-but-not-running apps

**Validation:** dogfooding. Success = the author uses it and it helps. There is no formal
test rig gating the product; targeted unit tests exist only where they pay off (§9).

## 4. Architecture — one model, three thin layers

The whole system rests on a single shared model: *"what key combo is bound to what
action, in what scope."* Build that, and visualization is rendering it, conflict
detection is a query over it, and recommendation is a search of its empty space.

Four isolated, independently-testable units:

### `ShortcutMap` (core data model)
Normalized bindings with query methods. Pure data + logic, **zero macOS dependencies** —
so it (and the Recommender that consumes it) can be tested with synthetic data.

```
KeyCombo  = { modifiers: Set<Modifier>, key: Key }
Binding   = { combo: KeyCombo, action: String, source: Source }
Source    = .system | .appMenu
ShortcutMap:
    add(Binding)
    isTaken(KeyCombo) -> Bool
    conflicts() -> [(KeyCombo, [Binding])]   // combos claimed by >1 binding
    takenCombos() -> Set<KeyCombo>
```

### Collectors (ingestion)
One per source, each with the same narrow interface `collect() -> [Binding]`:

- **`SystemShortcutCollector`** — reads `~/Library/Preferences/com.apple.symbolichotkeys.plist`
  (`AppleSymbolicHotKeys`), maps known hotkey IDs → human names, emits `.system` bindings.
- **`AppMenuCollector`** — for the captured frontmost app, walks the Accessibility tree:
  `AXUIElement` app ref → `AXMenuBar` → recurse menus/submenus → read
  `AXMenuItemCmdChar`, `AXMenuItemCmdModifiers`, `AXMenuItemCmdGlyph` per item. Emits
  `.appMenu` bindings. (This automatically reflects the user's own `NSUserKeyEquivalents`
  overrides, since the live menu already incorporates them.)

### `Recommender` (the novel logic — dependency-free)
Takes a `ShortcutMap`, returns ranked free combos. No OS calls, so it's unit-testable
against a fake map. See §6.

### `MenuBarUI`
SwiftUI `MenuBarExtra`. On open: capture frontmost app → run collectors → build map →
render "In use" (grouped by source, conflicts flagged) → run Recommender → render
"Open slots."

## 5. Data flow

```
click menu-bar icon
  → capture frontmost app (NSWorkspace.frontmostApplication, at open time)
  → SystemShortcutCollector.collect()  ┐
  → AppMenuCollector.collect()         ┘→ merge → ShortcutMap
  → render "In use"      (from ShortcutMap: grouped, conflicts flagged)
  → Recommender.recommend(map)  → render "Open slots" (ranked free combos)
```

The scan is fast (one running app's menus + one plist ≈ sub-second), so it runs fresh on
each open. No caching in the MVP.

## 6. The Recommender

Because the MVP recommends free real-estate (option A — no user-supplied target action),
ranking is about **combo quality**, not mnemonic fit.

1. **Taken set** = system shortcuts ∪ current-app menu shortcuts ∪ a small
   **"conventionally reserved" list** — near-universal combos (⌘C, ⌘V, ⌘X, ⌘Z, ⌘S, ⌘Q,
   ⌘W, ⌘A, ⌘F, ⌘N, ⌘O, ⌘P, …) that are never suggested even when the current app leaves
   them free.
2. **Candidate space** = a curated set of ergonomic modifier combinations
   (e.g. ⌘⇧, ⌘⌥, ⌃⌥⌘, …) × letters/digits.
3. **Free** = candidates − taken.
4. **Rank** by a single tunable scoring function; show the top ~8. Initial heuristic:
   - Prefer fewer / easier modifier chords, up to a "safe" sweet spot (~2 modifiers).
   - Prefer one-hand reachability; penalize awkward stretches.
   - Penalize combos that fight platform conventions even if locally free.

The scoring function is intentionally one small, isolated place to tune by feel — that's
the "if it works, it works" iteration loop.

## 7. The honesty constraint

The recommender **cannot** promise "guaranteed conflict-free," because macOS does not let
one app enumerate the global hotkeys another app registered via `RegisterEventHotKey`
(Raycast, Rectangle, Alfred, etc. — hidden by design for anti-keylogging). It also cannot
read menus of apps that aren't running.

Therefore the honest promise is: **"free among what we can see — system shortcuts + this
app's menus."** This is surfaced as **one small footnote** in the UI, not a wall of
caveats.

## 8. Edge cases & error handling

- **No Accessibility permission** → `AppMenuCollector` returns empty. Show system
  shortcuts plus a single line: *"Grant Accessibility to see app shortcuts → Open
  Settings."* This is a graceful empty state, **not** an onboarding flow.
- **Frontmost app has no menu bar / is unusual** → show system-only with a short note.
- **A collector throws** → degrade gracefully; render whatever was collected.

## 9. Testing strategy

Matched to dogfood validation — tests only where they earn their keep:

- **`Recommender`** — unit tests against synthetic `ShortcutMap`s (the valuable, novel
  logic; pure, so easy to test).
- **`SystemShortcutCollector` parser** — a golden-file test against a sample
  symbolichotkeys plist.
- **Collectors touching live apps / Accessibility** — validated by dogfooding, not
  automated tests.

## 10. Tech stack & distribution

- **Language/UI:** Swift + SwiftUI `MenuBarExtra` (macOS 13+).
- **APIs:** Accessibility (`AXUIElement` from ApplicationServices) for menus;
  `CFPreferences`/plist read for system shortcuts.
- **Permissions:** requires the Accessibility (TCC) permission to read other apps' menus.
- **Distribution:** open-source repo; notarized DMG. **Not** the Mac App Store — the
  Accessibility API against other apps is incompatible with MAS sandboxing.

## 11. Phase 2 (explicitly deferred, not part of MVP)

- Parse known automation tools' configs (Karabiner / skhd / Keyboard Maestro /
  BetterTouchTool) to widen the "taken" set — this is where borrowing HotkeyClash's
  proven ingestion pays off.
- **Fill-the-gaps** recommendations (option B): tie each suggestion to an actual
  unshortcutted menu command.
- **Ask-for-an-action** recommendations (option C): a text box where you describe the
  action and get mnemonic-aware suggestions.
- One-click apply for the safe, reversible case (per-app menu shortcuts via
  `NSUserKeyEquivalents`).
```
