# Repository guidance

Use `AGENTS.md` as the sole source of project guidance. `README.md` is a brief
project overview and installation/development guide, not an app feature reference
or instruction source. Verify implementation details against the relevant code
and configuration.

Do not edit README as part of routine feature, UI, or behavior changes. Edit it
only when the user explicitly requests a README change. Keep detailed app behavior,
UI descriptions, timing rules, and implementation notes in `AGENTS.md` or
`docs/ARCHITECTURE.md`.

OpenAway is a native macOS menu bar break reminder, built with SwiftUI, AppKit,
and Foundation. It supports macOS 13+, with Liquid Glass on macOS 26+ when built
with Xcode 26+ or matching Command Line Tools. There are no external package dependencies.

## Work in the existing structure

- `Sources/OpenAwayCore/`: deterministic timer state machine and version-tolerant
  Codable preferences. Supply explicit dates; keep platform effects out of this target.
- `Sources/OpenAway/`: main-actor app model, AppKit windows and menus, passive
  activity detection, and SwiftUI views.
- `Tests/OpenAwayCoreTests/`: XCTest tests with synthetic dates.
- `scripts/`: local packaging, the Command Line Tools test fallback, and icon generation.
- `Casks/openaway.rb`: the Homebrew cask, hosted in this repository as a tap.

Prefer existing helpers, standard-library functions, and native platform controls.
Keep changes small. Do not add speculative abstractions or dependencies.
The Command Line Tools assertion adapter exists because those tools can lack XCTest;
its test bodies come from the XCTest source files.

## Preserve the product behavior

- Keep General, Wellness Reminders, Appearance, Keyboard Shortcuts, Activity,
  and About in the compact sidebar. General is the startup and default page.
  Wellness Reminders belongs directly below General and contains all blink/posture
  toggles, intervals, and previews.
  Visual preferences belong in Appearance and shortcut help in Keyboard Shortcuts.
  Reset to Defaults remains last in General, resets all preferences, and preserves history.
  About stays compact with app identity, bundle version, and the GitHub link;
  confirmed history deletion belongs in Activity.
- Use native sidebar selection, spacing, window controls, and grouped forms. Keep
  all General and Wellness Reminders sections and dependent controls visible,
  disabling inactive fields.
  Do not add a repeated section toolbar or custom selection highlighting.
- Keep macOS 13 fallbacks for newer APIs. Use system glass effects on supported systems.
- Keep only Blur Desktop and Image backgrounds. Desktop blur is the default.
  Image uses the imported image and a saved blur amount from 0–80 points,
  defaulting to 0, adjusted live with a continuous native slider without tick marks;
  the zero endpoint is labeled None and keeps the image sharp.
  Legacy wallpaper preferences migrate to Image; User Image migrates with zero blur.
  Missing images fall back to desktop blur; do not read system wallpaper or capture
  the screen.
- Scheduled breaks show a full five-second warning, then wait for three seconds
  without typing or mouse activity. A held mouse button counts as activity.
- Reminder panels must not take keyboard focus. Blink/posture overlays and their
  previews fade after 1.5 seconds and honor Reduce Motion.
- A real break requires two distinct Escape presses within two seconds to skip;
  key repeat does not count. A preview closes with one press.
- Previews must not reset the timer or write history. Only completed short breaks
  advance the long-break cadence. Pause/resume preserves active time.
- Use passive activity metadata and public APIs. Do not capture input, screen,
  microphone, or camera content. Keep the app offline and preserve keyboard access.
- Commit custom break-message drafts on submission or focus loss; normalizing each
  keystroke would prevent typing spaces.

## Verify relevant changes

Swift formatting and style checks use the toolchain's `swift-format` and the
tracked `.swift-format` configuration. Format explicitly before staging:

```sh
xcrun swift-format format --in-place --recursive Package.swift Sources Tests scripts/make-icon.swift
xcrun swift-format lint --strict --recursive Package.swift Sources Tests scripts/make-icon.swift
```

Enable the optional native commit hook once per clone:

```sh
git config --local core.hooksPath .githooks
```

The hook lints staged Swift content using the staged configuration, preserving
partial staging without modifying files or the index. Stage `.swift-format` with
its initial formatting pass. Configuration changes check all tracked Swift files
in the index. Verify hook behavior with `./scripts/test-hooks.sh`.
CI runs strict lint and the hook checks on `macos-26`; use the same Swift toolchain
locally for consistent formatting. Hooks are optional; CI enforces the check.

With full Xcode, run `swift test`. With Command Line Tools only:

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/test-core.sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build-app.sh
```

For window or interaction changes, run from a logged-in desktop:

```sh
dist/OpenAway.app/Contents/MacOS/OpenAway --smoke-test
```

Use the `DEVELOPER_DIR` override rather than changing the system’s selected Xcode.
Run checks appropriate to the change, and report any checks you could not run.
Manually verify multiple displays and login-item approval when affected.

The build script generates the app icon from `scripts/make-icon.swift` for both
local and GitHub workflow builds. Generated `.icns` and `.iconset` files are not
tracked in Git.
The build script assembles, signs, and archives in a temporary directory to avoid
Finder/cloud metadata during signing. Generated `.build/`, `.swiftpm/`, and `dist/`
content stays out of Git. Local builds produce an app and ZIP, not a DMG.
A default build contains the host's architecture in `OpenAway-macos.zip`;
`./scripts/build-app.sh --universal` combines arm64 and x86_64 in
`OpenAway-macos-universal.zip`. Apps are ad-hoc
signed and not notarized. Publishing is handled by `.github/workflows/release.yml`
after a version tag is pushed, or by manually dispatching it for an existing tag.

For releases, keep the app version, tag, asset filename, and cask version/checksum
consistent. Verify the ZIP after extracting it into a clean temporary directory;
Finder metadata on the app copied into a synced folder can affect signature checks.

Every release must have a minimal, human-readable changelog in its annotated tag
notes. Format each changelog entry as a Markdown bullet starting with `- `;
do not use unbulleted lines. Prefer plain language; omit implementation details,
internal tooling, commit hashes, and test logs. The workflow publishes these notes as the
GitHub release changelog without appending download, system requirement, signing,
or installation boilerplate.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist`, verify, commit,
   and push the changes.
2. Push an annotated `v<version>` tag to trigger the release workflow. Tag notes
   become the release notes. On `macos-26`, the workflow uses the existing build
   script to produce and verify `OpenAway-macos-arm64.zip`, then builds the
   universal `OpenAway-macos-universal.zip`. Wait for both ZIPs,
   `OpenAway-macos-universal.dmg`, and their SHA256 files.
3. The workflow downloads the published arm64 ZIP/checksum, verifies them, and
   commits the cask's `version`, `sha256`, arm64 asset URL, and Apple Silicon
   architecture requirement together to the default branch as the Actions bot.
   It skips older releases and unchanged casks. Never use a local build's checksum
   for a workflow-built release.

Keep the current cask URL and checksum valid until an arm64 release is published;
the updater migrates the cask to Apple Silicon only when those assets exist.

The separate `create-dmg` job verifies the published ZIP, packages the same
universal app using the latest published `create-dmg/create-dmg` release as
`OpenAway-macos-universal.dmg`. Its source folder contains only `OpenAway.app`,
and its Finder layout places the app beside an Applications shortcut.
Resolve the tool's latest release at packaging time; do not pin a fixed version.
The job checks the mounted app's signature, architectures, and Applications link.
It adds DMG assets without
overwriting existing assets or changing the ZIP/cask. Dispatch `Release` with
the existing tag and `dmg_only` enabled to add a DMG without rebuilding the app
or bumping its version. Recovery also accepts the legacy universal ZIP name
`OpenAway-macos.zip` and refuses to overwrite either DMG naming scheme.

If publishing succeeds but the cask update fails, dispatch `Release` with the
existing tag and `update_cask_only` enabled. This requires that release's arm64
ZIP and checksum and does not rebuild or replace the release. Branch protection
must permit the bot's normal push; concurrent branch changes cause a visible
failure rather than a force push. Verify updater changes
with `ruby scripts/test-cask.rb`.

Update architecture notes when behavior changes. Use original artwork,
preserve the MIT license, and describe OpenAway as an independent project.
