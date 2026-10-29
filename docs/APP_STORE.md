# KeyOpen on the Mac App Store

Everything the App Store submission needs, in the order you'll need it. The
edition itself, and why it reads less than the direct download, is described in
[DISTRIBUTION.md, Tier 5](DISTRIBUTION.md#tier-5--mac-app-store-edition-sandboxed).
Tracked in THE-280.

## 1. Account setup (Hansee, in App Store Connect)

- [ ] **Agreements, Tax and Banking:** accept the **Paid Apps agreement** and fill in tax
      and bank details. KeyOpen is free, but the tip jar is an in-app purchase.
- [ ] **Certificates, Identifiers & Profiles** (developer.apple.com):
  - [ ] Register the App ID `ai.theautonomes.KeyOpen` (explicit, macOS). In-App
        Purchase is on by default.
  - [ ] Create an **Apple Distribution** certificate and a **Mac Installer
        Distribution** certificate, and install both in the keychain on this Mac.
  - [ ] Create a **Mac App Store** provisioning profile for that App ID and download it.
- [ ] **New app** in App Store Connect: platform macOS, name KeyOpen, bundle ID
      `ai.theautonomes.KeyOpen`, SKU `keyopen-mac`.
- [ ] **In-app purchases:** three consumables, once the tip jar mockup is approved.
      Proposed: `ai.theautonomes.KeyOpen.tip.small` / `.medium` / `.large` at
      $0.99 / $2.99 / $4.99.

## 2. Build and upload

```sh
APPSTORE_PROFILE=~/Downloads/KeyOpen_Mac_App_Store.provisionprofile ./scripts/appstore.sh
```

This writes `dist/appstore/KeyOpen-<version>.pkg`, signed for the store. Upload it
with the **Transporter** app. `./scripts/appstore.sh --dry-run` builds the same
bundle without the certificates, to check its structure.

The version comes from `scripts/package.sh`, as for the direct download. Each upload
needs a build number (`CFBundleVersion`) that the store hasn't seen before.

## 3. Listing

| Field | Value |
|---|---|
| Name | KeyOpen |
| Subtitle (30) | Find free keyboard shortcuts |
| Category | Productivity (secondary: Utilities) |
| Price | Free |
| Support URL | https://www.theautonomes.ai/keyopen |
| Marketing URL | https://www.theautonomes.ai/keyopen |
| Privacy Policy URL | https://www.theautonomes.ai/keyopen/privacy |
| Age rating | 4+ (no objectionable content in any category) |
| App Privacy | Data Not Collected |
| Copyright | 2026 The Autonomes |

**Promotional text** (170, can change without a review):

> Setting up a new shortcut? KeyOpen shows which combos are already taken on your Mac, and ranks the ones still free.

**Description:**

> You're in an app's settings with a shortcut field waiting. Which combination is safe to use?
>
> KeyOpen answers in one click from the menu bar, or from anywhere with ⌃⌥⌘K. It lists the keyboard shortcuts already taken and ranks the comfortable combinations still free.
>
> WHAT IT CHECKS
> • macOS's own keyboard shortcuts
> • Global hotkeys of other running apps, including apps built with the KeyboardShortcuts library, Alfred, Keyboard Maestro and Wispr Flow
>
> WHAT YOU SEE
> • Free combinations first, best first
> • What's taken, grouped by who owns it
> • Conflicts, with which shortcut wins
>
> KeyOpen only reads; it never changes a shortcut or a setting. It collects no data: no account, no analytics, no tracking.
>
> Good to know: macOS has no way to list every hotkey apps register, so "free" means free among what KeyOpen can see. This edition doesn't read the menu commands of the app you're using, because the App Store sandbox doesn't allow it.

**Keywords** (100):

> shortcut,hotkey,keyboard,conflict,menu bar,keybinding,free,productivity,Alfred,Keyboard Maestro

Keep this copy away from the direct download. Pointing App Store customers to
another place to get the app risks a rejection, so the listing states the
limitation without naming the alternative.

## 4. Screenshots (Hansee captures; I can't take screenshots on this Mac)

16:10 at **2880×1800** (or 1440×900). Shoot on a clean desktop:

1. The panel open over a familiar app, with **Open slots** showing.
2. **In use** expanded, with a conflict note visible (⚠︎ and "Blocked by …").
3. The panel opened with ⌃⌥⌘K over an app's settings pane, where you'd actually use it.

## 5. Notes for App Review

> KeyOpen is a read-only utility. It shows which keyboard shortcuts are already taken on the Mac, so a user setting up a new shortcut can pick one that's free.
>
> Why it asks for the Library folder: macOS keeps its own keyboard shortcuts and other apps' hotkey settings in ~/Library (Preferences and Application Support). Inside the App Sandbox these aren't visible, so on first launch KeyOpen asks the user to choose their Library folder in a standard open panel (com.apple.security.files.user-selected.read-only). The choice is stored as an app-scoped security bookmark, so it's asked only once. KeyOpen only reads these files. It never writes to them and never sends them anywhere. It uses no temporary-exception entitlements and doesn't request Accessibility.
>
> How to test:
> 1. Launch KeyOpen. A keyboard icon appears in the menu bar (no Dock icon).
> 2. Click it, then "Grant Library Access…". The Library folder is preselected; click "Grant Access".
> 3. The panel lists free shortcut combinations under "Open slots", and the shortcuts in use below them.
> 4. ⌃⌥⌘K opens the same panel from any app.
>
> The tips in the ⋯ menu are optional consumable in-app purchases and unlock nothing.

## Updates

Every new version goes through App Review again. The App Store edition has no
update check of its own: the App Store delivers updates.
