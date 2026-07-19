# KeyOpen

A macOS menu-bar helper that shows the keyboard shortcuts in use for the app
you're currently in (system shortcuts + that app's menus, conflicts flagged)
and recommends free, ergonomic key combinations you could still grab.

**Suggest-only** — it never changes any binding or system setting.

## Requirements
- macOS 13+
- Accessibility permission (to read other apps' menu shortcuts)

## Build & run

### As a standalone app (recommended)
```sh
./scripts/package.sh
open KeyOpen.app          # or double-click in Finder; move to /Applications to keep it
```
This builds `KeyOpen.app`, which runs **on its own** — no terminal window to keep
open. A keyboard icon appears in the menu bar (no Dock icon). The app is ad-hoc
code-signed so its Accessibility permission sticks across rebuilds.

### From the terminal (dev loop)
```sh
swift build -c release
.build/release/KeyOpen    # runs in the foreground — closing the terminal quits it
```

## Usage
Two ways to open KeyOpen, both of which read the app you were just using:
- **Click** the menu-bar icon.
- **Press `⌃⌥⌘K`** from anywhere — a floating panel appears. Press it again (or
  close the panel) to dismiss. Handy when you're mid-setup in another app and
  want a free combo. (The hotkey also needs the Accessibility permission.)

The **↻** button in the top-right rescans on demand. Since a rescan of an
unchanged app produces identical rows, the header shows `Updated HH:MM:SS`
(and a spinner while it runs) so you can tell it actually ran.

A command listed twice under one app — a File-menu "Close window" and a
Window-menu "Close Window" are both ⌘W — is collapsed to a single row and not
flagged as a conflict. Two *different* commands on one combo still are.

## What KeyOpen can and can't see

macOS has **no API to enumerate the global hotkeys apps have registered**, so
"free" always means *free among what we can see*:

| Source | How |
|---|---|
| System shortcuts | `com.apple.symbolichotkeys` preferences |
| The current app's menu commands | Accessibility, walking its menu bar |
| Global hotkeys of Swift apps | the `KeyboardShortcuts` library's stored prefs |
| Global hotkeys of known config-file apps | reading that app's own config |

A global hotkey belonging to the app you're currently in is listed **in that
app's own section**, not under "Global hotkeys (other apps)" — from where you're
sitting, Wispr Flow's ⇧⌘U is Wispr Flow's.

That last row needs a reader per app, since there's no shared format — three
apps, three encodings, none of them the same:

| App | Where | Encoding |
|---|---|---|
| **Wispr Flow** | `~/Library/Application Support/Wispr Flow/config.json` | `+`-joined virtual key codes with modifiers as codes of their own: `"32+55+56": "popo"` = ⇧⌘U |
| **Keyboard Maestro** | `~/Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist` | per-macro `HotKey` triggers as a Carbon key code + **Carbon** modifier mask: `{KeyCode: 18, Modifiers: 6400}` = ⌃⌥⌘1 |
| **Alfred** | `…/Alfred/Alfred.alfredpreferences/preferences/local/<localhash>/…/prefs.plist` | `{key: 49, mod: 1048576, string: " "}` — Carbon key code but a **Cocoa** `NSEvent` mask, the one macOS uses in `com.apple.symbolichotkeys` |

Only apps that are *running* are read, since a global hotkey is only live while
its owner is — and it's the process that registers them that has to be running,
which for Keyboard Maestro is its background *engine*, not the editor. Macros and
macro groups that are switched off are skipped; ones scoped to a single app are
not, because a slot that's taken whenever that app is frontmost isn't free.

Apps using the `KeyboardShortcuts` library need no reader of their own — the row
above them already covers them (**superwhisper** is one: its push-to-talk lives
in `~/Library/Preferences/com.superduper.superwhisper.plist` as
`KeyboardShortcuts_pushToTalk`).

Three apps checked and deliberately *not* read, because nothing on disk says
what their hotkeys are: **Discord** (keybinds are stored server-side with the
account; the local `settings.json` holds only window state), **Slack** (nothing
written until first launch), and **Telegram** (its prefs contain no shortcut
keys; the rest of its state is an encrypted store). Guessing at those would be
worse than missing them.

Adding another app means adding a decoder in
[`AppConfigHotkeyCollector.swift`](Sources/KeyOpenCore/AppConfigHotkeyCollector.swift),
and a decoder only ships once its format is confirmed against a real file — each
one has a test that reads the actual file on this machine and skips where the app
isn't installed. It's worth the tedium: a hotkey we can't see doesn't just go
unlisted, it gets **recommended as a free slot** — the one answer this app must
not get wrong.

## Permissions
On first run, grant Accessibility: **System Settings → Privacy & Security →
Accessibility** (the *privacy* pane that lists apps allowed to control your Mac —
**not** the separate Accessibility *features* pane), and enable **KeyOpen**.
Without it, only system + other-app global-hotkey shortcuts show (reading the
current app's menus needs it).

**Keeping the grant across rebuilds.** `package.sh` signs with a *stable*
code-signing identity when you have one — an Xcode **Apple Development**
certificate is picked up automatically (or set `CODESIGN_IDENTITY="…"` to choose).
With a stable identity the Accessibility grant persists across rebuilds. If you
have **no** signing cert, the app falls back to *ad-hoc*, whose code hash changes
every build, so macOS **resets the grant each rebuild** (Settings shows it enabled
while the app reports "not granted" — a stale entry); `./scripts/setup-signing.sh`
can create a local identity for that case. To clear a stale entry:
```sh
tccutil reset Accessibility com.hjl1045.KeyOpen
```

## Scope & honesty
KeyOpen reports combos that are free *among what it can see*: system shortcuts,
the current app's menus, and the global hotkeys of other **running** apps that it
can recover from their preferences (apps using the popular `KeyboardShortcuts`
library store them readably) or from their own config files (Wispr Flow,
Keyboard Maestro, Alfred). macOS does not let one app *enumerate* another's
global hotkeys, so apps that use other mechanisms (raw `RegisterEventHotKey`,
`MASShortcut`, an unread config file, sandboxed prefs) can still be missed.

A combo whose simpler form on the same key is already used (e.g. `⇧⌘D` when
`⌘D` is bound) is still offered, but ranked below fully-clean keys and flagged
`⚠︎ … in use` — usable, but it stacks a modifier onto a key that already means
something.

## Tests
```sh
swift test
```

## Installing elsewhere / publishing
See **[docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)** for porting to another Mac,
handing off the built app, and publishing via a Homebrew cask (`release.sh`
builds a distributable zip). The app icon is generated by `scripts/make-icon.swift`
and embedded automatically during packaging.

## Design
See `docs/superpowers/specs/2026-07-05-macos-shortcut-helper-design.md` and the
implementation plan in `docs/superpowers/plans/2026-07-05-keyopen-mvp.md`.
