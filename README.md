<img src="docs/assets/OpenAway.png" width="112" height="112" alt="OpenAway app icon">

# OpenAway

A native, open-source break reminder for macOS. Rest your eyes, blink, and reset
your posture without leaving your workflow.

Built with SwiftUI and AppKit. No accounts, analytics, or external dependencies.

## Install

Requires **macOS 13 or later**.

1. Download the app ZIP from [the latest release](https://github.com/phucisstupid/openaway/releases/latest).
2. Extract it and move **OpenAway.app** to **Applications**.
3. Open the app and configure your routine from the menu bar.

Or install with Homebrew:

```sh
brew tap phucisstupid/openaway https://github.com/phucisstupid/openaway
brew install --cask phucisstupid/openaway/openaway
```

Release builds are ad-hoc signed, not Developer ID signed or notarized. macOS may
block the first launch; after reviewing the download, use **System Settings >
Privacy & Security > Open Anyway** if offered.

## Features

- Customizable eye breaks and longer breaks, with a warning that waits for a pause.
- Automatic pauses for idle time, meetings, video playback, and selected apps.
- Separate blink and posture reminders that do not take keyboard focus.
- Break screens across your displays, using desktop blur, wallpaper blur, or your own image.
- Native settings, menu bar controls, and local activity history.

Preferences and history stay on your Mac. OpenAway does not capture screen,
keyboard, camera, or microphone content.

## Development

Use Xcode or Apple's Command Line Tools on macOS:

```sh
./scripts/build-app.sh
open dist/OpenAway.app
swift test
```

With Command Line Tools only, use `./scripts/test-core.sh` instead of `swift test`.
Xcode 26 or matching Command Line Tools enables Liquid Glass on macOS 26+;
older systems use native materials.

See [Contributing](CONTRIBUTING.md) for verification and
[Architecture](docs/ARCHITECTURE.md) for the implementation structure.
Repository guidance lives in [agent.md](agent.md).

## License

[MIT](LICENSE). OpenAway is an independent project, not affiliated with LookAway
or Mystical Bits.
