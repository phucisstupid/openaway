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
state. It requires five seconds without activity and does not install an event tap
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

Blur mode uses an active `NSVisualEffectView` with `behindWindow` blending in clear,
nonopaque break windows. The desktop is never captured. The message and countdown
sit in the center, with glass actions along the bottom. The top-center reminder panel cannot become key or main, keeping
the foreground application's typing focus throughout the warning and wait.

The dashboard uses `NSSplitViewController` with a full-height sidebar
`NSSplitViewItem`, compact settings groups, and Swift Charts. AppKit owns the
sidebar material, rounded glass on macOS 26+, and native window-control layout.
The compact sidebar uses a native SwiftUI `List(selection:)` with `.sidebar`
style for Overview, General, Activity, and About. macOS owns selection
highlighting, keyboard navigation, and row insets. General contains all
preferences in a native grouped `Form`; less-used options use native
`DisclosureGroup` controls. The default window expands to
1200 by 900 points, bounded by the screen's available area. The selected sidebar
row identifies the current section without a repeated header in the detail pane.
Both panes remain scrollable with hidden scroll indicators. Reset to Defaults is
the final option in General and preserves break history.
Liquid Glass uses the system glassEffect/button APIs on macOS 26+, with native
material/control fallbacks. SwiftUI views observe `AppModel`. Shared colors and original vector landscapes
live in `Theme.swift`. Custom message editing uses a draft committed on submission
or focus loss, so validation does not interfere with typing spaces.

## Verification

The XCTest suite exercises the pure core with synthetic dates. `test-core.sh`
executes those same test bodies with a Foundation assertion adapter when the
installed Command Line Tools do not include XCTest. It fails on any assertion
or undiscoverable test class; it is not a general-purpose XCTest replacement.

The bundled executable's `--smoke-test` uses transient settings/history and checks
real dashboard, reminder, and overlay lifecycles. It also simulates sleep, lock,
and foreground exclusion transitions. ActivityMonitor uses passive CoreAudio/AVFoundation metadata; video classification
is an audio-based heuristic, with known limits documented in README. The floating
reminder panel fades/slides without activation and honors Reduce Motion.

Actual multi-monitor hardware behavior and
login-item approval still need manual validation on supported macOS versions.
