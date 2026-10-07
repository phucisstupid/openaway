import SwiftUI
import AppKit

struct ScheduleView: View {
    @ObservedObject var model: AppModel
    @ViewState private var showingReset = false
    var body: some View {
        Form {
            screenBreaks
            longBreaks
            smartPause
            excludedApps
            general
            Section {
                Button("Reset to Defaults…") { showingReset = true }
            } footer: {
                note("Restores all preferences. Your break history is kept.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
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
        Section {
            NumberPreference(title: "Show breaks after", value: $model.settings.breakIntervalMinutes, range: 1...180)
            NumberPreference(title: "Break duration", value: $model.settings.breakDurationSeconds, range: 5...600, unit: "seconds", step: 5)
        } header: {
            Text("Breaks")
        } footer: {
            note("Breaks give you a 5-second heads-up and start after 3 seconds without typing or mouse activity.")
        }
    }

    private var longBreaks: some View {
        Section("Long breaks") {
            Toggle("Include longer breaks", isOn: $model.settings.longBreakEnabled)
            NumberPreference(title: "Take a long break after", value: $model.settings.longBreakEvery, range: 1...12, unit: "eye breaks")
                .disabled(!model.settings.longBreakEnabled)
            NumberPreference(title: "Long break duration", value: $model.settings.longBreakDurationMinutes, range: 1...60)
                .disabled(!model.settings.longBreakEnabled)
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
        }
    }

    private var smartPause: some View {
        Section {
            Toggle("Pause during meetings", isOn: $model.settings.pauseForMeetings)
            Toggle("Pause while watching video", isOn: $model.settings.pauseForVideo)
            Toggle("Pause when I’m away", isOn: $model.settings.idlePauseEnabled)
            NumberPreference(title: "Idle after", value: $model.settings.idleThresholdMinutes, range: 1...60)
                .disabled(!model.settings.idlePauseEnabled)
            Toggle("Start a fresh timer when I return", isOn: $model.settings.resetAfterIdle)
                .disabled(!model.settings.idlePauseEnabled)
        } header: {
            Text("Automatic pauses")
        } footer: {
            note("Meetings use microphone or camera activity. Video detection uses audio from supported apps and browsers. Muted video can be missed, and browser audio can pause the timer.")
        }
    }

    private var excludedApps: some View {
        Section {
            if model.settings.excludedBundleIDs.isEmpty {
                Text("No apps added").foregroundStyle(.secondary)
            }
            ForEach(model.settings.excludedBundleIDs, id: \.self) { id in
                HStack {
                    Text(appName(id)).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { model.removeExcludedApp(id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).help("Remove \(appName(id))")
                        .accessibilityLabel("Remove \(appName(id))")
                }
            }
            Button { model.addExcludedApp() } label: {
                Label("Add an app…", systemImage: "plus")
            }
        } header: {
            Text("Pause in apps")
        } footer: {
            note("Pause reminders while one of these apps is in front.")
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
