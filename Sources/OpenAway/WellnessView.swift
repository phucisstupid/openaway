import SwiftUI

struct WellnessView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to blink", isOn: $model.settings.blinkReminderEnabled)
                NumberPreference(
                    title: "Blink reminder every", value: $model.settings.blinkIntervalMinutes, range: 1...60
                )
                .disabled(!model.settings.blinkReminderEnabled)
                Button {
                    model.previewReminder(.blink)
                } label: {
                    Label("Preview blink reminder", systemImage: "play")
                }
            } header: {
                Text("Blink")
            }
            Section {
                Toggle("Remind me to check my posture", isOn: $model.settings.postureReminderEnabled)
                NumberPreference(
                    title: "Posture reminder every", value: $model.settings.postureIntervalMinutes, range: 1...180
                )
                .disabled(!model.settings.postureReminderEnabled)
                Button {
                    model.previewReminder(.posture)
                } label: {
                    Label("Preview posture reminder", systemImage: "play")
                }
            } header: {
                Text("Posture")
            } footer: {
                Text(
                    "Animated icons appear in the center of your screen without taking keyboard focus and fade after 1.5 seconds. Reminders stay quiet while breaks are paused."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .toggleStyle(.switch)
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
