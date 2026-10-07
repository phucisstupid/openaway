<img src="docs/assets/OpenAway.png" width="112" height="112" alt="OpenAway app icon">

# OpenAway

A native, open-source break reminder for macOS.

Built with SwiftUI and AppKit. No accounts, analytics, or external dependencies.

## Install

Requires **macOS 13 or later**.

Download **OpenAway-macos-universal.dmg** from [the latest release](https://github.com/phucisstupid/openaway/releases/latest).
Or install with Homebrew:

```sh
brew tap phucisstupid/openaway https://github.com/phucisstupid/openaway
brew install --cask phucisstupid/openaway/openaway
```

Homebrew installs the Apple Silicon build. The DMG supports Apple Silicon and Intel.

OpenAway is ad-hoc signed and not notarized.
If macOS blocks it, open **System Settings** > **Privacy & Security** and choose **Open Anyway**.

## Features

- Customizable eye breaks, blink and posture reminders.
- Automatic pauses for idle time, meetings, video playback, and selected apps.

Preferences and history stay on your Mac.
OpenAway does not capture screen, keyboard, camera, or microphone content.

## Development

Use Xcode or Apple's Command Line Tools on macOS:

```sh
./scripts/build-app.sh
open dist/OpenAway.app
swift test
```

With Command Line Tools only, use `./scripts/test-core.sh` instead of `swift test`.
Run `ruby scripts/test-cask.rb` and `ruby scripts/test-release.rb` to check release automation on macOS.

See [CONTRIBUTING.md](CONTRIBUTING.md) for verification and [ARCHITECTURE.md](docs/ARCHITECTURE.md) for the implementation structure.
Repository guidance lives in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE). OpenAway is an independent project, not affiliated with LookAway.
