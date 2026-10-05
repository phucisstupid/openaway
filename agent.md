# Repository guidance

Use `agent.md` as the sole source of project guidance. `README.md` is user-facing
documentation, not a project reference or instruction source. Verify implementation
details against the relevant code and configuration.

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
- Keep only Blur Desktop, Blur Wallpaper, and User Image backgrounds. Desktop blur
  is the default; wallpaper blur uses each display's public wallpaper URL, not capture.
- Scheduled breaks show a full five-second warning, then wait for five seconds
  without typing or mouse activity. A held mouse button counts as activity.
- Reminder panels must not take keyboard focus. Blink/posture overlays fade after
  seven seconds and honor Reduce Motion.
- A real break requires two distinct Escape presses within two seconds to skip;
  key repeat does not count. A preview closes with one press.
- Previews must not reset the timer or write history. Only completed short breaks
  advance the long-break cadence. Pause/resume preserves active time.
- Use passive activity metadata and public APIs. Do not capture input, screen,
  microphone, or camera content. Keep the app offline and preserve keyboard access.
- Commit custom break-message drafts on submission or focus loss; normalizing each
  keystroke would prevent typing spaces.

## Verify relevant changes

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

The build script assembles, signs, and archives in a temporary directory to avoid
Finder/cloud metadata during signing. Generated `.build/`, `.swiftpm/`, and `dist/`
content stays out of Git. A default build contains the host's architecture;
`./scripts/build-app.sh --universal` combines arm64 and x86_64. Apps are ad-hoc
signed and not notarized. Publishing is handled by `.github/workflows/release.yml`
after a version tag is pushed, or by manually dispatching it for an existing tag.

For releases, keep the app version, tag, asset filename, and cask version/checksum
consistent. Verify the ZIP after extracting it into a clean temporary directory;
Finder metadata on the app copied into a synced folder can affect signature checks.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist`, verify, commit,
   and push the changes.
2. Push an annotated `v<version>` tag to trigger the release workflow. Tag notes
   become the release notes. Wait for the workflow to publish both assets.
3. The workflow downloads the published ZIP/checksum, verifies them, and commits
   the cask's `version` and `sha256` to the default branch as the Actions bot.
   It skips older releases and unchanged casks. Never use a local build's checksum
   for a workflow-built release.

If publishing succeeds but the cask update fails, dispatch `Release` with the
existing tag and `update_cask_only` enabled. This does not rebuild or replace the
release. Branch protection must permit the bot's normal push; concurrent branch
changes cause a visible failure rather than a force push. Verify updater changes
with `ruby scripts/test-cask.rb`.

Update README and architecture notes when behavior changes. Use original artwork,
preserve the MIT license, and describe OpenAway as an independent project.
