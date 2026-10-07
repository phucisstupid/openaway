# Architecture

OpenAway has two Swift Package Manager targets and no external dependencies.

## Timer engine

`OpenAwayCore` depends only on Foundation. `AppSettings` owns the version-tolerant
Codable preferences and validates ranges. `BreakEngine` is a value-type state
machine with four phases: focusing, preparing, resting, and paused.

The engine accepts an explicit date for every transition. Active timers use a
deadline, rather than subtracting one second for each callback. A late callback
therefore updates the countdown accurately. Pausing stores the remaining duration
and suspended phase. Completion starts the next focus interval at the observed time,
so a delayed callback never creates a burst of missed breaks.

Scheduled breaks always enter a five-second preparing phase, including after a
late callback. `tick` and `resume` accept an `allowAutomaticBreak` input from the
host. At zero, preparing remains active until that input allows a break; only then
does the full rest duration begin. Explicit manual breaks bypass this gate.

Transitions return events for heads-up, break start, and break end. Incomplete
breaks are recorded separately from completed breaks. Only completed short breaks
advance the longer-break cadence. The engine has no knowledge of windows, system
idle time, sound, or persistence.

## Application model

`AppModel` runs on the main actor. A half-second pulse advances the engine and
publishes state for the views. It converts system conditions into pause reasons,
with system/display sleep, screen lock, and manual pause taking priority over
foreground-app exclusion, meeting/media activity, and idle detection. Idle detection is disabled during
rest, since looking away is the purpose of a break.

The automatic-break gate uses public CoreGraphics input-idle timing and mouse-button
state. It requires three seconds without activity and does not install an event tap
or read keys. The advance popup is derived from the preparing phase, so it persists
through activity and returns after pause or preview. Wellness reminders retain their
separate seven-second expiry.

Settings and bounded history are JSON-encoded into the app's UserDefaults domain.
The launch-at-login setting uses ServiceManagement; failures are exposed in
General → Application. A preview is independent presentation state and does not alter
the timer or create activity records.

## Native presentation

`AppDelegate` owns the menu bar item, dashboard window, reminder panel, and an
overlay window per display. Overlay windows join Spaces and support native
full-screen apps. Two distinct Escape presses within two seconds, or the visible Skip button, allow dismissal. The prior
application is restored after the break when appropriate. Changes to the display
configuration rebuild overlays.
The status menu opens General through Settings and labels its reminder toggle
Pause or Resume. It has no duplicate Open OpenAway command.

Blur mode uses an active `NSVisualEffectView` with `behindWindow` blending in clear,
nonopaque break windows. The desktop is never captured. The message and countdown
sit in the center, with glass actions along the bottom. The top-center reminder panel cannot become key or main, keeping
the foreground application's typing focus throughout the warning and wait.
Its SwiftUI content uses an active control appearance so enabled buttons stay
readable even though the panel does not take focus.
The warning's native buttons also highlight on hover, with animation disabled
when Reduce Motion is enabled.

Desktop blur is the default background; removed landscape themes migrate to it.
Legacy wallpaper preferences migrate to Image. Legacy User Image preferences
migrate to Image with zero blur to preserve their sharp appearance. Image applies
a saved blur radius from 0–80 points, defaulting to 32; zero keeps the image sharp.
It does not read system wallpaper or capture the screen.
The native image picker validates images with AppKit and atomically saves a local
copy in the app's Application Support directory. The settings store its path and
original name, and `AppModel` caches the decoded image. `BreakBackgroundView` fills
each break overlay's display and dims pictures for text contrast. The native image
smoke check uses the same renderer. Missing pictures fall back to desktop blur.
Removing a picture or resetting settings clears the cached image and local copy.

The dashboard uses `NSSplitViewController` with a full-height sidebar
`NSSplitViewItem`, compact settings groups, and Swift Charts. AppKit owns the
sidebar material, rounded glass on macOS 26+, and native window-control layout.
The compact sidebar uses a native SwiftUI `List(selection:)` with `.sidebar`
style for General, Wellness Reminders, Appearance, Keyboard Shortcuts, Activity,
and About. General is the startup and default page.
Standard `Label` controls use SF Symbols with system icon sizing and row spacing;
macOS owns selection highlighting, keyboard navigation, and row insets. General
contains routine and application preferences in a native grouped `Form`, with all
sections expanded. Wellness Reminders sits directly below General in the sidebar
and contains separate Blink and Posture sections with toggles, intervals, and
previews in its own grouped form. Dependent controls stay visible and are disabled
when their feature is off.
Numeric rows use native `LabeledContent` for label alignment.
Appearance contains native segmented controls for Mode (System/Light/Dark) and
Background (Blur Desktop/Image), plus the message and preview.
Image shows choose/change image controls and a native slider that updates the blur
live and saves the selected amount.
Keyboard Shortcuts lists the app's
commands in their own grouped forms. About shows the app identity, version from
the bundle, a short description, and a native link to the OpenAway GitHub repository.
Activity uses a native grouped `Form`: Summary shows completed breaks today,
rest time today, and the current streak; Last 7 days shows a completed-break chart;
Recent breaks shows the latest eight records with aligned duration and status.
Totals count completed breaks, while recent history also includes breaks ended
early. The final form group contains Clear History…, which requires destructive
confirmation and is disabled when history is empty.
The default window expands to
1200 by 900 points, bounded by the screen's available area. It opens centered when
no frame is saved and restores the user's saved position otherwise. Frame autosaving
starts after content setup and initial positioning so layout cannot save a temporary
frame before centering. The selected sidebar
row identifies the current section without a repeated header in the detail pane.
The sidebar, settings pages, and Activity remain scrollable; compact About centers
its content in the full detail pane. General and Activity use the system scroll
indicator. Reset to Defaults is the final option in General and preserves break history.
Liquid Glass uses the system glassEffect/button APIs on macOS 26+, with native
material/control fallbacks. SwiftUI views observe `AppModel`. Shared colors and background renderers
live in `Theme.swift`. Custom message editing uses a draft committed on submission
or focus loss, so validation does not interfere with typing spaces.
The dashboard window ends native field editing on outside clicks without
consuming the click, so blank space clears focus and controls remain responsive.

## Verification

The XCTest suite exercises the pure core with synthetic dates. `test-core.sh`
executes those same test bodies with a Foundation assertion adapter when the
installed Command Line Tools do not include XCTest. It fails on any assertion
or undiscoverable test class; it is not a general-purpose XCTest replacement.

The bundled executable's `--smoke-test` uses transient settings/history and checks
real dashboard, reminder, and overlay lifecycles, including first-open centering
with a temporary frame autosave name and position preservation on reopening. It also
simulates sleep, lock, and foreground exclusion transitions. ActivityMonitor uses
passive CoreAudio/AVFoundation metadata; video classification
is an audio-based heuristic: muted video can be missed, while browser audio can
pause reminders. The floating
reminder panel fades/slides without activation and honors Reduce Motion.

Actual multi-monitor hardware behavior and
login-item approval still need manual validation on supported macOS versions.

## Releases

`release.yml` checks out the explicit tag ref, verifies its version, and tests the app on `macos-26`. It uses
`./scripts/build-app.sh` for a native arm64 build, verifies its architecture and
signature, and names the archive `OpenAway-macos-arm64.zip`. It then runs the
same script with `--universal` to produce `OpenAway-macos-universal.zip` and
publishes both ZIPs with their SHA256 files.
A separate `create-dmg` job downloads and verifies the universal ZIP, then uses
the latest published `create-dmg/create-dmg` release, resolved at packaging time,
to package the same ad-hoc signed app in
`OpenAway-macos-universal.dmg`. The shell tool receives a staging folder containing
only the app; it sets a Finder layout with the app and an Applications shortcut.
It verifies the mounted signature,
arm64/x86_64 architectures, and Applications link before uploading the DMG and
its SHA256 without overwriting existing assets. A `dmg_only` manual dispatch adds
these assets to an existing release without rebuilding or replacing the ZIP.
Recovery accepts the legacy `OpenAway-macos.zip` name and refuses to overwrite
either legacy or explicitly named universal DMG assets.
Local builds continue to produce only the app and ZIP.

A dependent cask job on `macos-26` checks out the default branch,
downloads the published arm64 ZIP and checksum, and verifies the checksum,
bundle version, signature, and exact arm64 architecture before committing the
cask version, checksum, arm64 asset URL, and Apple Silicon architecture requirement
together using the Actions token. The existing cask stays valid until the first
arm64 release supplies these assets. Both release runs and cask updates queue
pending work instead of replacing it. The cask accepts only published stable
releases; the updater compares numeric versions to skip downgrades, independently
of GitHub's Latest marker. It skips unchanged files and never force-pushes. A cask-only manual dispatch
requires the arm64 assets and can recover a failed update without changing an
existing release and performs the same bundle verification. The updater and
offline workflow checks run in branch CI and before every cask synchronization.
