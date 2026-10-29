# KeyOpen on the Mac App Store

Everything the App Store submission needs, in the order you'll need it. The
edition itself, and why it reads less than the direct download, is described in
[DISTRIBUTION.md, Tier 5](DISTRIBUTION.md#tier-5--mac-app-store-edition-sandboxed).
Tracked in THE-280.

## 1. Account setup (Hansee, in App Store Connect)

- [x] **Agreements, Tax and Banking:** accept the **Paid Apps agreement** and fill in tax
      and bank details. KeyOpen is free, but the tip jar is an in-app purchase.
- [ ] **Certificates, Identifiers & Profiles** (developer.apple.com):
  - [x] Register the App ID `com.theautonomes.keyopen` (explicit, macOS). In-App
        Purchase is on by default.
  - [x] Create an **Apple Distribution** certificate and a **Mac Installer
        Distribution** certificate, and install both in the keychain on this Mac.
  - [x] Create a **Mac App Store** provisioning profile for that App ID ("KeyOpen Mac
        App Store") and download it. Xcode → Settings → Apple Accounts → the team →
        Download Manual Profiles puts it in
        `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.
- [x] **New app** in App Store Connect: platform macOS, name KeyOpen, bundle ID
      `com.theautonomes.keyopen`, SKU `keyopen-mac`. Apple ID `6828271124`.
- [x] **In-app purchases:** three consumables, created 2026-10-28 (all 175 regions, English text). Each still needs an App Review screenshot of the tip window, which can only be taken from a TestFlight build. The names are sizes of thanks, so no
      price can contradict them (Hansee's pick, 2026-10-28):

      | Product ID | Reference / display name | US price |
      |---|---|---|
      | `com.theautonomes.keyopen.tip.thanks` | Thanks | $0.99 |
      | `com.theautonomes.keyopen.tip.bigthanks` | Big thanks | $4.99 |
      | `com.theautonomes.keyopen.tip.hugethanks` | Huge thanks | $9.99 |

      The ids must match `TipCatalog` in the code. The first in-app purchases are
      submitted together with the first build.

### Status (2026-10-28)

Entered in App Store Connect: version **0.2.3** (it must equal the build's
`CFBundleShortVersionString`), promotional text, description, keywords, support and
marketing URLs, copyright, App Review notes, manual release, subtitle, categories
(Productivity / Utilities), content rights (no third-party content), age rating 4+,
price Free in 175 regions, privacy policy URL, and the "Data Not Collected" answers.

Left before **Submit for Review**:
1. **Publish** the App Privacy answers. It's a legal confirmation, so Hansee clicks it.
2. **App Review contact** (name, phone, email) on the version page. Personal details, Hansee's to enter.
3. **Screenshots** (§4).
4. **Upload a build** (§2), then in TestFlight buy each tip with a sandbox account and take the
   in-app purchase review screenshots.
5. Attach the build and the three in-app purchases to version 0.2.3, then submit.

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
| Support URL | https://www.theautonomes.ai/keyopen/support |
| Marketing URL | (empty) |
| Privacy Policy URL | https://www.theautonomes.ai/keyopen/privacy |
| Age rating | 4+ (no objectionable content in any category) |
| App Privacy | Data Not Collected |
| Copyright | 2026 The Autonomes |

The listing points only to /keyopen/support and /keyopen/privacy, never to /keyopen:
that page has the Buy Me a Coffee button and the direct download, and a listing may
not lead to other ways to pay or to get the app. For the same reason the App Store
edition itself opens no outside links.

**Promotional text** (170, can change without a review):

> Setting up a new shortcut? KeyOpen shows which combos are already taken on your Mac, and ranks the ones still free.

**Description** (opens with a statement, not a question, and names no other apps; Hansee, 2026-10-28):

> KeyOpen shows which keyboard shortcuts are already taken on your Mac, and ranks the comfortable combinations still free. Open it in one click from the menu bar, or from any app with ⌃⌥⌘K, right when a shortcut field is waiting.
>
> WHAT IT CHECKS
> • macOS's own keyboard shortcuts
> • Global hotkeys of the other apps you have running
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

> hotkey,conflict,keybinding,key combination

Only what a person who needs KeyOpen would search for, and that isn't already
in the name or subtitle. Apple indexes those too, so "keyboard", "shortcuts" and
"free" are already covered. No other apps' names and no generic words like
"productivity": they add noise, not matches (Hansee, 2026-10-28).

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
