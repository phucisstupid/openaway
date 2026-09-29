import SwiftUI
import AppKit

struct ScheduleView: View {
    @ObservedObject var model: AppModel
    @ViewState private var showingReset = false
    var body: some View {
        Form {
            screenBreaks
            general
            Section {
                smartPause
                wellness
                DisclosureGroup("Break screen") { ExperienceView(model: model) }
                shortcuts
            }
            Section {
                Button("Reset to Defaults…") { showingReset = true }
                note("Restores all preferences. Your break history is kept.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toggleStyle(.switch)
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .alert("Reset settings to defaults?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Defaults") { model.resetSettings() }
        } message: {
            Text("Restore the default routine, appearance, reminders, focus apps, and login preference. Your break history will be kept.")
        }
    }

    private var screenBreaks: some View {
        Section("Breaks") {
            NumberPreference(title: "Show breaks after", value: $model.settings.breakIntervalMinutes, range: 1...180)
            NumberPreference(title: "Break duration", value: $model.settings.breakDurationSeconds, range: 5...600, unit: "seconds", step: 5)
            Toggle("Pause during meetings", isOn: $model.settings.pauseForMeetings)
            Toggle("Pause while watching video", isOn: $model.settings.pauseForVideo)
            DisclosureGroup("Long breaks") {
                Toggle("Include longer breaks", isOn: $model.settings.longBreakEnabled)
                if model.settings.longBreakEnabled {
                    NumberPreference(title: "Take a long break after", value: $model.settings.longBreakEvery, range: 1...12, unit: "eye breaks")
                    NumberPreference(title: "Long break duration", value: $model.settings.longBreakDurationMinutes, range: 1...60)
                }
            }
            note("Breaks give you a 5-second heads-up and wait for a pause in typing or mouse activity.")
        }
    }

    private var general: some View {
        Section("Application") {
            Toggle("Launch at login", isOn: $model.settings.launchAtLogin)
            if let error = model.launchAtLoginError {
                Text(error).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Show countdown in menu bar", isOn: $model.settings.showCountdownInMenuBar)
            Toggle("Play break sounds", isOn: $model.settings.soundEnabled)
            Picker("Appearance", selection: $model.settings.appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }.pickerStyle(.menu)
        }
    }

    private var smartPause: some View {
        DisclosureGroup("More pause options") {
            Toggle("Pause when I’m away", isOn: $model.settings.idlePauseEnabled)
            if model.settings.idlePauseEnabled {
                NumberPreference(title: "Idle after", value: $model.settings.idleThresholdMinutes, range: 1...60)
                Toggle("Start a fresh timer when I return", isOn: $model.settings.resetAfterIdle)
            }
            note("Meetings use microphone or camera activity. Video detection uses audio from supported apps and browsers. Muted video can be missed, and browser audio can pause the timer.")
            note("Pause reminders while one of these apps is in front.")
            ForEach(model.settings.excludedBundleIDs, id: \.self) { id in
                HStack {
                    Text(appName(id)).lineLimit(2)
                    Spacer()
                    Button { model.removeExcludedApp(id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).accessibilityLabel("Remove \(appName(id))")
                }
            }
            Button("Add an app…") { model.addExcludedApp() }
        }
    }


    private var wellness: some View {
        DisclosureGroup("Wellness reminders") {
            Toggle("Remind me to blink", isOn: $model.settings.blinkReminderEnabled)
            if model.settings.blinkReminderEnabled {
                NumberPreference(title: "Blink reminder every", value: $model.settings.blinkIntervalMinutes, range: 1...60)
            }
            HStack {
                Text("A gentle blink animation").foregroundStyle(.secondary)
                Spacer()
                Button("Preview") { model.previewReminder(.blink) }
            }
            Toggle("Remind me to check my posture", isOn: $model.settings.postureReminderEnabled)
            if model.settings.postureReminderEnabled {
                NumberPreference(title: "Posture reminder every", value: $model.settings.postureIntervalMinutes, range: 1...180)
            }
            HStack {
                Text("A small posture animation").foregroundStyle(.secondary)
                Spacer()
                Button("Preview") { model.previewReminder(.posture) }
            }
            note("Floating reminders fade away without taking keyboard focus and stay quiet while breaks are paused.")
        }
    }


    private var shortcuts: some View {
        DisclosureGroup("Keyboard shortcuts") {
            shortcut("Take an eye break", keys: "⇧⌘B")
            shortcut("Pause or resume", keys: "⇧⌘P")
            shortcut("Open settings", keys: "⌘,")
            shortcut("Quit OpenAway", keys: "⌘Q")
            shortcut("Skip break", keys: "Esc, Esc")
            shortcut("Close preview", keys: "Esc")
            note("Skipping requires two distinct Escape presses within 2 seconds.")
        }
    }


    private func shortcut(_ title: String, keys: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func appName(_ bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent ?? bundleID
    }
}

func pageHeading(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.largeTitle.bold())
        Text(subtitle).foregroundStyle(.secondary)
    }
}
