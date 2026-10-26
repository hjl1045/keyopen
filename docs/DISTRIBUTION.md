# Distributing KeyOpen

KeyOpen already *is* a real macOS app — `scripts/package.sh` produces
`KeyOpen.app`, a normal double-clickable, menu-bar app bundle with an icon.
This doc covers getting it onto other machines, from "just my other Mac" up to
"publish it on Homebrew."

The tiers differ only in **how much code-signing you do**, which decides how much
Gatekeeper friction the recipient hits.

---

## Tier 1 — This machine (done)

```sh
./scripts/package.sh
open KeyOpen.app          # or double-click; mv to /Applications to keep it
```

The app is **ad-hoc signed**, which is enough to run on the machine that built
it, and keeps the Accessibility grant stable across rebuilds.

## Tier 2 — Another Mac you own (has Xcode / Swift)

Same as Tier 1, on that machine:

```sh
git clone <this repo>
cd keyopen
./scripts/package.sh && open KeyOpen.app
```

Needs the Swift toolchain (Xcode or the Command Line Tools). Re-grant
Accessibility on that Mac the first time.

## Tier 3 — A Mac without the toolchain (hand off the built app)

Build once, ship the bundle:

```sh
./scripts/release.sh          # builds KeyOpen.app and zips it to dist/KeyOpen-<ver>.zip
```

Transfer `dist/KeyOpen-<ver>.zip`, unzip, and drag `KeyOpen.app` to
`/Applications`. Because it's **ad-hoc signed (not notarized)**, macOS Gatekeeper
will flag it as coming from an "unidentified developer" on a machine that didn't
build it. The recipient clears it one of two ways:

- **Right-click → Open** the first time (then "Open" in the dialog), or
- `xattr -dr com.apple.quarantine /Applications/KeyOpen.app`

This is fine for yourself or a few trusting users. It does **not** scale to
public distribution — for that, notarize (Tier 4).

## Tier 4 — Public distribution / Homebrew

Yes, you can ship this on Homebrew. GUI `.app`s go through a **Homebrew Cask**.
The one real cost is **notarization** so users don't fight Gatekeeper.

### 4a. Sign + notarize (one-time setup, ~$99/yr Apple Developer Program)

```sh
# Sign with your Developer ID (not ad-hoc):
codesign --force --deep --options runtime \
  --sign "Developer ID Application: Your Name (TEAMID)" KeyOpen.app

# Zip and notarize:
ditto -c -k --keepParent KeyOpen.app KeyOpen.zip
xcrun notarytool submit KeyOpen.zip --apple-id you@example.com \
  --team-id TEAMID --password <app-specific-password> --wait

# Staple the ticket so it works offline:
xcrun stapler staple KeyOpen.app
```

Without notarization you *can* still publish a cask, but users must pass
`--no-quarantine` or right-click-Open — not a good public experience, and the
official `homebrew-cask` repo won't accept it.

### 4b. Host a release (on theautonomes.ai)

Releases live on the company site, not GitHub Releases. `./scripts/release.sh`
signs with the Developer ID, notarizes, staples, and writes
`dist/KeyOpen-<version>.zip`. Then, in `Websites/autonomes-web`:

1. Copy the zip to `public/downloads/`.
2. Add the release to the **top** of `public/keyopen/releases.json`:
   `version`, `date`, `title`, `notes`, and `download`. Write notes for users of
   the tool: spell out only changes to finding free shortcuts (a new app's
   hotkeys read, better suggestions, a clearer panel). Anything around it,
   like the About window, feedback, tipping, launch at login or update
   notices, is "Bug fixes and improvements". The `title` follows the same rule.
3. Merge. Vercel deploys, and `/keyopen` shows the new download and notes.

That same `releases.json` is the app's update feed. The app compares the highest
`version` there to its own `CFBundleShortVersionString` (bump it in
`scripts/package.sh` before building). The panel's "KeyOpen 0.2.0 is out — …"
line uses the `title`. Check a release the way a downloader sees it:

```sh
curl -sO https://www.theautonomes.ai/downloads/KeyOpen-<version>.zip
ditto -x -k KeyOpen-<version>.zip out && spctl --assess --type execute -v out/KeyOpen.app
```

"Buy me a coffee" in the app opens the KeyOpen page, whose own button links to
the tip page through `/keyopen/coffee`, a redirect in the site's `vercel.json`.
Change the redirect's destination to change the tip service. 0.2.0–0.2.2 open
that redirect directly, so keep it.

### 4c. Publish a cask (your own tap is easiest)

Create a GitHub repo named **`homebrew-tap`** under your account and add
`Casks/keyopen.rb`:

```ruby
cask "keyopen" do
  version "0.1.0"
  sha256 "PUT_THE_SHASUM_HERE"

  url "https://www.theautonomes.ai/downloads/KeyOpen-#{version}.zip"
  name "KeyOpen"
  desc "Menu-bar helper that shows in-use keyboard shortcuts and recommends free ones"
  homepage "https://github.com/hjl1045/keyopen"

  app "KeyOpen.app"

  caveats <<~EOS
    KeyOpen needs Accessibility permission to read other apps' menu shortcuts:
    System Settings → Privacy & Security → Accessibility → enable KeyOpen.
  EOS
end
```

Then anyone installs it with:

```sh
brew install --cask hjl1045/tap/keyopen
```

Later, submitting to the **official** `homebrew-cask` repo is possible once the
project has some traction (they have notability guidelines) — but a personal tap
works immediately and identically for users who know the tap name.

---

## Tier 5 — Mac App Store edition (sandboxed)

```sh
./scripts/package.sh --sandbox   # → "KeyOpen Sandbox.app", its own bundle id, sandboxed
```

The App Store requires App Sandbox, where `~` is the app's own container. The
same binary detects that at runtime (`APP_SANDBOX_CONTAINER_ID`) and changes
three things:

- **Preferences come from files.** The user grants `~/Library` once through an
  open panel (`files.user-selected.read-only`); the choice is kept as a
  security-scoped bookmark that reopens without asking. Plists are then read
  from disk (`PreferenceStore.files`) instead of through `UserDefaults`. Tested
  2026-10-25: it reads the same system shortcuts and global hotkeys as the
  direct build.
- **No current-app menus.** Accessibility can be granted (the user must add the
  app with **+** in System Settings, because the sandbox suppresses the prompt),
  but reading another app's menu bar still fails with `-25204` (cannotComplete).
  Apple DTS confirms sandboxed apps can't read other processes this way. That
  section of the panel stays empty in this edition.
- **No update check.** The App Store updates its own apps.

No temporary-exception entitlements: App Review rejects them.



Symptom: System Settings shows KeyOpen **enabled** under Accessibility, but the
app still says *"Grant Accessibility…"*.

Cause: ad-hoc signing gives the app an identity that is just its code hash, which
changes on every rebuild. macOS ties the grant to that hash, so a rebuilt app no
longer matches the authorized one — the Settings entry goes stale.

Fix: sign with a **stable** identity. `package.sh` does this automatically if you
have any code-signing certificate — an Xcode **Apple Development** cert works
(override with `CODESIGN_IDENTITY="…"`). With no cert at all,
`./scripts/setup-signing.sh` creates a local self-signed one (you may have to
trust it for code signing in Keychain Access). Either way, once the identity is
stable the grant persists across rebuilds. To clear an already-stale entry:

```sh
tccutil reset Accessibility com.hjl1045.KeyOpen
```

then relaunch and grant once more. Note: whenever the signing identity *changes*
(e.g. ad-hoc → self-signed, or later self-signed → Developer ID), you re-grant
that one time.

## Summary

| Goal | What you do | Gatekeeper |
|------|-------------|-----------|
| Run here | `package.sh` (ad-hoc) | none |
| Your other Macs | build there, or ship zip + unquarantine | right-click-Open |
| A few users | `release.sh`, send zip | right-click-Open |
| Public / Homebrew | Developer ID sign + notarize + cask | none |
