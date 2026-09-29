# OpenAway

A quiet, native break reminder for macOS. Free, open source, and built with
SwiftUI and AppKit, with Liquid Glass on macOS 26+ and native materials on older Macs.

OpenAway reminds you to rest your eyes, blink, and relax your posture while
respecting your work. It is an independent alternative inspired by
[LookAway](https://lookaway.com/), with original artwork and an MIT license.
No accounts, analytics, network requests, or third-party package dependencies.

## Features

- **Eye breaks and longer pauses:** choose your focus interval, break duration,
  and longer-break cadence.
- **A heads-up that waits:** a floating popup counts down from five seconds,
  then waits for five seconds without keyboard or mouse activity.
- **Automatic pauses:** meetings, video playback, idle time, sleep, screen lock,
  and selected foreground apps. Meeting and video detection use passive activity metadata.
- **Calm break screens:** blur your live desktop or choose an original grove,
  ocean, or dusk landscape. Breaks cover every connected display.
- **Gentle wellness reminders:** animated blink and posture overlays fade away
  without taking keyboard focus.
- **Native controls:** menu bar actions, two-Escape skipping, snoozing, sound cues,
  custom break messages, appearance options, and optional launch at login.
- **Local activity history:** completed breaks, rest time, a seven-day chart,
  and a daily streak.

## Build and run

Requires **macOS 13+** and Apple’s developer tools. Use **Xcode 26+** or its matching
Command Line Tools to build with Liquid Glass support; glass also requires macOS 26+ at runtime.

From a checkout:

```sh
./scripts/build-app.sh
open dist/OpenAway.app
```

If you need to install the developer tools first, run `xcode-select --install`.
To use installed Command Line Tools without changing the system’s selected Xcode:

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build-app.sh
```

The script creates `dist/OpenAway.app` and `dist/OpenAway-macos.zip`. It assembles,
signs, and archives the app in a temporary directory so Finder or cloud-sync metadata
cannot interfere with packaging. The ZIP contains the app for the architecture
of the Mac used to build it; it is not a universal binary. Build on an Intel Mac
for Intel support, or an Apple Silicon Mac for Apple Silicon support.

You can copy the app into `/Applications`. Keep it in a stable location before
enabling **Launch at login**. Local builds are ad-hoc signed and are not notarized;
Developer ID signing and notarization are separate release steps.

Open `Package.swift` in Xcode to develop the app. Use the app bundle for normal
usage and login-item support rather than the raw `swift build` executable.

## Settings and controls

The dashboard has four sections: **Overview**, **General**, **Activity**, and **About**.
All preferences live in **General**; less-used options are expandable.

- **General → Breaks:** timers, long breaks, and meeting/video pause toggles.
- **General → More pause options:** idle behavior and foreground-app exclusions.
- **General → Wellness reminders:** blink/posture intervals and previews.
- **General → Break screen:** background, custom message, and break preview.
- **Reset to Defaults:** the last option in General; preserves activity history.

The leaf icon in the menu bar provides quick actions. Closing the dashboard keeps
the timer running. Quit OpenAway to stop it.

| Shortcut | Action |
| --- | --- |
| ⇧⌘B | Start an eye break |
| ⇧⌘P | Pause or resume reminders |
| ⌘, | Open General settings |
| Esc twice within two seconds | Skip the current break |
| Esc | Close a break preview |
| ⌘Q | Quit |

Shortcuts apply while OpenAway is active. It does not install global keyboard hooks.
Holding Escape does not skip a break: two distinct presses are required. The
visible Skip button remains available.

## How breaks behave

Five seconds before a scheduled break, the top-center popup appears without
taking keyboard focus. At zero it stays at **Waiting for a pause** until you stop
typing or using the mouse for five seconds. Holding a mouse button keeps it waiting.
**Start now** begins immediately; **+1m**, **+5m**, and **+15m** delay the break.
Even a late timer callback gives you the full five-second warning.

During focus, delaying a break adds time to the remaining countdown. During a
break, **Snooze 5 min** ends it early and schedules another in five minutes.
Skipped and snoozed breaks do not count as completed breaks. Only completed eye
breaks advance the longer-break cadence; a completed long break resets that cycle.

Idle time can freeze or reset the focus timer, depending on your preference.
Inactivity during a break does not interrupt it. Sleep and screen lock freeze an
active break. A manual pause remains in effect over automatic pauses.
Previews do not change the timer or create activity records.

## Privacy and limitations

Preferences and up to 20,000 break records stay in the local
`org.openaway.OpenAway` UserDefaults domain. **About** includes an action to clear
history. The timer starts fresh when the app launches; preferences and history persist.

OpenAway reads input-idle timing, mouse-button state, foreground-app identity,
and microphone/camera/audio activity metadata. It does not read typed text or
capture your screen, camera, or microphone. Desktop blur uses `NSVisualEffectView`
and does not require Screen Recording permission.

Meeting/video detection is a heuristic. Muted video or a fully muted meeting with
no camera can be missed; browser music or an idle audio stream can trigger a pause.
On macOS 14.2+, audio activity is associated with known browser, player, and meeting
processes; older versions use device activity and the foreground app. Detection
polls every two seconds and holds a pause for five seconds to avoid rapid switching.
Disable either option in **General → Breaks**, or use manual pauses and app exclusions.
Starting a break manually overrides meeting/video detection for that break.

Wellness reminders fade after seven seconds. Reduce Motion disables symbol movement
and sliding; system accessibility settings also control transparency.

iPhone/iPad sync, Live Activities, calendar scheduling, custom audio/image imports,
and AppleScript/Shortcuts automation are not implemented.

## Development and verification

```sh
# Standard XCTest suite, using full Xcode:
swift test

# The same core test bodies, using Command Line Tools only:
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/test-core.sh

# Native window and behavior checks; uses temporary settings/history:
dist/OpenAway.app/Contents/MacOS/OpenAway --smoke-test
```

The core tests cover timing, pause/resume, activity waiting, long-break cadence,
snoozing, bounds, and preference migration. The native smoke test checks dashboard,
countdown, reminder, and break-window behavior. Run it from a logged-in Mac desktop.
Multiple displays and login-item approval still need manual checks.

[GitHub Actions](.github/workflows/checks.yml) is configured to test and package on
macOS 14 and macOS 26, covering native-material fallback and Liquid Glass builds.
The runner labels follow [GitHub’s supported images](https://github.com/actions/runner-images).
Each successful job uploads its app ZIP as a workflow artifact; it does not publish a release.

All artwork is drawn in code. To regenerate the icon:

```sh
swift scripts/make-icon.swift .build/AppIcon.iconset
cp .build/AppIcon.icns Resources/AppIcon.icns
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [architecture notes](docs/ARCHITECTURE.md),
and [agent.md](agent.md) for repository guidance.

## License

[MIT](LICENSE). OpenAway is not affiliated with or endorsed by LookAway or
Mystical Bits. No proprietary source, branding, or artwork is included.
