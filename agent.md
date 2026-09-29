# Repository guidance

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

Prefer existing helpers, standard-library functions, and native platform controls.
Keep changes small. Do not add speculative abstractions or dependencies.
The Command Line Tools assertion adapter exists because those tools can lack XCTest;
its test bodies come from the XCTest source files.

## Preserve the product behavior

- Keep Overview, General, Activity, and About in the compact sidebar. All preferences
  belong in General, with Reset to Defaults as its last option; resetting preserves history.
- Use native sidebar selection, spacing, window controls, grouped forms, and disclosure
  groups. Do not add a repeated section toolbar or custom selection highlighting.
- Keep macOS 13 fallbacks for newer APIs. Use system glass effects on supported systems.
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
content stays out of Git. A ZIP contains only the build host’s architecture, is
ad-hoc signed, and is not notarized. Publishing a release is separate from building it.

Update README and architecture notes when behavior changes. Use original artwork,
preserve the MIT license, and describe OpenAway as an independent project.
