# Contributing to OpenAway

OpenAway is a small, native macOS app built with SwiftUI and AppKit. It has no
third-party package dependencies. macOS 13 or later is supported at runtime. Build with Xcode 26 or its
matching Command Line Tools to include Liquid Glass.

1. Build the app with `./scripts/build-app.sh`.
2. Run `swift test` for the deterministic timer tests.
3. Launch `dist/OpenAway.app` and verify the affected flow.

With Command Line Tools only, run `./scripts/test-core.sh` instead of `swift test`.
Use `DEVELOPER_DIR=/Library/Developer/CommandLineTools` before either script if
you need to override the selected Xcode without changing system settings.

Keep timer behavior in `OpenAwayCore` so it can be tested with explicit dates.
Native window lifecycle, system integration, and persistence belong in the
`OpenAway` executable target. The interface uses shared styles in `Theme.swift`.

For changes to scheduling, test pause/resume, a delayed tick, snoozing, and long
break cadence. For break-window changes, verify double-Escape dismissal, multiple
monitors when available, and returning focus to the prior app. Keep previews
independent of activity records.

Prefer native APIs, preserve keyboard access, and keep the app usable without
accounts or network access. Do not add telemetry, copied proprietary assets,
or new dependencies without discussing the need in your proposed change.

See [AGENTS.md](AGENTS.md) for the behavior and native UI conventions to preserve.
Please include a description of the behavior being fixed or added, the macOS
version used, and the checks you ran. Contributions are made under the MIT license.
