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

## Usage
Two ways to open KeyOpen, both of which read the app you were just using:
- **Click** the menu-bar icon.
- **Press `⌃⌥⌘K`** from anywhere — a floating panel appears. Press it again (or
  close the panel) to dismiss. Handy when you're mid-setup in another app and
  want a free combo. (The hotkey also needs the Accessibility permission.)

## Permissions
On first run, grant Accessibility: **System Settings → Privacy & Security →
Accessibility**, and enable the `KeyOpen` binary. Without it, only system
shortcuts are shown. Running the built binary directly (`.build/release/KeyOpen`)
gives it a stable identity so the grant persists across launches.

## Scope & honesty
KeyOpen reports combos that are free *among what it can see*: system shortcuts
and the current app's menus. macOS does not expose third-party global hotkeys
(e.g. Raycast, Rectangle) to other apps, so those are not accounted for.

A combo whose simpler form on the same key is already used (e.g. `⇧⌘D` when
`⌘D` is bound) is still offered, but ranked below fully-clean keys and flagged
`⚠︎ … in use` — usable, but it stacks a modifier onto a key that already means
something.

## Tests
```sh
swift test
```

## Design
See `docs/superpowers/specs/2026-07-05-macos-shortcut-helper-design.md` and the
implementation plan in `docs/superpowers/plans/2026-07-05-keyopen-mvp.md`.
